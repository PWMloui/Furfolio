//
//  TrendIndicator.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Trend Indicator
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct TrendIndicatorAuditEvent: Codable {
    let timestamp: Date
    let direction: String // "up", "down", "flat"
    let value: Double
    let color: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] TrendIndicator: \(direction), value \(value), color \(color) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class TrendIndicatorAudit {
    static private(set) var log: [TrendIndicatorAuditEvent] = []

    /// Records a new audit event with given parameters.
    /// - Parameters:
    ///   - direction: Trend direction ("up", "down", "flat").
    ///   - value: Numeric value of the trend.
    ///   - color: Color representing the trend.
    ///   - tags: Optional tags for categorization.
    static func record(
        direction: String,
        value: Double,
        color: Color,
        tags: [String] = ["trendIndicator"]
    ) {
        let colorDesc: String
        switch color {
        case .green: colorDesc = "green"
        case .red: colorDesc = "red"
        case .gray: colorDesc = "gray"
        case .accentColor: colorDesc = "accentColor"
        default: colorDesc = color.description
        }
        let event = TrendIndicatorAuditEvent(
            timestamp: Date(),
            direction: direction,
            value: value,
            color: colorDesc,
            tags: tags
        )
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    /// - Returns: JSON string of last event or nil if no events.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No trend indicator events recorded."
    }

    /// Returns the accessibility labels of recent audit events up to a limit.
    /// - Parameter limit: Number of recent events to return.
    /// - Returns: Array of accessibility labels.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - New Enhancements

    /// Exports all audit events as CSV string with headers: timestamp,direction,value,color,tags
    /// - Returns: CSV formatted string of all audit events.
    static func exportCSV() -> String {
        let header = "timestamp,direction,value,color,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: ";")
            return "\"\(timestampStr)\",\"\(event.direction)\",\"\(event.value)\",\"\(event.color)\",\"\(tagsStr)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// The most frequent trend direction in the audit log.
    /// Returns "up", "down", or "flat". Returns "none" if no events.
    static var mostFrequentDirection: String {
        guard !log.isEmpty else { return "none" }
        let counts = Dictionary(grouping: log, by: { $0.direction })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "none"
    }

    /// The average value of all audit events.
    /// Returns 0 if no events.
    static var averageValue: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.value }
        return total / Double(log.count)
    }
}

// MARK: - TrendIndicator

public struct TrendIndicator: View {
    public let value: Double
    public let showPlus: Bool
    public let decimals: Int

    private var direction: String {
        if value > 0 { return "up" }
        if value < 0 { return "down" }
        return "flat"
    }
    private var color: Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .gray
    }
    private var arrow: String {
        switch direction {
        case "up": return "arrow.up"
        case "down": return "arrow.down"
        default: return "minus"
        }
    }

    public init(value: Double, showPlus: Bool = true, decimals: Int = 1) {
        self.value = value
        self.showPlus = showPlus
        self.decimals = decimals
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.caption)
                .foregroundColor(color)
                .accessibilityIdentifier("TrendIndicator-Arrow")
            Text(trendString)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
                .accessibilityIdentifier("TrendIndicator-Value")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("TrendIndicator-Container")
        .onAppear {
            TrendIndicatorAudit.record(
                direction: direction,
                value: value,
                color: color
            )
            // Accessibility enhancement:
            // If trend is "down" and value <= -5.0, post a VoiceOver announcement warning.
            if direction == "down" && value <= -5.0 {
                UIAccessibility.post(notification: .announcement, argument: "Warning: Significant negative trend detected.")
            }
        }
    }

    private var trendString: String {
        let sign = value > 0 && showPlus ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimals)f", value))%"
    }

    private var accessibilityLabel: String {
        switch direction {
        case "up": return "Trend up, \(trendString)"
        case "down": return "Trend down, \(trendString)"
        default: return "No trend, \(trendString)"
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum TrendIndicatorAuditAdmin {
    public static var lastSummary: String { TrendIndicatorAudit.accessibilitySummary }
    public static var lastJSON: String? { TrendIndicatorAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TrendIndicatorAudit.recentEvents(limit: limit)
    }

    // Expose new CSV export
    public static func exportCSV() -> String {
        TrendIndicatorAudit.exportCSV()
    }

    // Expose analytics properties
    public static var mostFrequentDirection: String {
        TrendIndicatorAudit.mostFrequentDirection
    }

    public static var averageValue: Double {
        TrendIndicatorAudit.averageValue
    }
}

// MARK: - Preview

#if DEBUG
/// Developer overlay view showing last 3 audit events, most frequent direction, and average value.
private struct TrendIndicatorAuditOverlay: View {
    @State private var events: [String] = []
    @State private var mostFreq: String = ""
    @State private var avgValue: Double = 0

    private var refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🔍 Audit Events (Last 3):")
                .font(.caption).bold()
            ForEach(events, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text("Most Frequent Direction: \(mostFreq)")
                .font(.caption2).bold()
            Text(String(format: "Average Value: %.2f%%", avgValue))
                .font(.caption2).bold()
        }
        .padding(8)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding()
        .onReceive(refreshTimer) { _ in
            events = TrendIndicatorAudit.recentEvents(limit: 3)
            mostFreq = TrendIndicatorAudit.mostFrequentDirection
            avgValue = TrendIndicatorAudit.averageValue
        }
    }
}

struct TrendIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 18) {
            TrendIndicator(value: 3.5)
            TrendIndicator(value: -1.2)
            TrendIndicator(value: 0)
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .overlay(
            // DEV overlay at bottom showing audit info
            VStack {
                Spacer()
                TrendIndicatorAuditOverlay()
            }
        )
    }
}
#else
struct TrendIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 18) {
            TrendIndicator(value: 3.5)
            TrendIndicator(value: -1.2)
            TrendIndicator(value: 0)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
