//
//  ChartHighlightBadge.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Highlight Badge
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct ChartHighlightBadgeAuditEvent: Codable {
    let timestamp: Date
    let text: String
    let color: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] ChartHighlightBadge: \"\(text)\", color: \(color) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ChartHighlightBadgeAudit {
    static private(set) var log: [ChartHighlightBadgeAuditEvent] = []

    /// Records a new badge display event with text, color, and optional tags.
    static func record(
        text: String,
        color: Color,
        tags: [String] = ["ChartHighlightBadge"]
    ) {
        let colorDesc: String
        switch color {
        case .green: colorDesc = "green"
        case .blue: colorDesc = "blue"
        case .red: colorDesc = "red"
        case .yellow: colorDesc = "yellow"
        case .accentColor: colorDesc = "accentColor"
        case .black: colorDesc = "black"
        default: colorDesc = color.description
        }
        let event = ChartHighlightBadgeAuditEvent(
            timestamp: Date(),
            text: text,
            color: colorDesc,
            tags: tags
        )
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }

    /// Exports the last badge event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary of the last badge event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No chart highlight badge events recorded."
    }

    /// Exports all badge events as a CSV string with header: timestamp,text,color,tags.
    static func exportCSV() -> String {
        let header = "timestamp,text,color,tags"
        let rows = log.map { event in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            // Escape commas and quotes in text and tags
            let escapedText = "\"\(event.text.replacingOccurrences(of: "\"", with: "\"\""))\""
            let escapedColor = "\"\(event.color.replacingOccurrences(of: "\"", with: "\"\""))\""
            let escapedTags = "\"\(event.tags.joined(separator: ",").replacingOccurrences(of: "\"", with: "\"\""))\""
            return "\(dateStr),\(escapedText),\(escapedColor),\(escapedTags)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// The text value that appears most frequently in the badge event log.
    static var mostFrequentText: String? {
        let counts = Dictionary(grouping: log, by: { $0.text }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// The color string that appears most frequently in the badge event log.
    static var mostFrequentColor: String? {
        let counts = Dictionary(grouping: log, by: { $0.color }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of badge events recorded in the log.
    static var totalBadgesShown: Int {
        log.count
    }
}

// MARK: - ChartHighlightBadge

struct ChartHighlightBadge: View {
    let text: String
    var backgroundColor: Color = .accentColor

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    private var foregroundColor: Color {
        backgroundColor.isLightColor ? .black : .white
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
            .accessibilityLabel(Text(text))
            .accessibilityIdentifier("ChartHighlightBadge-\(text)")
            .onAppear {
                ChartHighlightBadgeAudit.record(
                    text: text,
                    color: backgroundColor
                )
                // Accessibility: Post VoiceOver announcement on appear
                if accessibilityEnabled {
                    UIAccessibility.post(notification: .announcement, argument: "\(text) highlight badge displayed.")
                }
            }
            // DEV overlay in DEBUG builds showing audit info
            #if DEBUG
            .overlay(
                ChartHighlightBadgeDebugOverlay()
                    .padding(.top, 50),
                alignment: .bottom
            )
            #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum ChartHighlightBadgeAuditAdmin {
    /// Last event summary string for accessibility.
    public static var lastSummary: String { ChartHighlightBadgeAudit.accessibilitySummary }
    /// Last event JSON export.
    public static var lastJSON: String? { ChartHighlightBadgeAudit.exportLastJSON() }
    /// Recent event accessibility labels limited by count.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChartHighlightBadgeAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Export all events as CSV string.
    public static func exportCSV() -> String {
        ChartHighlightBadgeAudit.exportCSV()
    }
    /// Most frequent badge text displayed.
    public static var mostFrequentText: String? {
        ChartHighlightBadgeAudit.mostFrequentText
    }
    /// Most frequent badge color displayed.
    public static var mostFrequentColor: String? {
        ChartHighlightBadgeAudit.mostFrequentColor
    }
    /// Total number of badges shown.
    public static var totalBadgesShown: Int {
        ChartHighlightBadgeAudit.totalBadgesShown
    }
}

// MARK: - Color extension for luminance check

private extension Color {
    var isLightColor: Bool {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.6
        #else
        return false
        #endif
    }
}

// MARK: - DEV Overlay View for Debugging

#if DEBUG
/// A SwiftUI overlay view that displays recent audit events and summary statistics for debugging.
private struct ChartHighlightBadgeDebugOverlay: View {
    // Observe changes to the audit log using a timer to trigger updates.
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // Limit of recent events to show in overlay
    private let recentLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📊 ChartHighlightBadge Audit (last \(recentLimit)):")
                .font(.footnote.bold())
                .foregroundColor(.white)
            ForEach(Array(ChartHighlightBadgeAudit.log.suffix(recentLimit).enumerated()), id: \.offset) { index, event in
                Text("• \(event.text) | \(event.color) | \(event.tags.joined(separator: ","))")
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Divider().background(Color.white.opacity(0.7))
            Group {
                Text("Most Frequent Text: \(ChartHighlightBadgeAudit.mostFrequentText ?? "N/A")")
                Text("Most Frequent Color: \(ChartHighlightBadgeAudit.mostFrequentColor ?? "N/A")")
                Text("Total Badges Shown: \(ChartHighlightBadgeAudit.totalBadgesShown)")
            }
            .font(.caption2.monospaced())
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(8)
        .background(Color.black.opacity(0.75))
        .cornerRadius(10)
        .padding(.horizontal)
        .onReceive(timer) { _ in
            // Trigger view update every second to reflect latest logs
        }
    }
}
#endif

// MARK: - Previews

#if DEBUG
struct ChartHighlightBadge_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach([Color.accentColor, .green, .blue, .red, .yellow, .black], id: \.self) { color in
                ChartHighlightBadge(text: color.description.capitalized, backgroundColor: color)
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.light)

            ForEach([Color.accentColor, .green, .blue, .red, .yellow, .black], id: \.self) { color in
                ChartHighlightBadge(text: color.description.capitalized, backgroundColor: color)
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
        }
    }
}
#endif
