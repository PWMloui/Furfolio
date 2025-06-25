//
//  RevenueAnalyzer.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–compliant, test/preview-injectable, token-compliant.
//

import Foundation

// MARK: - Analytics/Audit Protocol

public protocol RevenueAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullRevenueAnalyticsLogger: RevenueAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol RevenueTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullRevenueTrustCenterDelegate: RevenueTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - RevenueEvent, RevenueAnalyzerError, PagedResult, Location, Appointment
// (all unchanged, as in your code)

/// Represents an event in revenue analytics for auditing and system transparency.
public struct RevenueEvent {
    public let timestamp: Date
    public let action: String
    public let metadata: [String: Any]?

    public init(timestamp: Date = Date(), action: String, metadata: [String: Any]? = nil) {
        self.timestamp = timestamp
        self.action = action
        self.metadata = metadata
    }
}

public enum RevenueAnalyzerError: Error {
    case invalidDateRange
    case emptyDataSet
    case invalidGoalAmount
    case pagingError(String)
}

public struct PagedResult<T> {
    public let items: [T]
    public let totalCount: Int
    public let pageIndex: Int
    public let pageSize: Int

    public init(items: [T], totalCount: Int, pageIndex: Int, pageSize: Int) {
        self.items = items
        self.totalCount = totalCount
        self.pageIndex = pageIndex
        self.pageSize = pageSize
    }
}

public struct Location { /* ... unchanged ... */ }
public struct Appointment {
    public let id: UUID
    public let location: Location
    public let date: Date

    public init(id: UUID = UUID(), location: Location, date: Date) {
        self.id = id
        self.location = location
        self.date = date
    }
}

@resultBuilder
public struct RevenueStatsBuilder {
    public static func buildBlock(_ components: [Any]...) -> [Any] {
        return components.flatMap { $0 }
    }
}

// MARK: - RevenueAnalyzer

public final class RevenueAnalyzer {

    // MARK: - Static Injectables for Analytics & Trust Center

    public static var analyticsLogger: RevenueAnalyticsLogger = NullRevenueAnalyticsLogger()
    public static var trustCenterDelegate: RevenueTrustCenterDelegate = NullRevenueTrustCenterDelegate()

    // MARK: - Instance Properties

    public var auditLogHook: ((RevenueEvent) -> Void)?
    public let calendar: Calendar
    public let excludedChargeTypes: Set<ChargeType>

    // MARK: - Initialization

    public init(calendar: Calendar = .current, excludedChargeTypes: Set<ChargeType> = []) {
        self.calendar = calendar
        self.excludedChargeTypes = excludedChargeTypes
    }

    // MARK: - Permission/Trust Center Check Helper

    private func checkPermission(_ action: String, context: [String: Any]? = nil) -> Bool {
        let allowed = Self.trustCenterDelegate.permission(for: action, context: context)
        Self.analyticsLogger.log(event: "trust_permission", info: [
            "action": action,
            "allowed": allowed,
            "context": context ?? [:]
        ])
        return allowed
    }

    // MARK: - Total Revenue

    public func totalRevenue(
        charges: [Charge],
        from start: Date? = nil,
        to end: Date? = nil
    ) throws -> Double {
        guard checkPermission("totalRevenue", context: ["from": start as Any, "to": end as Any]) else {
            throw RevenueAnalyzerError.pagingError("Permission denied")
        }
        try validateDateRange(start: start, end: end)
        let filtered = filterByDate(charges, from: start, to: end)
            .filter { !excludedChargeTypes.contains($0.type) }
        let total = filtered.reduce(0) { $0 + $1.amount }
        let event = RevenueEvent(action: "totalRevenue", metadata: [
            "from": start as Any,
            "to": end as Any,
            "result": total
        ])
        auditLogHook?(event)
        Self.analyticsLogger.log(event: "totalRevenue", info: event.metadata)
        return total
    }

    public func totalRevenue(
        pagedCharges: PagedResult<Charge>,
        from start: Date? = nil,
        to end: Date? = nil
    ) throws -> Double {
        try totalRevenue(charges: pagedCharges.items, from: start, to: end)
    }

    // MARK: - Daily Revenue

    public func dailyRevenue(
        charges: [Charge],
        days: Int = 30
    ) -> [(date: Date, total: Double)] {
        guard checkPermission("dailyRevenue", context: ["days": days]) else { return [] }
        let today = calendar.startOfDay(for: Date())
        var results: [(Date, Double)] = []

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let sum = charges
                .filter { !excludedChargeTypes.contains($0.type) && calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            results.append((day, sum))
        }
        let sortedResults = results.sorted {
            calendar.compare($0.0, to: $1.0, toGranularity: .day) == .orderedAscending
        }
        Self.analyticsLogger.log(event: "dailyRevenue", info: ["days": days])
        return sortedResults
    }

    public func dailyRevenue(
        pagedCharges: PagedResult<Charge>,
        days: Int = 30
    ) -> [(date: Date, total: Double)] {
        dailyRevenue(charges: pagedCharges.items, days: days)
    }

    // MARK: - Revenue by Service

