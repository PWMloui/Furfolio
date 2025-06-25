//
//  ChartHighlightBadge.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Highlight Badge
//

import SwiftUI

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No chart highlight badge events recorded."
    }
}

// MARK: - ChartHighlightBadge

struct ChartHighlightBadge: View {
    let text: String
    var backgroundColor: Color = .accentColor

    @Environment(\.colorScheme) private var colorScheme

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
            }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChartHighlightBadgeAuditAdmin {
    public static var lastSummary: String { ChartHighlightBadgeAudit.accessibilitySummary }
    public static var lastJSON: String? { ChartHighlightBadgeAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChartHighlightBadgeAudit.log.suffix(limit).map { $0.accessibilityLabel }
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
