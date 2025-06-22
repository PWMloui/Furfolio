//
//  RevenueAnalyzer.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import Foundation

// MARK: - RevenueAnalyzer (Financial Analytics, Dashboard, Route Optimization)

/// Represents an event in revenue analytics for auditing and system transparency.
///
/// Used for audit trails, debugging, and compliance. Each event captures a timestamp,
/// an action string (such as "totalRevenue"), and optional metadata. Events may be
/// localized or extended for future analytics, cloud audit integration, or dashboard activity logs.
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

/// Errors that can be thrown by `RevenueAnalyzer`.
public enum RevenueAnalyzerError: Error {
    case invalidDateRange
    case emptyDataSet
    case invalidGoalAmount
    case pagingError(String)
}

/// A paged result container for scalable analytics, dashboard paging, and cloud/hybrid data sources.
///
/// Used to support efficient paging of large datasets in dashboards or analytics queries.
/// Designed for future extensibility with cloud/hybrid data sources, and for localization
/// of paging UI in dashboards.
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

/// Represents a location for route optimization and analytics.
///
/// Intended for use in future route optimization features (e.g., TSP, mapping).
/// Extendable for address, coordinates, and localization for internationalization.
public struct Location {
    // Placeholder properties for location coordinates, address, etc.
}

/// Represents an appointment for route optimization, analytics, and dashboard display.
///
/// Used as an input for route optimization (planned TSP/VRP features), dashboard scheduling,
/// and auditing. Designed for extensibility with future analytics and localization.
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

/// A result builder for constructing revenue analytics dashboard sections.
///
/// Used to declaratively build dashboard statistics, charts, and summaries.
/// Designed for modular dashboard composition, localization, and future extensibility
/// for cloud/hybrid analytics and custom dashboard widgets.
@resultBuilder
public struct RevenueStatsBuilder {
    public static func buildBlock(_ components: [Any]...) -> [Any] {
        return components.flatMap { $0 }
    }
}

/**
 Utility for revenue and financial analytics in Furfolio.

 `RevenueAnalyzer` provides modular, testable, and extensible analytics for revenue,
 trends, goals, and route optimization. Designed for dashboard integration, audit
 logging, and localization.

 - Architecture:
   - Modular: Analytics methods are decoupled, support dependency injection (calendar, excluded types).
   - Testable: All analytics are pure functions, easy to test in isolation.
   - Auditing: All public analytics methods emit `RevenueEvent` for audit trails and debugging.
   - Localization: Methods and builders support future localization of stats, labels, and paging.
   - Dashboard: Methods and builders are dashboard-friendly, supporting paging, charting, and summaries.
   - Extensibility:
     - Route optimization: Stubs and types for future TSP/route optimization.
     - Cloud/hybrid analytics: `PagedResult` and builders are designed for scalable and remote data sources.
     - Dashboard stats: `RevenueStatsBuilder` enables modular dashboard section composition.
     - Auditing: Audit hooks can be integrated with cloud or local audit systems.
   - Future: Designed for internationalization, more advanced analytics, and integration with cloud/hybrid dashboards.
*/
public final class RevenueAnalyzer {
    
    // MARK: - Public Properties
    
    /// Hook to receive audit events for actions performed by this analyzer.
    public var auditLogHook: ((RevenueEvent) -> Void)?
    
    /// Calendar instance used for all date computations.
    public let calendar: Calendar
    
    /// Set of charge types to exclude from calculations (e.g., expenses, refunds).
    public let excludedChargeTypes: Set<ChargeType>
    
    // MARK: - Initialization
    
    /// Initializes a new instance of `RevenueAnalyzer`.
    ///
    /// - Parameters:
    ///   - calendar: Calendar to use for date calculations. Defaults to `.current`.
    ///   - excludedChargeTypes: Set of charge types to exclude from calculations. Defaults to empty.
    public init(calendar: Calendar = .current, excludedChargeTypes: Set<ChargeType> = []) {
        self.calendar = calendar
        self.excludedChargeTypes = excludedChargeTypes
    }
    
    // MARK: - Total Revenue
    
    /// Calculates total revenue for a given date range from an array of charges.
    ///
    /// - Parameters:
    ///   - charges: Array of charges to process.
    ///   - from: Optional start date to filter charges.
    ///   - to: Optional end date to filter charges.
    /// - Returns: Total revenue as a `Double`.
    /// - Throws: `RevenueAnalyzerError.invalidDateRange` if `from` > `to`.
    public func totalRevenue(
        charges: [Charge],
        from start: Date? = nil,
        to end: Date? = nil
    ) throws -> Double {
        try validateDateRange(start: start, end: end)
        let filtered = filterByDate(charges, from: start, to: end)
            .filter { !excludedChargeTypes.contains($0.type) }
        let total = filtered.reduce(0) { $0 + $1.amount }
        auditLogHook?(RevenueEvent(action: "totalRevenue", metadata: [
            "from": start as Any,
            "to": end as Any,
            "result": total
        ]))
        return total
    }
    
