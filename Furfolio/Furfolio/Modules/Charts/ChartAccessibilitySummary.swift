import Foundation
import SwiftUI
import Charts

/// Utility to generate accessibility summary strings for charts displaying appointment or revenue data.
struct ChartAccessibilitySummary {

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Generates an accessibility label summarizing appointment volume chart data.
    /// - Parameter appointmentsByDate: A dictionary mapping dates to appointment counts.
    /// - Returns: A summary string suitable for VoiceOver.
    static func appointmentVolumeSummary(appointmentsByDate: [Date: Int]) -> String {
        let totalAppointments = appointmentsByDate.values.reduce(0, +)
        let maxAppointments = appointmentsByDate.values.max() ?? 0

        let maxDates = appointmentsByDate
            .filter { $0.value == maxAppointments }
            .map { $0.key }
            .sorted()

        let maxDatesStr = maxDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")

        return "There were \(totalAppointments) appointments in total. The busiest day(s): \(maxDatesStr) with \(maxAppointments) appointments."
    }

    /// Generates an accessibility label summarizing revenue progress chart data.
    /// - Parameters:
    ///   - currentRevenue: The current revenue amount.
    ///   - goalRevenue: The revenue goal amount.
    /// - Returns: A summary string suitable for VoiceOver.
    static func revenueGoalSummary(currentRevenue: Double, goalRevenue: Double) -> String {
        guard goalRevenue > 0 else {
            return "Current revenue is \(formatCurrency(currentRevenue)). No goal has been set."
        }

        let percent = (currentRevenue / goalRevenue * 100).rounded()
        return "Current revenue is \(formatCurrency(currentRevenue)), which is \(Int(percent))% of the goal of \(formatCurrency(goalRevenue))."
    }

    /// Helper to format currency values.
    private static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
