//
//  DashboardSummaryRow.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Summary Row
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct DashboardSummaryRowAuditEvent: Codable {
    let timestamp: Date
    let iconName: String
    let iconColor: String
    let title: String
    let value: String
    let valueColor: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(title): \(value), icon: \(iconName), iconColor: \(iconColor), valueColor: \(valueColor) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DashboardSummaryRowAudit {
    static private(set) var log: [DashboardSummaryRowAuditEvent] = []

    /// Records a new audit event with the provided details.
    static func record(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String,
        valueColor: Color,
        tags: [String] = ["summaryRow"]
    ) {
        let colorName: (Color) -> String = { color in
            switch color {
            case .blue: return "blue"
            case .green: return "green"
            case .orange: return "orange"
            case .red: return "red"
            case .primary: return "primary"
            default: return color.description
            }
        }
        let event = DashboardSummaryRowAuditEvent(
            timestamp: Date(),
            iconName: iconName,
            iconColor: colorName(iconColor),
            title: title,
            value: value,
            valueColor: colorName(valueColor),
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

    /// Provides an accessibility summary label for the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No dashboard summary row events recorded."
    }
    
    // MARK: - New Analytics Computed Properties
    
    /// Returns the title that appears most frequently in the audit log.
    static var mostFrequentTitle: String? {
        guard !log.isEmpty else { return nil }
        let counts = Dictionary(grouping: log, by: { $0.title }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the valueColor that appears most frequently in the audit log.
    static var mostFrequentValueColor: String? {
        guard !log.isEmpty else { return nil }
        let counts = Dictionary(grouping: log, by: { $0.valueColor }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the total number of audit events recorded.
    static var totalSummaryRows: Int {
        log.count
    }
    
    // MARK: - CSV Export
    
    /// Exports all audit events as a CSV string with headers.
    /// Columns: timestamp,iconName,iconColor,title,value,valueColor,tags
    static func exportCSV() -> String {
        let header = "timestamp,iconName,iconColor,title,value,valueColor,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let escapedTitle = event.title.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedValue = event.value.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedTags = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap fields that may contain commas or quotes in quotes
            return """
            "\(timestampStr)","\(event.iconName)","\(event.iconColor)","\(escapedTitle)","\(escapedValue)","\(event.valueColor)","\(escapedTags)"
            """
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - DashboardSummaryRow

struct DashboardSummaryRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color
    
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(valueColor)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .onAppear {
            DashboardSummaryRowAudit.record(
                iconName: iconName,
                iconColor: iconColor,
                title: title,
                value: value,
                valueColor: valueColor
            )
            // Accessibility: Post VoiceOver announcement on appear
            if accessibilityEnabled {
                let announcement = "\(title): \(value) summary row shown."
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
        #if DEBUG
        // DEV overlay showing audit analytics and recent events
        .overlay(
            VStack(spacing: 4) {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audit Summary")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("Most Frequent Title: \(DashboardSummaryRowAudit.mostFrequentTitle ?? "N/A")")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    Text("Most Frequent ValueColor: \(DashboardSummaryRowAudit.mostFrequentValueColor ?? "N/A")")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    Text("Total Summary Rows: \(DashboardSummaryRowAudit.totalSummaryRows)")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Last 3 Audit Events:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(Array(DashboardSummaryRowAudit.log.suffix(3).enumerated()), id: \.offset) { _, event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(6)
            .background(Color(UIColor.systemBackground).opacity(0.9))
            .cornerRadius(12)
            .padding([.leading, .trailing, .bottom], 8),
            alignment: .bottom
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardSummaryRowAuditAdmin {
    /// Returns the accessibility summary of the last audit event.
    public static var lastSummary: String { DashboardSummaryRowAudit.accessibilitySummary }
    
    /// Returns the last audit event as JSON string.
    public static var lastJSON: String? { DashboardSummaryRowAudit.exportLastJSON() }
    
    /// Returns the most frequent title in audit events.
    public static var mostFrequentTitle: String? { DashboardSummaryRowAudit.mostFrequentTitle }
    
    /// Returns the most frequent valueColor in audit events.
    public static var mostFrequentValueColor: String? { DashboardSummaryRowAudit.mostFrequentValueColor }
    
    /// Returns the total number of audit events recorded.
    public static var totalSummaryRows: Int { DashboardSummaryRowAudit.totalSummaryRows }
    
    /// Returns recent audit events accessibility labels, limited by `limit`.
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardSummaryRowAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    /// Exports all audit events as CSV string.
    public static func exportCSV() -> String {
        DashboardSummaryRowAudit.exportCSV()
    }
}

#if DEBUG
struct DashboardSummaryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardSummaryRow(
                iconName: "chart.bar.fill",
                iconColor: .blue,
                title: "Total Revenue",
                value: "$12,345",
                valueColor: .green
            )
            .previewLayout(.sizeThatFits)
            .padding()

            DashboardSummaryRow(
                iconName: "calendar",
                iconColor: .orange,
                title: "Upcoming Appointments",
                value: "5",
                valueColor: .primary
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif
