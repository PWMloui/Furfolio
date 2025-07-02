//
//  WidgetFactory.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Scalable Widget Factory
//

import SwiftUI
import Combine

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

    /// Public static property returning the widget type created most frequently
    public static var mostFrequentWidgetType: WidgetType? {
        let counts = Dictionary(grouping: creationLog, by: { $0.widgetType })
            .mapValues { $0.count }
        guard let maxEntry = counts.max(by: { $0.value < $1.value }),
              let type = WidgetType(rawValue: maxEntry.key) else {
            return nil
        }
        return type
    }

    /// Public static property returning the total number of widgets created
    public static var totalWidgetsCreated: Int {
        creationLog.count
    }

    static func makeWidget(of type: WidgetType, configuration: WidgetConfiguration) -> AnyView {
        // Audit
        recordCreation(of: type, configuration: configuration)

        // Accessibility: Post VoiceOver announcement on widget creation
        let announcement = "Widget \(type.rawValue) created."
        UIAccessibility.post(notification: .announcement, argument: announcement)

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

    /// Export audit log as CSV
    /// - Returns: CSV string with header: timestamp,widgetType,configuration
    static func exportCSV() -> String {
        var csv = "timestamp,widgetType,configuration\n"
        let formatter = ISO8601DateFormatter()
        for event in creationLog {
            let timestamp = formatter.string(from: event.timestamp)
            // Escape configuration to handle commas or quotes
            let escapedConfig = event.configuration
                .replacingOccurrences(of: "\"", with: "\"\"")
            let configField = "\"\(escapedConfig)\""
            csv += "\(timestamp),\(event.widgetType),\(configField)\n"
        }
        return csv
    }

    /// Recent widget creation summaries for admin/QA
    static func recentCreations(limit: Int = 10) -> [String] {
        creationLog.suffix(limit).map { $0.summary }
    }
}

#if DEBUG
/// SwiftUI overlay view to display recent audit events and analytics in DEBUG builds
struct WidgetFactoryAuditOverlay: View {
    @State private var lastEvents: [WidgetFactory.WidgetFactoryEvent] = []
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 2, on: .main, in: .common)
    @State private var cancellable: Cancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WidgetFactory Audit Overlay")
                .font(.headline)
                .padding(.bottom, 4)
            Text("Most Frequent Widget: \(WidgetFactory.mostFrequentWidgetType?.rawValue ?? "N/A")")
            Text("Total Widgets Created: \(WidgetFactory.totalWidgetsCreated)")
            Divider()
            Text("Last 3 Creations:")
                .font(.subheadline)
            ForEach(lastEvents, id: \.timestamp) { event in
                Text(event.summary)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .cornerRadius(10)
        .onAppear {
            updateEvents()
            cancellable = timer.connect() as? Cancellable
            timer = Timer.publish(every: 2, on: .main, in: .common)
            cancellable = timer.autoconnect().sink { _ in
                updateEvents()
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }

    private func updateEvents() {
        lastEvents = Array(WidgetFactory.creationLog.suffix(3)).reversed()
    }
}
#endif