    public func revenueByService(
        charges: [Charge]
    ) -> [(service: ChargeType, total: Double)] {
        guard checkPermission("revenueByService") else { return [] }
        let filteredCharges = charges.filter { !excludedChargeTypes.contains($0.type) }
        let grouped = Dictionary(grouping: filteredCharges) { $0.type }
        let mapped = grouped.map { (service, group) in
            (service, group.reduce(0) { $0 + $1.amount })
        }
        let sorted = mapped.sorted {
            if $0.total == $1.total {
                return localizedString(for: $0.service).localizedStandardCompare(localizedString(for: $1.service)) == .orderedAscending
            }
            return $0.total > $1.total
        }
        Self.analyticsLogger.log(event: "revenueByService", info: ["count": sorted.count])
        return sorted
    }

    public func revenueByService(
        pagedCharges: PagedResult<Charge>
    ) -> [(service: ChargeType, total: Double)] {
        revenueByService(charges: pagedCharges.items)
    }

    // MARK: - Revenue by Owner

    public func topClients(
        owners: [DogOwner],
        topN: Int = 3
    ) -> [(owner: DogOwner, total: Double)] {
        guard checkPermission("topClients", context: ["topN": topN]) else { return [] }
        let filteredOwners = owners.map { owner in
            let filteredCharges = owner.charges.filter { !excludedChargeTypes.contains($0.type) }
            return (owner, filteredCharges.reduce(0) { $0 + $1.amount })
        }
        let sorted = filteredOwners
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .prefix(topN)
        Self.analyticsLogger.log(event: "topClients", info: ["topN": topN])
        return Array(sorted)
    }

    public func topClients(
        pagedOwners: PagedResult<DogOwner>,
        topN: Int = 3
    ) -> [(owner: DogOwner, total: Double)] {
        topClients(owners: pagedOwners.items, topN: topN)
    }

    // MARK: - Goal Progress

    public func monthlyGoalProgress(
        charges: [Charge],
        goalAmount: Double
    ) throws -> (total: Double, progress: Double) {
        guard checkPermission("monthlyGoalProgress", context: ["goalAmount": goalAmount]) else {
            throw RevenueAnalyzerError.pagingError("Permission denied")
        }
        guard goalAmount > 0 else { throw RevenueAnalyzerError.invalidGoalAmount }
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return (0, 0)
        }
        let monthCharges = charges.filter { !excludedChargeTypes.contains($0.type) && $0.date >= monthStart }
        let total = monthCharges.reduce(0) { $0 + $1.amount }
        let progress = min(total / goalAmount, 1.0)
        Self.analyticsLogger.log(event: "monthlyGoalProgress", info: [
            "goalAmount": goalAmount,
            "total": total,
            "progress": progress
        ])
        return (total, progress)
    }

    public func monthlyGoalProgress(
        pagedCharges: PagedResult<Charge>,
        goalAmount: Double
    ) throws -> (total: Double, progress: Double) {
        try monthlyGoalProgress(charges: pagedCharges.items, goalAmount: goalAmount)
    }

    // MARK: - Trends

    public func revenueGrowth(
        charges: [Charge],
        days: Int = 30
    ) -> Double {
        guard checkPermission("revenueGrowth", context: ["days": days]) else { return 0 }
        let now = Date()
        guard let periodStart = calendar.date(byAdding: .day, value: -days, to: now),
              let prevPeriodStart = calendar.date(byAdding: .day, value: -(2 * days), to: now) else {
            return 0
        }
        let current = charges
            .filter { !excludedChargeTypes.contains($0.type) && $0.date >= periodStart && $0.date <= now }
            .reduce(0) { $0 + $1.amount }
        let previous = charges
            .filter { !excludedChargeTypes.contains($0.type) && $0.date >= prevPeriodStart && $0.date < periodStart }
            .reduce(0) { $0 + $1.amount }
        guard previous > 0 else { return 100 }
        let growth = ((current - previous) / previous) * 100
        Self.analyticsLogger.log(event: "revenueGrowth", info: [
            "days": days,
            "growthPercent": growth
        ])
        return growth
    }

    public func revenueGrowth(
        pagedCharges: PagedResult<Charge>,
        days: Int = 30
    ) -> Double {
        revenueGrowth(charges: pagedCharges.items, days: days)
    }

    // MARK: - Utilities

    private func filterByDate(
        _ charges: [Charge],
        from start: Date?,
        to end: Date?
    ) -> [Charge] {
        charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
    }

    private func validateDateRange(start: Date?, end: Date?) throws {
        if let start = start, let end = end, start > end {
            throw RevenueAnalyzerError.invalidDateRange
        }
    }

    private func localizedString(for chargeType: ChargeType) -> String {
        return String(describing: chargeType)
    }

    // MARK: - Route Optimization (Stub)

    public func optimalRoute(
        for appointments: [Appointment],
        startingAt: Location? = nil
    ) -> [Appointment] {
        Self.analyticsLogger.log(event: "optimalRoute_stub", info: ["count": appointments.count])
        // TODO: Route optimization (TSP/VRP). For now, stable sort by date.
        return appointments.sorted { $0.date < $1.date }
    }
}
