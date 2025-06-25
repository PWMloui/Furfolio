//
//  ChartAccessibilitySummary.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Chart Summary Provider
//

import Foundation
import SwiftUI
import Charts

/// Utility to generate accessibility summary strings for charts displaying appointment or revenue data,
/// with audit/event logging and export for trust center/BI.
struct ChartAccessibilitySummary {

    // MARK: - Audit/Event Logging

    fileprivate struct ChartSummaryAuditEvent: Codable {
        let timestamp: Date
        let summaryType: String
        let input: [String: String]
        let result: String
        let tags: [String]
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let inputStr = input.map { "\($0): \($1)" }.joined(separator: ", ")
            return "[\(summaryType)] \(inputStr) → \(result) [\(tags.joined(separator: ","))] at \(dateStr)"
        }
    }

    fileprivate final class Audit {
        static private(set) var log: [ChartSummaryAuditEvent] = []

        static func record(
            summaryType: String,
            input: [String: String],
            result: String,
            tags: [String]
        ) {
            let event = ChartSummaryAuditEvent(
                timestamp: Date(),
                summaryType: summaryType,
                input: input,
                result: result,
                tags: tags
            )
            log.append(event)
            if log.count > 60 { log.removeFirst() }
        }

        static func exportLastJSON() -> String? {
            guard let last = log.last else { return nil }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }

        static var accessibilitySummary: String {
            log.last?.accessibilityLabel ?? "No chart summary events recorded."
        }
    }

    // MARK: - Formatters

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

    // MARK: - Public API

    /// Generates an accessibility label summarizing appointment volume chart data.
    static func appointmentVolumeSummary(appointmentsByDate: [Date: Int]) -> String {
        let totalAppointments = appointmentsByDate.values.reduce(0, +)
        let maxAppointments = appointmentsByDate.values.max() ?? 0

        let maxDates = appointmentsByDate
            .filter { $0.value == maxAppointments }
            .map { $0.key }
            .sorted()

        let maxDatesStr = maxDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")

        let summary = "There were \(totalAppointments) appointments in total. The busiest day(s): \(maxDatesStr) with \(maxAppointments) appointments."
        Audit.record(
            summaryType: "appointmentVolume",
            input: [
                "totalAppointments": "\(totalAppointments)",
                "maxAppointments": "\(maxAppointments)",
                "maxDates": maxDatesStr
            ],
            result: summary,
            tags: ["appointment", "chartSummary"]
        )
        return summary
    }

    /// Generates an accessibility label summarizing revenue progress chart data.
    static func revenueGoalSummary(currentRevenue: Double, goalRevenue: Double) -> String {
        let summary: String
        if goalRevenue <= 0 {
            summary = "Current revenue is \(formatCurrency(currentRevenue)). No goal has been set."
        } else {
            let percent = (currentRevenue / goalRevenue * 100).rounded()
            summary = "Current revenue is \(formatCurrency(currentRevenue)), which is \(Int(percent))% of the goal of \(formatCurrency(goalRevenue))."
        }
        Audit.record(
            summaryType: "revenueGoal",
            input: [
                "currentRevenue": "\(currentRevenue)",
                "goalRevenue": "\(goalRevenue)"
            ],
            result: summary,
            tags: ["revenue", "goal", "chartSummary"]
        )
        return summary
    }

    // MARK: - Helpers

    private static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    // MARK: - Audit/Admin Accessors

    public static var lastSummary: String { Audit.accessibilitySummary }
    public static var lastJSON: String? { Audit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        Audit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
