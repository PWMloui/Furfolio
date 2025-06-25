//
//  KPIWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular KPI Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct KPIWidgetAuditEvent: Codable {
    let timestamp: Date
    let widgetTitle: String
    let metricTitle: String
    let value: Double
    let unit: String?
    let trend: Double?
    let tags: [String]
    var accessibilityLabel: String {
        let valueStr = String(format: "%.2f", value)
        let trendStr = trend != nil ? String(format: "%.2f", trend!) : "n/a"
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Display] \(widgetTitle): \(metricTitle) = \(valueStr) \(unit ?? ""), trend: \(trendStr) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class KPIWidgetAudit {
    static private(set) var log: [KPIWidgetAuditEvent] = []

    static func record(
        widgetTitle: String,
        metric: Metric?,
        tags: [String] = ["kpiWidget"]
    ) {
        guard let metric = metric else { return }
        let event = KPIWidgetAuditEvent(
            timestamp: Date(),
            widgetTitle: widgetTitle,
            metricTitle: metric.title,
            value: metric.value,
            unit: metric.unit,
            trend: metric.trend,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No KPI widget events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - KPIWidget

struct KPIWidget: WidgetViewProtocol {
    let widgetTitle: String = "Key Performance Indicator"
    let icon = Image(systemName: "chart.bar")
    var configuration: WidgetConfiguration

    @State private var metric: Metric? = nil
    @State private var isLoading = false
    @State private var fetchError: String? = nil

    var body: some View {
        VStack {
            HStack {
                icon
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(widgetTitle)
                    .font(.headline)
                    .accessibilityIdentifier("KPIWidget-Title")
            }
            .padding(.bottom, 6)

            if isLoading {
                ProgressView()
                    .accessibilityLabel("Loading KPI metric")
                    .accessibilityIdentifier("KPIWidget-Loading")
            } else if let error = fetchError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("KPIWidget-Error")
            } else if let metric = metric {
                Text(metric.title)
                    .font(.title3)
                    .accessibilityIdentifier("KPIWidget-MetricTitle")
                Text("\(metric.value, specifier: "%.0f") \(metric.unit ?? "")")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityIdentifier("KPIWidget-MetricValue")
                if let trend = metric.trend {
                    TrendIndicator(value: trend)
                        .accessibilityIdentifier("KPIWidget-TrendIndicator")
                }
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .accessibilityIdentifier("KPIWidget-NoData")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("KPIWidget-Container")
        .onAppear(perform: fetchMetric)
    }

    private func fetchMetric() {
        isLoading = true
        fetchError = nil
        MetricService.shared.fetchMetrics(for: .kpi, configuration: configuration) { metrics in
            DispatchQueue.main.async {
                self.isLoading = false
                if let metric = metrics.first {
                    self.metric = metric
                    KPIWidgetAudit.record(widgetTitle: widgetTitle, metric: metric)
                } else {
                    self.fetchError = "No KPI data"
                }
            }
        }
    }

    private var accessibilitySummary: String {
        if isLoading {
            return "Loading KPI metric"
        } else if let error = fetchError {
            return error
        } else if let metric = metric {
            let trendStr = metric.trend != nil ? "Trend \(metric.trend!.formatted(.number.precision(.fractionLength(2)))) percent." : "No trend available."
            return "\(widgetTitle). \(metric.title): \(metric.value) \(metric.unit ?? ""). \(trendStr)"
        } else {
            return "No KPI data available"
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum KPIWidgetAuditAdmin {
    public static var lastSummary: String { KPIWidgetAudit.accessibilitySummary }
    public static var lastJSON: String? { KPIWidgetAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        KPIWidgetAudit.recentEvents(limit: limit)
    }
}
