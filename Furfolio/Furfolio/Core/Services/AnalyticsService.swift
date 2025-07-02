/**
 AnalyticsService
 ----------------
 Centralized analytics engine for Furfolio, providing non-blocking event and screen-view logging with built-in audit capabilities.

 - **Architecture**: Singleton conforming to `AnalyticsServiceProtocol` for dependency injection.
 - **Concurrency & Async Logging**: Protocol methods are `async` and internal logging is offloaded to avoid UI blocking.
 - **Audit Ready**: Integrates with `AnalyticsAuditManager` actor to record every analytic event.
 - **Localization & Accessibility**: Event names and parameters can be localized at the call site.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */
//
//  AnalyticsService.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftUI
import OSLog

/// A record of an analytics event for audit purposes.
public struct AnalyticsAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let parameters: [String: Any]?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, parameters: [String: Any]?) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.parameters = parameters
    }
}

/// Concurrency-safe actor for recording analytics audit entries.
public actor AnalyticsAuditManager {
    private var buffer: [AnalyticsAuditEntry] = []
    private let maxEntries = 100
    public static let shared = AnalyticsAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: AnalyticsAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [AnalyticsAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as a pretty-printed JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Analytics Protocol

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

// MARK: - AnalyticsService (Modular, Tokenized, Auditable Business Analytics Engine)

/// Centralized analytics engine for Furfolio business and owner insights.
final class AnalyticsService: AnalyticsServiceProtocol {
    // MARK: - Singleton & Dependencies

    /// Shared instance for convenience, but dependency injection is preferred for testing.
    static let shared = AnalyticsService()

    /// Logger for analytics-related events and errors.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio.analytics", category: "analytics")

    /// Stub for feature flag manager integration.
    private let featureFlagManager = FeatureFlagManager.shared

    /// Private initializer for singleton pattern.
    private init() {}

    // MARK: - Protocol Conformance

    public func log(event: String, parameters: [String: Any]? = nil) async {
        logger.log("Event: \(event), Parameters: \(String(describing: parameters))")
        await AnalyticsAuditManager.shared.add(
            AnalyticsAuditEntry(event: event, parameters: parameters)
        )
        // TODO: Integrate with Firebase, Mixpanel, etc.
    }

    public func screenView(_ name: String) async {
        await log(event: "screen_view", parameters: ["screen_name": name])
    }

    // MARK: - Public Business Methods

    func totalRevenue(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> Double {
        do {
            let filtered = try filterByDate(charges, from: start, to: end)
            return filtered.reduce(0) { $0 + $1.amount }
        } catch {
            logger.error("Failed to filter charges for totalRevenue: \(error.localizedDescription)")
            return 0
        }
    }

    func revenueByDay(charges: [Charge], forDays days: Int = 30) -> [(date: Date, total: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(Date, Double)] = []

        for i in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else {
                logger.warning("Date calculation failed for day index \(i)")
                continue
            }
            let dayCharges = charges.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let sum = dayCharges.reduce(0) { $0 + $1.amount }
            result.append((day, sum))
        }
        return result.reversed()
    }

    func appointmentCount(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> Int {
        do {
            let filtered = try filterByDate(appointments, from: start, to: end)
            return filtered.count
        } catch {
            logger.error("Failed to filter appointments for appointmentCount: \(error.localizedDescription)")
            return 0
        }
    }

    func appointmentsByDay(appointments: [Appointment], forDays days: Int = 30) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(Date, Int)] = []

        for i in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else {
                logger.warning("Date calculation failed for day index \(i)")
                continue
            }
            let dayAppointments = appointments.filter { calendar.isDate($0.date, inSameDayAs: day) }
            result.append((day, dayAppointments.count))
        }
        return result.reversed()
    }

    func topServices(appointments: [Appointment], topN: Int = 3) -> [(service: ServiceType, count: Int)] {
        let counts = Dictionary(grouping: appointments) { $0.serviceType }
            .mapValues { $0.count }
        return counts.sorted(by: { $0.value > $1.value }).prefix(topN).map { ($0.key, $0.value) }
    }

    func activeOwners(owners: [DogOwner], since days: Int = 30) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return owners.filter { owner in
            owner.appointments.contains { $0.date >= cutoff }
        }
    }

    func returningOwners(owners: [DogOwner], since days: Int = 90) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return owners.filter { owner in
            owner.appointments.filter { $0.date >= cutoff }.count > 1
        }
    }

    func retentionRiskOwners(owners: [DogOwner], riskThresholdDays: Int = 60) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -riskThresholdDays, to: Date()) ?? Date()
        return owners.filter { owner in
            guard let last = owner.lastAppointmentDate else { return false }
            return last < cutoff
        }
    }

    func topSpenders(owners: [DogOwner], topN: Int = 3) -> [DogOwner] {
        owners.sorted(by: { $0.totalSpent > $1.totalSpent }).prefix(topN).map { $0 }
    }

    func loyaltyEligibleOwners(loyalties: [LoyaltyProgram]) -> [LoyaltyProgram] {
        loyalties.filter { $0.isEligibleForReward }
    }

    func averageSessionDuration(appointments: [Appointment]) -> [ServiceType: Double] {
        let groups = Dictionary(grouping: appointments) { $0.serviceType }
        return groups.mapValues { group in
            guard !group.isEmpty else { return 0 }
            let total = group.reduce(0) { $0 + Double($1.durationMinutes) }
            return total / Double(group.count)
        }
    }

    func optimizeAppointmentRoute(appointments: [Appointment]) async -> [Appointment] {
        logger.debug("Starting route optimization for \(appointments.count) appointments.")
        await Task.sleep(500_000_000) // Simulate async delay (0.5s)
        logger.debug("Route optimization completed.")
        return appointments // Placeholder logic
    }

    func cacheAnalyticsDataIfNeeded() {
        logger.debug("cacheAnalyticsDataIfNeeded called - caching layer to be implemented.")
    }

    func reportDiagnostics(error: Error? = nil) {
        if let error = error {
            logger.error("Analytics diagnostic error reported: \(error.localizedDescription)")
        } else {
            logger.debug("Analytics diagnostics reported with no error.")
        }
        // Placeholder for crash reporting integration
    }

    // MARK: - Private Helpers

    private func filterByDate<T>(_ items: [T], from start: Date?, to end: Date?) throws -> [T] {
        return items.filter { item in
            let date: Date
            if let charge = item as? Charge {
                date = charge.date
            } else if let appointment = item as? Appointment {
                date = appointment.date
            } else {
                logger.error("Unsupported type passed to filterByDate: \(type(of: item))")
                return false
            }
            if let start = start, date < start { return false }
            if let end = end, date > end { return false }
            return true
        }
    }
}

// MARK: - Feature Flag Manager Stub

final class FeatureFlagManager {
    static let shared = FeatureFlagManager()
    private init() {}

    func isFeatureEnabled(_ featureName: String) -> Bool {
        return false
    }
}

// MARK: - Analytics Errors

enum AnalyticsError: Error {
    case invalidType
}

// MARK: - Diagnostics

public extension AnalyticsService {
    /// Fetch recent analytics audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [AnalyticsAuditEntry] {
        await AnalyticsAuditManager.shared.recent(limit: limit)
    }

    /// Export the analytics audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AnalyticsAuditManager.shared.exportJSON()
    }
}
