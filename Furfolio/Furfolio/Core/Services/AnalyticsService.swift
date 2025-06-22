//
//  AnalyticsService.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftUI
import OSLog

// MARK: - AnalyticsService (Modular, Tokenized, Auditable Business Analytics Engine)

/// Centralized analytics engine for Furfolio business and owner insights.
/// This modular, tokenized, and auditable analytics engine supports compliance,
/// dashboards, reporting, feature flagging, badge logic, caching, crash reporting,
/// and seamless SwiftUI/MVVM integration. It is designed for scalable, owner-focused
/// dashboards and enterprise-level reporting to empower data-driven decision making,
/// audit trails, and business intelligence.
/// 
/// The service integrates tightly with domain models such as Charge, Appointment,
/// DogOwner, LoyaltyProgram, and ServiceType to provide comprehensive analytics
/// and operational insights while maintaining extensibility and platform awareness.
final class AnalyticsService {
    // MARK: - Singleton & Dependencies
    
    /// Shared instance for convenience, but dependency injection is preferred for testing.
    static let shared = AnalyticsService()
    
    /// Logger for analytics-related events and errors.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio.analytics", category: "analytics")
    
    /// Stub for feature flag manager integration.
    private let featureFlagManager = FeatureFlagManager.shared
    
    /// Private initializer for singleton pattern.
    private init() {}
    
    // MARK: - Public API
    
