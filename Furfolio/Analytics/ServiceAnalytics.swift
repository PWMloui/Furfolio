//  ServiceAnalytics.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on May 30, 2025 — performance improvements, clearer naming, added top-frequency helper,
//                         and replaced intermediate arrays with single-pass aggregates.
//
// Computations run off the main thread by default. UI views should `await` these async methods.

import Foundation
import _Concurrency
/// Provides analytics functions for appointments and charges, such as frequency, duration, and revenue metrics.
struct ServiceAnalytics {
    
    private static func runAsync<T>(
        _ work: @Sendable @escaping () -> T
    ) async -> T {
        await Task.detached { work() }.value
    }
    
    /// Aggregated metrics for a specific service type.
    /// Aggregated metrics for a specific service type.
    struct ServiceMetrics {
        let frequency: Int           // Number of appointments
        let averageDuration: Double  // Average duration in minutes
        let totalRevenue: Double     // Total revenue from charges

        /// Revenue per minute across all appointments of this type.
        var revenuePerMinute: Double {
            let totalMinutes = averageDuration * Double(frequency)
            return totalMinutes > 0 ? totalRevenue / totalMinutes : 0
        }
    }
    
    
    // MARK: – Appointment Frequency
    
    /// Returns the count of appointments grouped by service type.
    /// - Parameter appointments: Array of Appointment instances.
    /// - Returns: A dictionary mapping each service type to its frequency.
    /// - Note: This is a synchronous method.
    static func syncAppointmentFrequency(
        in appointments: [Appointment]
    ) -> [Appointment.ServiceType: Int] {
        appointments.reduce(into: [:]) { counts, appt in
            // Single-pass aggregation for frequency.
            counts[appt.serviceType, default: 0] += 1
        }
    }

    /// Returns the count of appointments grouped by service type.
    /// - Parameter appointments: Array of Appointment instances.
    /// - Returns: A dictionary mapping each service type to its frequency.
    /// - Note: This is an async method running off the main thread.
    static func appointmentFrequency(
        in appointments: [Appointment]
    ) async -> [Appointment.ServiceType: Int] {
        await runAsync { syncAppointmentFrequency(in: appointments) }
    }
    
    
    // MARK: – Average Duration
    
    /// Computes average appointment duration per service type.
    /// - Parameter appointments: Array of Appointment instances.
    /// - Returns: A dictionary mapping each service type to its average duration in minutes.
    static func averageDuration(
        for appointments: [Appointment]
    ) -> [Appointment.ServiceType: Double] {
        let stats = appointments.reduce(into: [Appointment.ServiceType: (sum: Double, count: Int)]()) { acc, appt in
            guard let dur = appt.durationMinutes else { return }
            let type = appt.serviceType
            var entry = acc[type] ?? (0, 0)
            entry.sum += Double(dur)
            entry.count += 1
            acc[type] = entry
        }
        return stats.mapValues { entry in
            entry.count > 0 ? entry.sum / Double(entry.count) : 0
        }
    }
    
    
    // MARK: – Revenue by Service

    @MainActor
    static func revenueByService(
        for appointments: [Appointment],
        charges: [Charge]
    ) -> [Appointment.ServiceType: Double] {
        // Map appointment IDs to their service types
        let serviceMap = Dictionary(uniqueKeysWithValues:
            appointments.map { ($0.id, $0.serviceType) }
        )
        // Accumulate charge amounts for matching appointments
        return charges.reduce(into: [:]) { sums, charge in
            guard
                let appt = charge.appointment,
                let type = serviceMap[appt.id]
            else { return }
            sums[type, default: 0] += charge.amount
        }
    }
    
    
    // MARK: – Combined Metrics
    