    /// Calculates total revenue for a given date range from a paged result of charges.
    ///
    /// - Parameters:
    ///   - pagedCharges: PagedResult of charges to process.
    ///   - from: Optional start date to filter charges.
    ///   - to: Optional end date to filter charges.
    /// - Returns: Total revenue as a `Double`.
    /// - Throws: `RevenueAnalyzerError` on invalid input.
    public func totalRevenue(
        pagedCharges: PagedResult<Charge>,
        from start: Date? = nil,
        to end: Date? = nil
    ) throws -> Double {
        try totalRevenue(charges: pagedCharges.items, from: start, to: end)
    }
    
    // MARK: - Revenue by Day
    
    /// Returns revenue totals per day for the last N days (for charting/trends).
    ///
    /// - Parameters:
    ///   - charges: Array of charges to process.
    ///   - days: Number of days to include counting backwards from today.
    /// - Returns: Array of tuples with date and total revenue for that day.
    public func dailyRevenue(
        charges: [Charge],
        days: Int = 30
    ) -> [(date: Date, total: Double)] {
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
        auditLogHook?(RevenueEvent(action: "dailyRevenue", metadata: ["days": days]))
        return sortedResults
    }
    
    /// Returns revenue totals per day for the last N days from a paged result of charges.
    ///
    /// - Parameters:
    ///   - pagedCharges: PagedResult of charges to process.
    ///   - days: Number of days to include counting backwards from today.
    /// - Returns: Array of tuples with date and total revenue for that day.
    public func dailyRevenue(
        pagedCharges: PagedResult<Charge>,
        days: Int = 30
    ) -> [(date: Date, total: Double)] {
        dailyRevenue(charges: pagedCharges.items, days: days)
    }
    
    // MARK: - Revenue by Service
    
    /// Returns total revenue grouped by charge/service type.
    ///
    /// - Parameter charges: Array of charges to process.
    /// - Returns: Sorted array of tuples with service type and total revenue.
    public func revenueByService(
        charges: [Charge]
    ) -> [(service: ChargeType, total: Double)] {
        let filteredCharges = charges.filter { !excludedChargeTypes.contains($0.type) }
        let grouped = Dictionary(grouping: filteredCharges) { $0.type }
        let mapped = grouped.map { (service, group) in
            (service, group.reduce(0) { $0 + $1.amount })
        }
        // Stable, locale-aware sort by total descending, then service's localized name ascending
        let sorted = mapped.sorted {
            if $0.total == $1.total {
                return localizedString(for: $0.service).localizedStandardCompare(localizedString(for: $1.service)) == .orderedAscending
            }
            return $0.total > $1.total
        }
        auditLogHook?(RevenueEvent(action: "revenueByService", metadata: ["count": sorted.count]))
        return sorted
    }
    
    /// Returns total revenue grouped by charge/service type from a paged result.
    ///
    /// - Parameter pagedCharges: PagedResult of charges to process.
    /// - Returns: Sorted array of tuples with service type and total revenue.
    public func revenueByService(
        pagedCharges: PagedResult<Charge>
    ) -> [(service: ChargeType, total: Double)] {
        revenueByService(charges: pagedCharges.items)
    }
    
    // MARK: - Revenue by Owner
    
    /// Returns top N clients by total spent.
    ///
    /// - Parameters:
    ///   - owners: Array of dog owners to process.
    ///   - topN: Number of top clients to return.
    /// - Returns: Sorted array of tuples with owner and total spent.
    public func topClients(
        owners: [DogOwner],
        topN: Int = 3
    ) -> [(owner: DogOwner, total: Double)] {
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
        auditLogHook?(RevenueEvent(action: "topClients", metadata: ["topN": topN]))
        return Array(sorted)
    }
    
    /// Returns top N clients by total spent from a paged result.
    ///
    /// - Parameters:
    ///   - pagedOwners: PagedResult of dog owners to process.
    ///   - topN: Number of top clients to return.
    /// - Returns: Sorted array of tuples with owner and total spent.
    public func topClients(
        pagedOwners: PagedResult<DogOwner>,
        topN: Int = 3
    ) -> [(owner: DogOwner, total: Double)] {
        topClients(owners: pagedOwners.items, topN: topN)
    }
    
    // MARK: - Goal Progress
    