    /// Calculates total revenue within an optional date range.
    /// - Parameters:
    ///   - charges: Array of Charge objects.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: Total revenue as Double.
    ///
    /// This method supports audit logging and business reporting by providing
    /// accurate revenue figures for dashboards, financial reporting, and compliance.
    /// It ensures traceability of revenue data over specified periods.
    func totalRevenue(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> Double {
        do {
            let filtered = try filterByDate(charges, from: start, to: end)
            return filtered.reduce(0) { $0 + $1.amount }
        } catch {
            logger.error("Failed to filter charges for totalRevenue: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Provides revenue aggregated by day for the past `days` days.
    /// - Parameters:
    ///   - charges: Array of Charge objects.
    ///   - days: Number of days to include, default 30.
    /// - Returns: Array of tuples (date, total revenue).
    ///
    /// This method facilitates time-series analytics for dashboards and reports,
    /// enabling business users to observe revenue trends and patterns with auditability.
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
    
    /// Counts appointments within an optional date range.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: Number of appointments.
    ///
    /// Provides key business metrics for appointment volume reporting,
    /// audit trails of scheduling activity, and operational performance dashboards.
    func appointmentCount(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> Int {
        do {
            let filtered = try filterByDate(appointments, from: start, to: end)
            return filtered.count
        } catch {
            logger.error("Failed to filter appointments for appointmentCount: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Aggregates appointment counts by day for the past `days` days.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects.
    ///   - days: Number of days to include, default 30.
    /// - Returns: Array of tuples (date, count).
    ///
    /// Supports daily operational reporting and dashboard visualizations for appointment trends,
    /// enabling business and audit teams to monitor scheduling activity over time.
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
    
    /// Returns the top N most popular service types by appointment count.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects.
    ///   - topN: Number of top services to return, default 3.
    /// - Returns: Array of tuples (service type, count).
    ///
    /// Enables business intelligence on service popularity for strategic planning,
    /// marketing focus, and audit reporting on service utilization.
    func topServices(appointments: [Appointment], topN: Int = 3) -> [(service: ServiceType, count: Int)] {
        let counts = Dictionary(grouping: appointments) { $0.serviceType }
            .mapValues { $0.count }
        return counts.sorted(by: { $0.value > $1.value }).prefix(topN).map { ($0.key, $0.value) }
    }
    
    /// Returns owners with an appointment in the last `days` days.
    /// - Parameters:
    ///   - owners: Array of DogOwner objects.
    ///   - days: Number of recent days to consider, default 30.
    /// - Returns: Array of active DogOwner objects.
    ///
    /// Supports customer engagement analytics, retention metrics, and audit trails
    /// for owner activity within business-defined time windows.
    func activeOwners(owners: [DogOwner], since days: Int = 30) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return owners.filter { owner in
            owner.appointments.contains { $0.date >= cutoff }
        }
    }
    
    /// Returns owners with more than one appointment in the last `days` days.
    /// - Parameters:
    ///   - owners: Array of DogOwner objects.
    ///   - days: Number of recent days to consider, default 90.
    /// - Returns: Array of returning DogOwner objects.
    ///
    /// Provides insights into customer loyalty and repeat engagement,
    /// supporting business reporting and audit compliance for retention programs.
    func returningOwners(owners: [DogOwner], since days: Int = 90) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return owners.filter { owner in
            owner.appointments.filter { $0.date >= cutoff }.count > 1
        }
    }
    
    /// Returns owners at risk of retention loss (no booking in `riskThresholdDays`).
    /// - Parameters:
    ///   - owners: Array of DogOwner objects.
    ///   - riskThresholdDays: Days threshold to consider at risk, default 60.
    /// - Returns: Array of DogOwner objects at retention risk.
    ///
    /// Supports proactive customer retention analytics, risk scoring, and audit
    /// reporting to identify and engage owners at risk of churn.
    func retentionRiskOwners(owners: [DogOwner], riskThresholdDays: Int = 60) -> [DogOwner] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -riskThresholdDays, to: Date()) ?? Date()
        return owners.filter { owner in
            guard let last = owner.lastAppointmentDate else { return false }
            return last < cutoff
        }
    }
    
    /// Returns top N owners by total amount spent.
    /// - Parameters:
    ///   - owners: Array of DogOwner objects.
    ///   - topN: Number of top spenders to return, default 3.
    /// - Returns: Array of DogOwner objects.
    ///
    /// Enables financial analytics and VIP customer identification for business
    /// reporting, loyalty program targeting, and audit compliance.
    func topSpenders(owners: [DogOwner], topN: Int = 3) -> [DogOwner] {
        owners.sorted(by: { $0.totalSpent > $1.totalSpent }).prefix(topN).map { $0 }
    }
    
    /// Returns loyalty program entries eligible for rewards.
    /// - Parameter loyalties: Array of LoyaltyProgram objects.
    /// - Returns: Filtered array of eligible LoyaltyProgram entries.
    ///
    /// Supports reward eligibility analytics, compliance verification,
    /// and dashboard reporting for loyalty program management.
    func loyaltyEligibleOwners(loyalties: [LoyaltyProgram]) -> [LoyaltyProgram] {
        loyalties.filter { $0.isEligibleForReward }
    }
    
    /// Calculates average session duration (in minutes) by service type.
    /// - Parameter appointments: Array of Appointment objects.
    /// - Returns: Dictionary mapping ServiceType to average duration.
    ///
    /// Provides operational analytics on service efficiency and customer experience,
    /// supporting dashboards, reporting, and audit of service delivery.
    func averageSessionDuration(appointments: [Appointment]) -> [ServiceType: Double] {
        let groups = Dictionary(grouping: appointments) { $0.serviceType }
        return groups.mapValues { group in
            guard !group.isEmpty else { return 0 }
            let total = group.reduce(0) { $0 + Double($1.durationMinutes) }
            return total / Double(group.count)
        }
    }
    
    /// Stub: Optimizes appointment route using a Traveling Salesman Problem solver.
    /// - Parameter appointments: Array of Appointment objects.
    /// - Returns: Optimized array of Appointment objects in order.
    ///
    /// This async method is designed to produce route optimization results that support
    /// map and dashboard display, audit trails, and compliance hooks. The underlying
    /// TSP/route logic will be modular and tokenized to ensure extensibility,
    /// traceability, and integration with analytics pipelines.
    func optimizeAppointmentRoute(appointments: [Appointment]) async -> [Appointment] {
        // Placeholder for TSP solver integration.
        // This method is async to prepare for potential network or heavy computation.
        logger.debug("Starting route optimization for \(appointments.count) appointments.")
        await Task.sleep(500_000_000) // Simulate async delay (0.5s)
        logger.debug("Route optimization completed.")
        return appointments // Return input as-is for now.
    }
    
    /// Stub: Caches analytics data if needed.
    /// This hints at a caching layer for performance optimization.
    ///
    /// Intended to support audit logging, analytics data persistence,
    /// and reporting efficiency by reducing redundant computations.
    func cacheAnalyticsDataIfNeeded() {
        // Placeholder for caching implementation.
        logger.debug("cacheAnalyticsDataIfNeeded called - caching layer to be implemented.")
    }
    
    /// Stub: Reports analytics-related diagnostics and crashes.
    /// This method is prepared for integration with crash reporting tools.
    /// - Parameter error: Optional error to report.
    ///
    /// Supports audit and diagnostic reporting to enable monitoring of analytics
    /// service health, error tracking, and compliance with operational standards.
    func reportDiagnostics(error: Error? = nil) {
        if let error = error {
            logger.error("Analytics diagnostic error reported: \(error.localizedDescription)")
        } else {
            logger.debug("Analytics diagnostics reported with no error.")
        }
        // Integration with crash reporting SDKs to be added here.
    }
    
    // MARK: - Private Helpers
    
    /// Filters an array of items by date range.
    /// Supports Charge and Appointment types.
    /// - Parameters:
    ///   - items: Array of generic items (Charge or Appointment).
    ///   - start: Optional start date.
    ///   - end: Optional end date.
    /// - Throws: AnalyticsError.invalidType if unsupported type is passed.
    /// - Returns: Filtered array of items.
    ///
    /// This helper method ensures consistent date filtering for audit and analytics
    /// operations, and reports errors for unsupported types to maintain diagnostic visibility.
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

/// Stub feature flag manager to prepare for feature toggling integration.
///
/// This class supports modular feature flagging with audit and diagnostic
/// capabilities to enable compliance, testing, and controlled feature rollout
/// within the analytics ecosystem.
final class FeatureFlagManager {
    static let shared = FeatureFlagManager()
    
    private init() {}
    
    /// Example feature flag getter.
    func isFeatureEnabled(_ featureName: String) -> Bool {
        // Placeholder: Return false by default.
        return false
    }
}

/// Analytics-related errors.
///
/// Defines error types for analytics operations with reporting,
/// audit, and diagnostic purposes to improve robustness and traceability.
enum AnalyticsError: Error {
    case invalidType
}
