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

    fileprivate final class Audit {
        static private(set) var log: [DashboardSummaryAuditEvent] = []

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

        static func exportLastJSON() -> String? {
            guard let last = log.last else { return nil }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }
        static var accessibilitySummary: String {
            log.last?.accessibilityLabel ?? "No dashboard summary events recorded."
        }
    }

    /// Returns a summary of appointments for accessibility.
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
        return summary
    }

    /// Returns a summary of revenue data for accessibility.
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
        return summary
    }

    /// Returns a summary of customer retention stats.
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
        return summary
    }

    /// Returns a summary of loyalty program status.
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

    // MARK: - Audit/Admin Accessors

    public static var lastSummary: String { Audit.accessibilitySummary }
    public static var lastJSON: String? { Audit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        Audit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
