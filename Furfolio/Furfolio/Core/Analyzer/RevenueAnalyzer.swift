//
//  RevenueAnalyzer.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–compliant, test/preview-injectable, token-compliant, BI-ready.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct RevenueAnalyzerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "RevenueAnalyzer"
}

// MARK: - Analytics/Audit Protocol

public protocol RevenueAnalyticsLogger: AnyObject {
    var testMode: Bool { get set }
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    var recentEvents: [RevenueAnalyticsEvent] { get }
}

/// Revenue analytics event with full audit context.
public struct RevenueAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let action: String
    public let metadata: [String: Any]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

// Null logger (for previews/tests)
public final class NullRevenueAnalyticsLogger: RevenueAnalyticsLogger {
    public var testMode: Bool = true
    private var buffer: [RevenueAnalyticsEvent] = []
    public init() {}
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let evt = RevenueAnalyticsEvent(timestamp: Date(), action: event, metadata: info, role: role, staffID: staffID, context: context, escalate: escalate)
        if buffer.count >= 20 { buffer.removeFirst() }
        buffer.append(evt)
        if testMode {
            print("[NullRevenueAnalyticsLogger] \(event) info:\(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
    public var recentEvents: [RevenueAnalyticsEvent] { buffer }
}

/// Default analytics logger with capped buffer and async/await, supports testMode for console-only logging.
public actor DefaultRevenueAnalyticsLogger: RevenueAnalyticsLogger {
    public var testMode: Bool = false
    private let bufferSize = 20
    private var buffer: [RevenueAnalyticsEvent] = []
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let evt = RevenueAnalyticsEvent(timestamp: Date(), action: event, metadata: info, role: role, staffID: staffID, context: context, escalate: escalate)
        if buffer.count >= bufferSize { buffer.removeFirst() }
        buffer.append(evt)
        if testMode {
            print("[RevenueAnalyticsLogger] \(event): \(String(describing: info)), role:\(role ?? "-"), staffID:\(staffID ?? "-"), context:\(context ?? "-"), escalate:\(escalate)")
        } else {
            // Production: integrate with endpoint here
        }
    }
    public var recentEvents: [RevenueAnalyticsEvent] { buffer }
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

    public var auditLogHook: ((RevenueAnalyticsEvent) -> Void)?
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
        Task {
            let escalate = action.lowercased().contains("danger") || action.lowercased().contains("critical") || action.lowercased().contains("delete") ||
                (context?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
            await Self.analyticsLogger.log(
                event: NSLocalizedString("trust_permission", value: "Trust Center Permission", comment: "Analytics: Trust Center permission check"),
                info: [
                    NSLocalizedString("action", value: "Action", comment: "Analytics: permission action"): action,
                    NSLocalizedString("allowed", value: "Allowed", comment: "Analytics: permission allowed"): allowed,
                    NSLocalizedString("context", value: "Context", comment: "Analytics: permission context"): context ?? [:]
                ],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
        return allowed
    }

    // MARK: - Total Revenue

    public func totalRevenue(
        charges: [Charge],
        from start: Date? = nil,
        to end: Date? = nil
    ) throws -> Double {
        guard checkPermission(NSLocalizedString("totalRevenue", value: "Total Revenue", comment: "Analytics: total revenue calculation"), context: [
            NSLocalizedString("from", value: "From", comment: "Analytics: start date"): start as Any,
            NSLocalizedString("to", value: "To", comment: "Analytics: end date"): end as Any
        ]) else {
            throw RevenueAnalyzerError.pagingError(NSLocalizedString("permission_denied", value: "Permission denied", comment: "Error: permission denied"))
        }
        try validateDateRange(start: start, end: end)
        let filtered = filterByDate(charges, from: start, to: end)
            .filter { !excludedChargeTypes.contains($0.type) }
        let total = filtered.reduce(0) { $0 + $1.amount }
        let meta = [
            NSLocalizedString("from", value: "From", comment: "Analytics: start date"): start as Any,
            NSLocalizedString("to", value: "To", comment: "Analytics: end date"): end as Any,
            NSLocalizedString("result", value: "Result", comment: "Analytics: result value"): total
        ]
        auditLogHook?(RevenueAnalyticsEvent(timestamp: Date(), action: NSLocalizedString("totalRevenue", value: "Total Revenue", comment: "Analytics: total revenue calculation"), metadata: meta, role: RevenueAnalyzerAuditContext.role, staffID: RevenueAnalyzerAuditContext.staffID, context: RevenueAnalyzerAuditContext.context, escalate: false))
        Task {
            let escalate = false // Adjust escalation if needed here
            await Self.analyticsLogger.log(
                event: NSLocalizedString("totalRevenue", value: "Total Revenue", comment: "Analytics: total revenue calculation"),
                info: meta,
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        guard checkPermission(NSLocalizedString("dailyRevenue", value: "Daily Revenue", comment: "Analytics: daily revenue calculation"), context: [
            NSLocalizedString("days", value: "Days", comment: "Analytics: number of days"): days
        ]) else { return [] }
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
        Task {
            let escalate = false // Adjust if needed
            await Self.analyticsLogger.log(
                event: NSLocalizedString("dailyRevenue", value: "Daily Revenue", comment: "Analytics: daily revenue calculation"),
                info: [NSLocalizedString("days", value: "Days", comment: "Analytics: number of days"): days],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        guard checkPermission(NSLocalizedString("revenueByService", value: "Revenue by Service", comment: "Analytics: revenue by service"), context: nil) else { return [] }
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
        Task {
            let escalate = false
            await Self.analyticsLogger.log(
                event: NSLocalizedString("revenueByService", value: "Revenue by Service", comment: "Analytics: revenue by service"),
                info: [NSLocalizedString("count", value: "Count", comment: "Analytics: count of services"): sorted.count],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        guard checkPermission(NSLocalizedString("topClients", value: "Top Clients", comment: "Analytics: top clients by revenue"), context: [
            NSLocalizedString("topN", value: "Top N", comment: "Analytics: N clients"): topN
        ]) else { return [] }
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
        Task {
            let escalate = false
            await Self.analyticsLogger.log(
                event: NSLocalizedString("topClients", value: "Top Clients", comment: "Analytics: top clients by revenue"),
                info: [NSLocalizedString("topN", value: "Top N", comment: "Analytics: N clients"): topN],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        guard checkPermission(NSLocalizedString("monthlyGoalProgress", value: "Monthly Goal Progress", comment: "Analytics: monthly goal progress"), context: [
            NSLocalizedString("goalAmount", value: "Goal Amount", comment: "Analytics: goal amount"): goalAmount
        ]) else {
            throw RevenueAnalyzerError.pagingError(NSLocalizedString("permission_denied", value: "Permission denied", comment: "Error: permission denied"))
        }
        guard goalAmount > 0 else { throw RevenueAnalyzerError.invalidGoalAmount }
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return (0, 0)
        }
        let monthCharges = charges.filter { !excludedChargeTypes.contains($0.type) && $0.date >= monthStart }
        let total = monthCharges.reduce(0) { $0 + $1.amount }
        let progress = min(total / goalAmount, 1.0)
        Task {
            let escalate = false
            await Self.analyticsLogger.log(
                event: NSLocalizedString("monthlyGoalProgress", value: "Monthly Goal Progress", comment: "Analytics: monthly goal progress"),
                info: [
                    NSLocalizedString("goalAmount", value: "Goal Amount", comment: "Analytics: goal amount"): goalAmount,
                    NSLocalizedString("total", value: "Total", comment: "Analytics: total value"): total,
                    NSLocalizedString("progress", value: "Progress", comment: "Analytics: progress value"): progress
                ],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        guard checkPermission(NSLocalizedString("revenueGrowth", value: "Revenue Growth", comment: "Analytics: revenue growth calculation"), context: [
            NSLocalizedString("days", value: "Days", comment: "Analytics: number of days"): days
        ]) else { return 0 }
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
        Task {
            let escalate = false
            await Self.analyticsLogger.log(
                event: NSLocalizedString("revenueGrowth", value: "Revenue Growth", comment: "Analytics: revenue growth calculation"),
                info: [
                    NSLocalizedString("days", value: "Days", comment: "Analytics: number of days"): days,
                    NSLocalizedString("growthPercent", value: "Growth Percent", comment: "Analytics: growth percentage"): growth
                ],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
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
        Task {
            let escalate = false
            await Self.analyticsLogger.log(
                event: NSLocalizedString("optimalRoute_stub", value: "Optimal Route (Stub)", comment: "Analytics: optimal route (stub)"),
                info: [NSLocalizedString("count", value: "Count", comment: "Analytics: count of appointments"): appointments.count],
                role: RevenueAnalyzerAuditContext.role,
                staffID: RevenueAnalyzerAuditContext.staffID,
                context: RevenueAnalyzerAuditContext.context,
                escalate: escalate
            )
        }
        return appointments.sorted { $0.date < $1.date }
    }

    // MARK: - Diagnostics/Buffer

    public func recentAnalyticsEvents() async -> [RevenueAnalyticsEvent] {
        await Self.analyticsLogger.recentEvents
    }
}

#if DEBUG
import SwiftUI
struct RevenueAnalyzer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("preview_title", value: "Revenue Analyzer Preview", comment: "Preview: Title"))
                .font(.headline)
            Text(NSLocalizedString("preview_testmode", value: "Test Mode: ON", comment: "Preview: test mode ON"))
                .accessibilityLabel(NSLocalizedString("preview_testmode_accessibility", value: "Test Mode is On", comment: "Accessibility: test mode"))
            Divider()
            DiagnosticsView()
        }
        .padding()
        .onAppear {
            Task {
                let logger = DefaultRevenueAnalyticsLogger(testMode: true)
                RevenueAnalyzer.analyticsLogger = logger
                await logger.log(event: NSLocalizedString("preview_event1", value: "Preview Event 1", comment: "Preview: event 1"), info: ["foo": "bar"], role: "previewRole", staffID: "previewID", context: "RevenueAnalyzer", escalate: false)
                await logger.log(event: NSLocalizedString("preview_event2", value: "Preview Event 2", comment: "Preview: event 2"), info: ["baz": 123], role: "previewRole", staffID: "previewID", context: "RevenueAnalyzer", escalate: false)
            }
        }
    }
    struct DiagnosticsView: View {
        @State private var events: [RevenueAnalyticsEvent] = []
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("diagnostics_buffer", value: "Diagnostics Buffer (last 20 events):", comment: "Preview: diagnostics buffer header"))
                    .font(.subheadline)
                ScrollView {
                    ForEach(events) { event in
                        VStack(alignment: .leading) {
                            Text(event.action)
                                .font(.caption)
                            if let meta = event.metadata {
                                Text(meta.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("role: \(event.role ?? "-")")
                                Text("staffID: \(event.staffID ?? "-")")
                                Text("context: \(event.context ?? "-")")
                                Text("escalate: \(event.escalate ? "YES" : "NO")")
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(event.action), \(event.metadata?.description ?? ""), \(event.timestamp)")
                    }
                }
            }
            .onAppear {
                Task {
                    if let logger = RevenueAnalyzer.analyticsLogger as? DefaultRevenueAnalyticsLogger {
                        let recent = await logger.recentEvents
                        events = recent
                    }
                }
            }
        }
    }
}
#endif
