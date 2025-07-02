//  RevenueGoalWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Revenue Goal Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct RevenueGoalAuditEvent: Codable {
    let timestamp: Date
    let goal: Double
    let actual: Double
    let percent: Double
    let status: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let percentStr = String(format: "%.1f", percent * 100)
        return "[Appear] RevenueGoalWidget: goal \(goal), actual \(actual), \(percentStr)%% (\(status)) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class RevenueGoalAudit {
    static private(set) var log: [RevenueGoalAuditEvent] = []

    /// Records a new audit event with the given parameters.
    static func record(
        goal: Double,
        actual: Double,
        percent: Double,
        status: String,
        tags: [String] = ["revenueGoalWidget"]
    ) {
        let event = RevenueGoalAuditEvent(
            timestamp: Date(),
            goal: goal,
            actual: actual,
            percent: percent,
            status: status,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as a CSV string with columns: timestamp,goal,actual,percent,status,tags.
    static func exportCSV() -> String {
        let header = "timestamp,goal,actual,percent,status,tags"
        let rows = log.map { event in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|")
            return "\(dateStr),\(event.goal),\(event.actual),\(event.percent),\(event.status),\(tagsStr)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Accessibility label summary of the last event or a default message.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No revenue goal widget events recorded."
    }
    
    /// Returns the accessibility labels of the most recent audit events, limited by `limit`.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    // MARK: - Analytics Enhancements
    
    /// Computes the average percent value of all audit events.
    static var averagePercent: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0.0) { $0 + $1.percent }
        return total / Double(log.count)
    }
    
    /// Determines the most frequent status string among all audit events.
    static var mostFrequentStatus: String {
        guard !log.isEmpty else { return "none" }
        let frequency = Dictionary(grouping: log, by: { $0.status })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key ?? "none"
    }
    
    /// Total number of audit events recorded.
    static var totalDisplays: Int {
        log.count
    }
}

// MARK: - RevenueGoalWidget

public struct RevenueGoalWidget: View {
    public let goal: Double
    public let actual: Double
    public let period: String

    private var percent: Double {
        goal > 0 ? min(actual / goal, 1.0) : 0
    }
    private var status: String {
        percent >= 1.0 ? "achieved" : (percent >= 0.9 ? "almost" : "in progress")
    }
    private var color: Color {
        percent >= 1.0 ? .green : (percent >= 0.9 ? .yellow : .accentColor)
    }
    private var currency: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencySymbol = "$"
        return f
    }

    public init(goal: Double, actual: Double, period: String) {
        self.goal = goal
        self.actual = actual
        self.period = period
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Revenue Goal (\(period))")
                    .font(.headline)
                    .accessibilityIdentifier("RevenueGoalWidget-Title")
            }
            .padding(.bottom, 2)

            ProgressView(value: percent)
                .accentColor(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(height: 16)
                .accessibilityLabel("Revenue progress bar")
                .accessibilityIdentifier("RevenueGoalWidget-ProgressBar")

            HStack {
                VStack(alignment: .leading) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency.string(from: NSNumber(value: goal)) ?? "$0")
                        .font(.headline)
                        .accessibilityIdentifier("RevenueGoalWidget-GoalValue")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency.string(from: NSNumber(value: actual)) ?? "$0")
                        .font(.headline)
                        .foregroundColor(color)
                        .accessibilityIdentifier("RevenueGoalWidget-ActualValue")
                }
            }
            .padding(.top, 4)

            HStack {
                Text(String(format: "%.0f%%", percent * 100))
                    .font(.title2.bold())
                    .foregroundColor(color)
                    .accessibilityIdentifier("RevenueGoalWidget-PercentLabel")
                Text(status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("RevenueGoalWidget-StatusLabel")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("RevenueGoalWidget-Container")
        .onAppear {
            RevenueGoalAudit.record(
                goal: goal,
                actual: actual,
                percent: percent,
                status: status
            )
            // Accessibility: Post VoiceOver announcement if percent < 0.5
            if percent < 0.5 {
                UIAccessibility.post(notification: .announcement, argument: "Warning: Revenue goal progress below 50 percent.")
            }
        }
        #if DEBUG
        // DEV overlay showing recent audit info and analytics for debugging purposes
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit Events (last 3):")
                    .font(.caption).bold()
                ForEach(RevenueGoalAudit.recentEvents(limit: 3), id: \.self) { event in
                    Text(event)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(String(format: "Average Percent: %.2f%%", RevenueGoalAudit.averagePercent * 100))
                    .font(.caption2)
                Text("Most Frequent Status: \(RevenueGoalAudit.mostFrequentStatus)")
                    .font(.caption2)
                Text("Total Displays: \(RevenueGoalAudit.totalDisplays)")
                    .font(.caption2)
            }
            .padding(6)
            .background(Color(.systemBackground).opacity(0.85))
            .cornerRadius(8)
            .padding([.leading, .trailing, .bottom], 8),
            alignment: .bottom
        )
        #endif
    }

    private var accessibilitySummary: String {
        let percentStr = String(format: "%.0f", percent * 100)
        return "Revenue goal progress for \(period). Goal \(currency.string(from: NSNumber(value: goal)) ?? "$0"), actual \(currency.string(from: NSNumber(value: actual)) ?? "$0"), \(percentStr) percent, status: \(status)"
    }
}

// MARK: - Audit/Admin Accessors

public enum RevenueGoalWidgetAuditAdmin {
    public static var lastSummary: String { RevenueGoalAudit.accessibilitySummary }
    public static var lastJSON: String? { RevenueGoalAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        RevenueGoalAudit.recentEvents(limit: limit)
    }
    
    // Expose CSV export for audit events
    public static func exportCSV() -> String {
        RevenueGoalAudit.exportCSV()
    }
    
    // Expose analytics properties
    public static var averagePercent: Double {
        RevenueGoalAudit.averagePercent
    }
    public static var mostFrequentStatus: String {
        RevenueGoalAudit.mostFrequentStatus
    }
    public static var totalDisplays: Int {
        RevenueGoalAudit.totalDisplays
    }
}

// MARK: - Preview

#if DEBUG
struct RevenueGoalWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RevenueGoalWidget(goal: 15000, actual: 13300, period: "June")
                .previewLayout(.sizeThatFits)
                .padding()
            RevenueGoalWidget(goal: 15000, actual: 15500, period: "June")
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
#endif
