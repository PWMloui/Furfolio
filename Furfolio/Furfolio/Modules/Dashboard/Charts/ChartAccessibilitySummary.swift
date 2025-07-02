//
//  ChartAccessibilitySummary.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Chart Summary Provider
//

import Foundation
import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

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

        /// Records a new audit event and trims log to last 60 entries.
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

        /// Exports the last audit event as a pretty-printed JSON string.
        static func exportLastJSON() -> String? {
            guard let last = log.last else { return nil }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }

        /// Exports all audit events as CSV with columns: timestamp,summaryType,input,result,tags.
        /// Inputs and tags are serialized as JSON strings for CSV integrity.
        static func exportCSV() -> String {
            let header = "timestamp,summaryType,input,result,tags"
            let rows = log.map { event -> String in
                let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
                // Serialize input dictionary and tags array as JSON strings to preserve structure
                let inputData = (try? JSONSerialization.data(withJSONObject: event.input, options: []))
                let inputStr = inputData.flatMap { String(data: $0, encoding: .utf8) }?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                let tagsData = (try? JSONSerialization.data(withJSONObject: event.tags, options: []))
                let tagsStr = tagsData.flatMap { String(data: $0, encoding: .utf8) }?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                // Escape result string for CSV by doubling quotes and wrapping in quotes
                let escapedResult = event.result.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(timestampStr)\",\"\(event.summaryType)\",\"\(inputStr)\",\"\(escapedResult)\",\"\(tagsStr)\""
            }
            return ([header] + rows).joined(separator: "\n")
        }

        /// Returns an accessibility summary string for the most recent audit event or a default message.
        static var accessibilitySummary: String {
            log.last?.accessibilityLabel ?? "No chart summary events recorded."
        }

        /// Returns the summaryType with the highest frequency among audit events.
        /// If no events, returns nil.
        static var mostFrequentSummaryType: String? {
            guard !log.isEmpty else { return nil }
            let freq = Dictionary(grouping: log, by: { $0.summaryType })
                .mapValues { $0.count }
            return freq.max(by: { $0.value < $1.value })?.key
        }

        /// Returns the total number of audit events recorded.
        static var totalSummaries: Int {
            log.count
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
    /// Posts a VoiceOver announcement with the summary string.
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
        // Post VoiceOver announcement for accessibility
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: summary)
        }
        #endif
        return summary
    }

    /// Generates an accessibility label summarizing revenue progress chart data.
    /// Posts a VoiceOver announcement with the summary string.
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
        // Post VoiceOver announcement for accessibility
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: summary)
        }
        #endif
        return summary
    }

    // MARK: - Helpers

    private static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    // MARK: - Audit/Admin Accessors

    /// Returns the accessibility summary string of the last audit event.
    public static var lastSummary: String { Audit.accessibilitySummary }

    /// Returns the last audit event as JSON string.
    public static var lastJSON: String? { Audit.exportLastJSON() }

    /// Returns recent audit events' accessibility labels limited by `limit`.
    public static func recentEvents(limit: Int = 5) -> [String] {
        Audit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    /// Exports all audit events as CSV string.
    public static func exportCSV() -> String {
        Audit.exportCSV()
    }

    /// Returns the most frequent summaryType in audit log, or nil if none.
    public static var mostFrequentSummaryType: String? {
        Audit.mostFrequentSummaryType
    }

    /// Returns the total number of audit events recorded.
    public static var totalSummaries: Int {
        Audit.totalSummaries
    }
}

#if DEBUG
/// SwiftUI overlay view showing last 3 audit events, most frequent summaryType, and total summaries.
/// Useful for development and debugging.
struct ChartSummaryAuditOverlayView: View {
    @State private var auditEvents: [String] = []
    @State private var mostFrequent: String = "N/A"
    @State private var totalSummaries: Int = 0

    private func refreshData() {
        auditEvents = ChartAccessibilitySummary.recentEvents(limit: 3)
        mostFrequent = ChartAccessibilitySummary.mostFrequentSummaryType ?? "N/A"
        totalSummaries = ChartAccessibilitySummary.totalSummaries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chart Summary Audit Overlay")
                .font(.headline)
            Text("Most Frequent Summary Type: \(mostFrequent)")
            Text("Total Summaries: \(totalSummaries)")
            Divider()
            Text("Last 3 Audit Events:")
                .font(.subheadline)
            ForEach(auditEvents, id: \.self) { event in
                Text(event)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.85))
        .cornerRadius(10)
        .shadow(radius: 5)
        .onAppear(perform: refreshData)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshData()
        }
    }
}
#endif