    /// Calculates current month's revenue and progress toward a goal.
    ///
    /// - Parameters:
    ///   - charges: Array of charges to process.
    ///   - goalAmount: Revenue goal amount; must be > 0.
    /// - Returns: Tuple of total revenue and progress ratio (0.0 to 1.0).
    /// - Throws: `RevenueAnalyzerError.invalidGoalAmount` if goalAmount is zero or negative.
    public func monthlyGoalProgress(
        charges: [Charge],
        goalAmount: Double
    ) throws -> (total: Double, progress: Double) {
        guard goalAmount > 0 else { throw RevenueAnalyzerError.invalidGoalAmount }
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return (0, 0)
        }
        let monthCharges = charges.filter { !excludedChargeTypes.contains($0.type) && $0.date >= monthStart }
        let total = monthCharges.reduce(0) { $0 + $1.amount }
        let progress = min(total / goalAmount, 1.0)
        auditLogHook?(RevenueEvent(action: "monthlyGoalProgress", metadata: [
            "goalAmount": goalAmount,
            "total": total,
            "progress": progress
        ]))
        return (total, progress)
    }
    
    /// Calculates current month's revenue and progress toward a goal from a paged result.
    ///
    /// - Parameters:
    ///   - pagedCharges: PagedResult of charges to process.
    ///   - goalAmount: Revenue goal amount; must be > 0.
    /// - Returns: Tuple of total revenue and progress ratio (0.0 to 1.0).
    /// - Throws: `RevenueAnalyzerError.invalidGoalAmount` if goalAmount is zero or negative.
    public func monthlyGoalProgress(
        pagedCharges: PagedResult<Charge>,
        goalAmount: Double
    ) throws -> (total: Double, progress: Double) {
        try monthlyGoalProgress(charges: pagedCharges.items, goalAmount: goalAmount)
    }
    
    // MARK: - Trends
    
    /// Returns percent growth (or decline) in revenue compared to previous period.
    ///
    /// - Parameters:
    ///   - charges: Array of charges to process.
    ///   - days: Number of days for each period.
    /// - Returns: Percent change as Double; 100 indicates 100% increase or no previous data.
    public func revenueGrowth(
        charges: [Charge],
        days: Int = 30
    ) -> Double {
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
        auditLogHook?(RevenueEvent(action: "revenueGrowth", metadata: [
            "days": days,
            "growthPercent": growth
        ]))
        return growth
    }
    
    /// Returns percent growth (or decline) in revenue compared to previous period from a paged result.
    ///
    /// - Parameters:
    ///   - pagedCharges: PagedResult of charges to process.
    ///   - days: Number of days for each period.
    /// - Returns: Percent change as Double; 100 indicates 100% increase or no previous data.
    public func revenueGrowth(
        pagedCharges: PagedResult<Charge>,
        days: Int = 30
    ) -> Double {
        revenueGrowth(charges: pagedCharges.items, days: days)
    }
    
    // MARK: - Utilities
    
    /// Filters charges by optional date range.
    ///
    /// - Parameters:
    ///   - charges: Array of charges to filter.
    ///   - from: Optional start date.
    ///   - to: Optional end date.
    /// - Returns: Filtered array of charges.
    private func filterByDate(
        _ charges: [Charge],
        from start: Date?,
        to end: Date?
    ) -> [Charge] {
        charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
    }
    
    /// Validates that the date range is valid (start <= end).
    ///
    /// - Parameters:
    ///   - start: Optional start date.
    ///   - end: Optional end date.
    /// - Throws: `RevenueAnalyzerError.invalidDateRange` if invalid.
    private func validateDateRange(start: Date?, end: Date?) throws {
        if let start = start, let end = end, start > end {
            throw RevenueAnalyzerError.invalidDateRange
        }
    }
    
    /// Returns a localized string for a given charge type.
    ///
    /// - Parameter chargeType: ChargeType to localize.
    /// - Returns: Localized string.
    private func localizedString(for chargeType: ChargeType) -> String {
        // Assuming ChargeType conforms to CustomStringConvertible or similar.
        // Replace with actual localization logic as needed.
        return String(describing: chargeType)
    }
    
    // MARK: - Route Optimization (Stub)
    
    /**
     Computes an optimal route for a set of appointments.

     - Parameters:
       - appointments: Array of appointments to optimize route for.
       - startingAt: Optional starting location.
     - Returns: Ordered array of appointments representing the (currently date-sorted) optimal route.

     - Note:
       This is a stub implementation. Planned for future extension with route optimization algorithms
       (e.g., Traveling Salesman Problem solvers, mapping APIs). For now, provides a stable fallback
       by sorting appointments by date. Intended for use in dashboard route optimization features,
       analytics, and future cloud/hybrid route planning.
    */
    public func optimalRoute(
        for appointments: [Appointment],
        startingAt: Location? = nil
    ) -> [Appointment] {
        // TODO: Implement route optimization algorithm (e.g., TSP solver)
        // For now, return appointments sorted by date as a stable fallback.
        return appointments.sorted { $0.date < $1.date }
    }
}
