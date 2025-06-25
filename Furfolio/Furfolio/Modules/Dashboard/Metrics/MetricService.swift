//
//  MetricService.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Metric Service
//

import Foundation

// MARK: - Audit/Event Logging

fileprivate struct MetricServiceAuditEvent: Codable {
    let timestamp: Date
    let widgetType: String
    let configurationDescription: String
    let metricsCount: Int
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Fetch] WidgetType: \(widgetType), Config: \(configurationDescription), Metrics: \(metricsCount) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class MetricServiceAudit {
    static private(set) var log: [MetricServiceAuditEvent] = []

    static func record(
        widgetType: String,
        configurationDescription: String,
        metricsCount: Int,
        tags: [String] = ["metricService"]
    ) {
        let event = MetricServiceAuditEvent(
            timestamp: Date(),
            widgetType: widgetType,
            configurationDescription: configurationDescription,
            metricsCount: metricsCount,
            tags: tags
        )
        log.append(event)
        if log.count > 60 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No metric service events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Metric Model

struct Metric {
    let title: String
    let value: Double
    let trend: Double?
    let unit: String?
    // Add other fields as needed

    init(title: String, value: Double, trend: Double? = nil, unit: String? = nil) {
        self.title = title
        self.value = value
        self.trend = trend
        self.unit = unit
    }
}

// MARK: - WidgetType/WidgetConfiguration (Stubs for demonstration)

enum WidgetType: String {
    case revenue
    case appointments
    case customers
    case retention
    // Add more widget types as needed
}

struct WidgetConfiguration: CustomStringConvertible {
    let parameters: [String: Any]
    var description: String {
        parameters.map { "\($0):\($1)" }.joined(separator: ", ")
    }
}

// MARK: - MetricService

class MetricService {
    static let shared = MetricService()
    private let dataSource: MetricDataSource

    // Dependency injection for testability/mock
    init(dataSource: MetricDataSource = MetricLocalStore()) {
        self.dataSource = dataSource
    }

    // Async/await API (modern)
    func fetchMetrics(
        for type: WidgetType,
        configuration: WidgetConfiguration
    ) async throws -> [Metric] {
        let metrics = try await dataSource.fetchMetrics(for: type, configuration: configuration)
        MetricServiceAudit.record(
            widgetType: type.rawValue,
            configurationDescription: configuration.description,
            metricsCount: metrics.count
        )
        return metrics
    }

    // Legacy completion handler (backward compatible)
    func fetchMetrics(
        for type: WidgetType,
        configuration: WidgetConfiguration,
        completion: @escaping ([Metric]) -> Void
    ) {
        Task {
            do {
                let metrics = try await fetchMetrics(for: type, configuration: configuration)
                completion(metrics)
            } catch {
                // Optionally log or handle error here
                completion([])
            }
        }
    }

    // MARK: - Audit/Admin Accessors

    static var lastSummary: String { MetricServiceAudit.accessibilitySummary }
    static var lastJSON: String? { MetricServiceAudit.exportLastJSON() }
    static func recentEvents(limit: Int = 5) -> [String] {
        MetricServiceAudit.recentEvents(limit: limit)
    }
}

// MARK: - Metric Data Source Protocol

protocol MetricDataSource {
    func fetchMetrics(for type: WidgetType, configuration: WidgetConfiguration) async throws -> [Metric]
}

// MARK: - Local (Sample) Data Source Implementation

struct MetricLocalStore: MetricDataSource {
    func fetchMetrics(for type: WidgetType, configuration: WidgetConfiguration) async throws -> [Metric] {
        // Example: Return hardcoded or simulated data for demo purposes
        // Replace this with real data access logic
        switch type {
        case .revenue:
            return [
                Metric(title: "Total Revenue", value: 14320.0, trend: 0.08, unit: "USD"),
                Metric(title: "Monthly Growth", value: 8.0, trend: 0.02, unit: "%")
            ]
        case .appointments:
            return [
                Metric(title: "Upcoming Appointments", value: 23, trend: 0.04, unit: nil),
                Metric(title: "No-shows", value: 1, trend: -0.01, unit: nil)
            ]
        case .customers:
            return [
                Metric(title: "Active Customers", value: 145, trend: 0.03, unit: nil),
                Metric(title: "Churn Rate", value: 2.5, trend: -0.01, unit: "%")
            ]
        case .retention:
            return [
                Metric(title: "Retention Rate", value: 96.5, trend: 0.01, unit: "%"),
                Metric(title: "Loyalty Members", value: 48, trend: 0.05, unit: nil)
            ]
        }
    }
}
