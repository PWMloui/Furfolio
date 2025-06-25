//
//  WidgetProtocol.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Configurable, Extensible Widget Protocol
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

// MARK: - WidgetAudit (Optional)

/// Optional struct for audit logs (can be used by widget implementations)
struct WidgetAuditEvent: Codable {
    let timestamp: Date
    let widgetTitle: String
    let configuration: String
    let action: String
    let extra: [String: String]?
}
