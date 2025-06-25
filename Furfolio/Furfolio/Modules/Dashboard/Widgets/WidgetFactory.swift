//
//  WidgetFactory.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Scalable Widget Factory
//

import SwiftUI

enum WidgetType: String, CaseIterable, Identifiable {
    case kpi
    case topClients
    case serviceTrends
    case revenueGoal
    // Add more as needed

    var id: String { self.rawValue }
}

final class WidgetFactory {
    /// Audit log for widget creation events
    private static var creationLog: [WidgetFactoryEvent] = []

    /// Auditable event model
    struct WidgetFactoryEvent: Codable {
        let timestamp: Date
        let widgetType: String
        let configuration: String
        var summary: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "[Create] Widget \(widgetType), config: \(configuration) at \(dateStr)"
        }
    }

    static func makeWidget(of type: WidgetType, configuration: WidgetConfiguration) -> AnyView {
        // Audit
        recordCreation(of: type, configuration: configuration)

        switch type {
        case .kpi:
            return AnyView(
                KPIWidget(configuration: configuration)
                    .accessibilityIdentifier("WidgetFactory-KPIWidget")
            )
        case .topClients:
            return AnyView(
                TopClientsWidget(configuration: configuration)
                    .accessibilityIdentifier("WidgetFactory-TopClientsWidget")
            )
        case .serviceTrends:
            return AnyView(
                ServiceTrendsWidget(configuration: configuration)
                    .accessibilityIdentifier("WidgetFactory-ServiceTrendsWidget")
            )
        case .revenueGoal:
            return AnyView(
                RevenueGoalWidget(configuration: configuration)
                    .accessibilityIdentifier("WidgetFactory-RevenueGoalWidget")
            )
        }
    }

    /// Audit log functions
    private static func recordCreation(of type: WidgetType, configuration: WidgetConfiguration) {
        let event = WidgetFactoryEvent(
            timestamp: Date(),
            widgetType: type.rawValue,
            configuration: configuration.description
        )
        creationLog.append(event)
        if creationLog.count > 100 { creationLog.removeFirst() }
    }

    /// Export audit log as JSON
    static func exportAuditJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(creationLog)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Recent widget creation summaries for admin/QA
    static func recentCreations(limit: Int = 10) -> [String] {
        creationLog.suffix(limit).map { $0.summary }
    }
}