    /// Builds combined metrics (frequency, average duration, total revenue) for all service types.
    /// - Parameters:
    ///   - appointments: Array of Appointment instances.
    ///   - charges: Array of Charge instances.
    /// - Returns: A dictionary mapping each service type to its ServiceMetrics.
    /// - Note: This is an async method running off the main thread.
    static func metrics(
        for appointments: [Appointment],
        charges: [Charge]
    ) async -> [Appointment.ServiceType: ServiceMetrics] {
        // Compute frequency and duration
        async let freqAndDur: [Appointment.ServiceType: (frequency: Int, durationSum: Double, durationCount: Int)] = runAsync {
            appointments.reduce(into: [:]) { acc, appt in
                let type = appt.serviceType
                var entry = acc[type] ?? (0, 0, 0)
                entry.frequency += 1
                if let dur = appt.durationMinutes {
                    entry.durationSum += Double(dur)
                    entry.durationCount += 1
                }
                acc[type] = entry
            }
        }
        // Compute revenue by service type
        async let revenueMap: [Appointment.ServiceType: Double] = runAsync {
            let serviceMap = Dictionary(uniqueKeysWithValues:
                appointments.map { ($0.id, $0.serviceType) }
            )
            return charges.reduce(into: [:]) { sums, charge in
                guard let appt = charge.appointment,
                      let type = serviceMap[appt.id] else { return }
                sums[type, default: 0] += charge.amount
            }
        }
        // Await both
        let (stats, revenues) = await (freqAndDur, revenueMap)
        // Build result metrics
        return Appointment.ServiceType.allCases.reduce(into: [:]) { result, type in
            let (frequency, durationSum, durationCount) = stats[type] ?? (0, 0, 0)
            let avgDuration = durationCount > 0 ? durationSum / Double(durationCount) : 0
            let revenue = revenues[type] ?? 0
            result[type] = ServiceMetrics(
                frequency: frequency,
                averageDuration: avgDuration,
                totalRevenue: revenue
            )
        }
    }
    
    
    // MARK: – Top Services Helpers

    /// Generic helper to return top-N service metrics by a provided selector.
    /// - Parameters:
    ///   - metrics: Dictionary of service type to ServiceMetrics.
    ///   - limit: Maximum number of results.
    ///   - selector: Closure selecting the metric value to sort by.
    /// - Returns: An array of tuples containing service type and metrics.
    private static func topServicesByMetric<T: Comparable>(
        from metrics: [Appointment.ServiceType: ServiceMetrics],
        limit: Int,
        metric selector: (ServiceMetrics) -> T
    ) -> [(type: Appointment.ServiceType, metrics: ServiceMetrics)] {
        metrics
            .sorted { selector($0.value) > selector($1.value) }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Returns the top-N service types by total revenue.
    static func topRevenueServices(
        from metrics: [Appointment.ServiceType: ServiceMetrics],
        limit: Int = 3
    ) -> [(type: Appointment.ServiceType, metrics: ServiceMetrics)] {
        topServicesByMetric(from: metrics, limit: limit) { $0.totalRevenue }
    }

    /// Returns the top-N service types by appointment frequency.
    static func topFrequentServices(
        from metrics: [Appointment.ServiceType: ServiceMetrics],
        limit: Int = 3
    ) -> [(type: Appointment.ServiceType, frequency: Int)] {
        topServicesByMetric(from: metrics, limit: limit) { Double($0.frequency) }
            .map { ($0.type, $0.metrics.frequency) }
    }

    /// Convenience that computes metrics and returns top-N by revenue in one call.
    static func topRevenueServices(
        for appointments: [Appointment],
        charges: [Charge],
        limit: Int = 3
    ) async -> [(type: Appointment.ServiceType, metrics: ServiceMetrics)] {
        let m = await metrics(for: appointments, charges: charges)
        return topRevenueServices(from: m, limit: limit)
    }

    /// Returns the top-N service types by revenue per minute.
    static func topRevenuePerMinuteServices(
        from metrics: [Appointment.ServiceType: ServiceMetrics],
        limit: Int = 3
    ) -> [(type: Appointment.ServiceType, value: Double)] {
        metrics
            .map { (type: $0.key, value: $0.value.revenuePerMinute) }
            .sorted(by: { $0.value > $1.value })
            .prefix(limit)
            .map { (type: $0.type, value: $0.value) }
    }

    /// Convenience that computes metrics and returns top-N by revenue per minute in one call.
    static func topRevenuePerMinuteServices(
        for appointments: [Appointment],
        charges: [Charge],
        limit: Int = 3
    ) async -> [(type: Appointment.ServiceType, value: Double)] {
        let m = await metrics(for: appointments, charges: charges)
        return topRevenuePerMinuteServices(from: m, limit: limit)
    }
}
