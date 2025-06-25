//
//  TrendIndicator.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Trend Indicator
//

import SwiftUI

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No trend indicator events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
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
}

// MARK: - Preview

#if DEBUG
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
