//
//  DashboardAccessibilitySummary.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Accessibility Summary Provider
//

import Foundation

/// Provides accessibility summary strings for Furfolio dashboard components, with full audit/event logging.
struct DashboardAccessibilitySummary {

    // MARK: - Audit/Event Logging

    fileprivate struct DashboardSummaryAuditEvent: Codable {
        let timestamp: Date
        let summaryType: String
        let values: [String: String]
        let result: String
        let tags: [String]
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let valuesStr = values.map { "\($0): \($1)" }.joined(separator: ", ")
            return "[\(summaryType)] \(valuesStr) → \(result) [\(tags.joined(separator: ","))] at \(dateStr)"
        }
    }

    // MARK: - Audit/Event Logging and Analytics Enhancements
    ///
    /// Audit event tracker for dashboard summary events.
    /// - Enhanced: CSV export, analytics, and developer overlay support.
    /// - Analytics: mostFrequentSummaryType, totalSummaries.
    /// - CSV: exportCSV() for exporting all audit events.
    /// - In DEBUG: supports developer overlay view.
    fileprivate final class Audit {
        static private(set) var log: [DashboardSummaryAuditEvent] = []

        /// Records a new audit event and maintains log size.
        static func record(
            summaryType: String,
            values: [String: String],
            result: String,
            tags: [String]
        ) {
            let event = DashboardSummaryAuditEvent(
                timestamp: Date(),
                summaryType: summaryType,
                values: values,
                result: result,
                tags: tags
            )
            log.append(event)
            if log.count > 100 { log.removeFirst() }
        }

        /// Exports the last audit event as JSON.
        static func exportLastJSON() -> String? {
            guard let last = log.last else { return nil }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }

        /// Exports all audit events as CSV.
        /// CSV columns: timestamp,summaryType,values,result,tags
        static func exportCSV() -> String {
            let header = "timestamp,summaryType,values,result,tags"
            let formatter = ISO8601DateFormatter()
            let rows = log.map { event in
                let timestamp = formatter.string(from: event.timestamp)
                let summaryType = event.summaryType.replacingOccurrences(of: ",", with: " ")
                let values = event.values.map { "\($0)=\($1)" }.joined(separator: ";").replacingOccurrences(of: ",", with: ";")
                let result = event.result.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: ",", with: ";")
                let tags = event.tags.joined(separator: "|").replacingOccurrences(of: ",", with: "|")
                return "\"\(timestamp)\",\"\(summaryType)\",\"\(values)\",\"\(result)\",\"\(tags)\""
            }
            return ([header] + rows).joined(separator: "\n")
        }

        /// Returns the accessibility label of the last event.
        static var accessibilitySummary: String {
            log.last?.accessibilityLabel ?? "No dashboard summary events recorded."
        }

        /// The most frequent summaryType in audit events.
        static var mostFrequentSummaryType: String? {
            let types = log.map { $0.summaryType }
            let freq = Dictionary(types.map { ($0, 1) }, uniquingKeysWith: +)
            return freq.sorted { $0.value > $1.value }.first?.key
        }

        /// The total number of audit events.
        static var totalSummaries: Int {
            log.count
        }
    }

    /// Returns a summary of appointments for accessibility.
    /// - Enhancement: Posts a VoiceOver announcement for accessibility after summary generation.
    static func appointmentSummary(upcomingCount: Int, completedCount: Int) -> String {
        let summary: String
        switch (upcomingCount, completedCount) {
        case (0, 0):
            summary = "You have no appointments scheduled or completed."
        case (_, 0):
            summary = "You have \(upcomingCount) upcoming appointments."
        case (0, _):
            summary = "You have \(completedCount) completed appointments."
        default:
            summary = "You have \(upcomingCount) upcoming appointments and \(completedCount) completed appointments."
        }
        Audit.record(
            summaryType: "appointment",
            values: [
                "upcomingCount": "\(upcomingCount)",
                "completedCount": "\(completedCount)"
            ],
            result: summary,
            tags: ["appointment"]
        )
        // Accessibility enhancement: announce summary.
        announceAccessibility(summary)
        return summary
    }

    /// Returns a summary of revenue data for accessibility.
    /// - Enhancement: Posts a VoiceOver announcement for accessibility after summary generation.
    static func revenueSummary(totalRevenue: Double, revenueChangePercent: Double) -> String {
        let formattedRevenue = formatCurrency(totalRevenue)
        let changeDescription: String

        switch revenueChangePercent {
        case let x where x > 0:
            changeDescription = "increased by \(String(format: "%.1f", x)) percent"
        case let x where x < 0:
            changeDescription = "decreased by \(String(format: "%.1f", abs(x))) percent"
        default:
            changeDescription = "no change from last month"
        }

        let summary = "Total revenue is \(formattedRevenue), \(changeDescription)."
        Audit.record(
            summaryType: "revenue",
            values: [
                "totalRevenue": "\(totalRevenue)",
                "revenueChangePercent": "\(revenueChangePercent)"
            ],
            result: summary,
            tags: ["revenue"]
        )
        // Accessibility enhancement: announce summary.
        announceAccessibility(summary)
        return summary
    }

    /// Returns a summary of customer retention stats.
    /// - Enhancement: Posts a VoiceOver announcement for accessibility after summary generation.
    static func retentionSummary(totalCustomers: Int, inactiveCustomers: Int) -> String {
        let summary: String
        if totalCustomers == 0 {
            summary = "You have no customers yet."
        } else if inactiveCustomers == 0 {
            summary = "All \(totalCustomers) customers are active."
        } else {
            summary = "There are \(totalCustomers) customers in total, with \(inactiveCustomers) inactive customers."
        }
        Audit.record(
            summaryType: "retention",
            values: [
                "totalCustomers": "\(totalCustomers)",
                "inactiveCustomers": "\(inactiveCustomers)"
            ],
            result: summary,
            tags: ["retention"]
        )
        // Accessibility enhancement: announce summary.
        announceAccessibility(summary)
        return summary
    }

    /// Returns a summary of loyalty program status.
    /// - Enhancement: Posts a VoiceOver announcement for accessibility after summary generation.
    static func loyaltySummary(totalPoints: Int, pointsToNextReward: Int) -> String {
        let summary: String
        if totalPoints == 0 {
            summary = "You haven't earned any loyalty points yet."
        } else if pointsToNextReward == 0 {
            summary = "You have \(totalPoints) loyalty points and have earned your next reward."
        } else {
            summary = "You have \(totalPoints) loyalty points. \(pointsToNextReward) points to your next reward."
        }
        Audit.record(
            summaryType: "loyalty",
            values: [
                "totalPoints": "\(totalPoints)",
                "pointsToNextReward": "\(pointsToNextReward)"
            ],
            result: summary,
            tags: ["loyalty"]
        )
        // Accessibility enhancement: announce summary.
        announceAccessibility(summary)
        return summary
    }

    // MARK: - Helpers

    private static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    // MARK: - Audit/Admin Accessors and Analytics

    /// The last audit event's accessibility summary string.
    public static var lastSummary: String { Audit.accessibilitySummary }
    /// The last audit event as JSON.
    public static var lastJSON: String? { Audit.exportLastJSON() }
    /// The last N audit events' accessibility labels.
    public static func recentEvents(limit: Int = 5) -> [String] {
        Audit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Exports all audit events as CSV.
    public static func exportCSV() -> String { Audit.exportCSV() }
    /// The most frequent summaryType in audit history.
    public static var mostFrequentSummaryType: String? { Audit.mostFrequentSummaryType }
    /// The total number of audit events.
    public static var totalSummaries: Int { Audit.totalSummaries }

    // MARK: - Accessibility Announcements
    /// Posts a VoiceOver announcement with the given summary string (iOS only).
    private static func announceAccessibility(_ summary: String) {
#if canImport(UIKit)
        // Only post if running in iOS environment.
        import UIKit
        UIAccessibility.post(notification: .announcement, argument: summary)
#endif
    }

#if DEBUG
    // MARK: - Developer Overlay View (DEBUG Only)
    //
    // SwiftUI overlay for developer audit/analytics.
    // Shows last 3 audit events, most frequent summaryType, and total summaries.
    import SwiftUI
    struct DashboardSummaryAuditOverlayView: View {
        @State private var eventCount: Int = DashboardAccessibilitySummary.totalSummaries
        @State private var mostFrequent: String = DashboardAccessibilitySummary.mostFrequentSummaryType ?? "-"
        @State private var lastEvents: [String] = DashboardAccessibilitySummary.recentEvents(limit: 3)

        private func refresh() {
            eventCount = DashboardAccessibilitySummary.totalSummaries
            mostFrequent = DashboardAccessibilitySummary.mostFrequentSummaryType ?? "-"
            lastEvents = DashboardAccessibilitySummary.recentEvents(limit: 3)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔎 Dashboard Summary Audit (DEV)").font(.headline)
                Text("Total summaries: \(eventCount)")
                Text("Most frequent type: \(mostFrequent)")
                Divider()
                Text("Recent Events:")
                ForEach(lastEvents.indices, id: \.self) { idx in
                    Text(lastEvents[idx])
                        .font(.caption)
                        .lineLimit(2)
                }
                Button("Refresh") { refresh() }
                    .font(.caption)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(radius: 3)
            .onAppear(perform: refresh)
        }
    }
#endif
}
