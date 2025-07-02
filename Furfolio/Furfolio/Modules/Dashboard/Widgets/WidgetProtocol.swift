//
//  WidgetProtocol.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Configurable, Extensible Widget Protocol with Analytics, CSV, Accessibility, DEV Overlay
//

import SwiftUI

// MARK: - WidgetViewProtocol

/// All dashboard widgets must conform to this protocol.
/// Adds hooks for runtime audit, configuration, and analytics.
protocol WidgetViewProtocol: View {
    var widgetTitle: String { get }
    var icon: Image { get }
    var configuration: WidgetConfiguration { get set }
    /// Called after widget is displayed (for audit/analytics)
    func onAppearAudit()
    /// Optionally surface runtime metrics (e.g. for admin/QA)
    func widgetMetrics() -> [String: Any]
}

// MARK: - WidgetConfiguration

/// Generic, codable widget configuration for dynamic dashboards
struct WidgetConfiguration: Codable, CustomStringConvertible {
    var timeRange: TimeInterval?
    var filters: [String: String]? // Only Codable values for safety
    var parameters: [String: String]? // Arbitrary key-value pairs

    // Allows admin or analytics hooks to query config
    public var description: String {
        var parts: [String] = []
        if let t = timeRange { parts.append("timeRange:\(t)") }
        if let f = filters, !f.isEmpty { parts.append("filters:\(f)") }
        if let p = parameters, !p.isEmpty { parts.append("parameters:\(p)") }
        return parts.isEmpty ? "default" : parts.joined(separator: ", ")
    }

    // Sample static factory for convenience
    static func last30Days() -> WidgetConfiguration {
        .init(timeRange: 60 * 60 * 24 * 30, filters: nil, parameters: nil)
    }
}

// MARK: - WidgetAudit & Admin (Built-in)

// Optional struct for audit logs (can be used by widget implementations)
struct WidgetAuditEvent: Codable {
    let timestamp: Date
    let widgetTitle: String
    let configuration: String
    let action: String
    let extra: [String: String]?
}

final class WidgetAudit {
    static private(set) var log: [WidgetAuditEvent] = []

    static func record(
        widgetTitle: String,
        configuration: String,
        action: String,
        extra: [String: String]? = nil
    ) {
        let event = WidgetAuditEvent(
            timestamp: Date(),
            widgetTitle: widgetTitle,
            configuration: configuration,
            action: action,
            extra: extra
        )
        log.append(event)
        if log.count > 80 { log.removeFirst() }
        // Accessibility: Announce each widget action (for visibility/testing)
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: "Widget \(widgetTitle) action: \(action).")
        #endif
    }

    // MARK: - CSV Export

    /// Export the audit log as CSV (timestamp,widgetTitle,configuration,action,extra)
    static func exportCSV() -> String {
        var csv = "timestamp,widgetTitle,configuration,action,extra\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let ts = dateFormatter.string(from: event.timestamp)
            let config = event.configuration.replacingOccurrences(of: ",", with: ";")
            let extraStr = event.extra?.map { "\($0):\($1)" }.joined(separator: "|").replacingOccurrences(of: ",", with: ";") ?? ""
            csv += "\(ts),\(event.widgetTitle),\(config),\(event.action),\(extraStr)\n"
        }
        return csv
    }

    // MARK: - Analytics

    /// The widget title that appears most frequently in audit
    static var mostFrequentWidget: String? {
        let titles = log.map { $0.widgetTitle }
        let counts = Dictionary(grouping: titles, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    /// The action that occurs most frequently
    static var mostFrequentAction: String? {
        let actions = log.map { $0.action }
        let counts = Dictionary(grouping: actions, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    /// Total widget renders/uses
    static var totalWidgetRenders: Int { log.count }
}

// MARK: - DEV Overlay for Admin/QA (DEBUG only)

#if DEBUG
struct WidgetAuditOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Widget Audit")
                .font(.caption.bold())
                .foregroundColor(.accentColor)
            ForEach(WidgetAudit.log.suffix(3), id: \.timestamp) { event in
                Text("\(event.widgetTitle): \(event.action) at \(event.timestamp.formatted())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let mostWidget = WidgetAudit.mostFrequentWidget {
                Text("Most Widget: \(mostWidget)").font(.caption2)
            }
            if let mostAction = WidgetAudit.mostFrequentAction {
                Text("Most Action: \(mostAction)").font(.caption2)
            }
            Text("Total: \(WidgetAudit.totalWidgetRenders)")
                .font(.caption2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .shadow(radius: 2)
    }
}
#endif

// MARK: - Admin Accessors

public enum WidgetAuditAdmin {
    public static var log: [WidgetAuditEvent] { WidgetAudit.log }
    public static func exportCSV() -> String { WidgetAudit.exportCSV() }
    public static var mostFrequentWidget: String? { WidgetAudit.mostFrequentWidget }
    public static var mostFrequentAction: String? { WidgetAudit.mostFrequentAction }
    public static var totalWidgetRenders: Int { WidgetAudit.totalWidgetRenders }
}
