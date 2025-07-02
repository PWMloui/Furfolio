//
//  KPIWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular KPI Widget
//

import SwiftUI
import Combine
import AVFoundation

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
    
    /// Records an audit event with the given widget title and metric.
    /// - Parameters:
    ///   - widgetTitle: The title of the widget.
    ///   - metric: The metric data to record.
    ///   - tags: Optional tags for categorization.
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
    
    /// Exports the last audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Accessibility summary label for the most recent audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No KPI widget events recorded."
    }
    
    /// Returns recent audit event accessibility labels up to the given limit.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    // MARK: - New Analytics Properties
    
    /// The metricTitle that appears most frequently in the audit log.
    static var mostFrequentMetricTitle: String? {
        guard !log.isEmpty else { return nil }
        let frequency = Dictionary(grouping: log, by: { $0.metricTitle })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }
    
    /// The average value of all recorded metric values.
    static var averageValue: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0.0) { $0 + $1.value }
        return total / Double(log.count)
    }
    
    /// Total number of audit events recorded.
    static var totalWidgetDisplays: Int {
        log.count
    }
    
    // MARK: - CSV Export
    
    /// Exports all audit events as CSV string with header.
    /// Columns: timestamp,widgetTitle,metricTitle,value,unit,trend,tags
    static func exportCSV() -> String {
        let header = "timestamp,widgetTitle,metricTitle,value,unit,trend,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let unitStr = event.unit ?? ""
            let trendStr = event.trend != nil ? String(format: "%.2f", event.trend!) : ""
            let tagsStr = event.tags.joined(separator: ";")
            return "\"\(timestampStr)\",\"\(event.widgetTitle)\",\"\(event.metricTitle)\",\(event.value),\"\(unitStr)\",\(trendStr),\"\(tagsStr)\""
        }
        return ([header] + rows).joined(separator: "\n")
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
    
    @State private var voiceOverCancellable: AnyCancellable? = nil

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
#if DEBUG
            // DEV overlay showing recent audit info and analytics
            if !KPIWidgetAudit.log.isEmpty {
                Divider()
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEV Overlay")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    Text("Recent Events:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(KPIWidgetAudit.recentEvents(limit: 3), id: \.self) { event in
                        Text(event)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let frequent = KPIWidgetAudit.mostFrequentMetricTitle {
                        Text("Most Frequent Metric: \(frequent)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "Average Value: %.2f", KPIWidgetAudit.averageValue))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Total Widget Displays: \(KPIWidgetAudit.totalWidgetDisplays)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(6)
            }
#endif
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
                    // Accessibility announcement if value zero or trend negative
                    if metric.value == 0.0 || (metric.trend ?? 0.0) < 0.0 {
                        postAccessibilityWarning()
                    }
                } else {
                    self.fetchError = "No KPI data"
                }
            }
        }
    }
    
    /// Posts a VoiceOver announcement warning if KPI value is zero or trend is negative.
    private func postAccessibilityWarning() {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: "Warning: KPI metric is zero or trending negative.")
        #endif
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
    
    // Expose new analytics properties
    public static var mostFrequentMetricTitle: String? { KPIWidgetAudit.mostFrequentMetricTitle }
    public static var averageValue: Double { KPIWidgetAudit.averageValue }
    public static var totalWidgetDisplays: Int { KPIWidgetAudit.totalWidgetDisplays }
    
    // Expose CSV export
    public static func exportCSV() -> String {
        KPIWidgetAudit.exportCSV()
    }
}
