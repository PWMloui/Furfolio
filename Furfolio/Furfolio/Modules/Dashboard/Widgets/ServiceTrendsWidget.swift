//
//  ServiceTrendsWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Service Trends Widget
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct ServiceTrendsAuditEvent: Codable {
    let timestamp: Date
    let serviceCount: Int
    let topService: String?
    let valueRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] ServiceTrendsWidget: \(serviceCount) services, top: \(topService ?? "n/a"), \(valueRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ServiceTrendsAudit {
    static private(set) var log: [ServiceTrendsAuditEvent] = []

    /// Records a new audit event with given parameters.
    /// - Parameters:
    ///   - serviceCount: Number of services displayed.
    ///   - topService: Name of the top service.
    ///   - valueRange: Range of values shown.
    ///   - tags: Tags associated with the event.
    static func record(
        serviceCount: Int,
        topService: String?,
        valueRange: String,
        tags: [String] = ["serviceTrendsWidget"]
    ) {
        let event = ServiceTrendsAuditEvent(
            timestamp: Date(),
            serviceCount: serviceCount,
            topService: topService,
            valueRange: valueRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as pretty-printed JSON string.
    /// - Returns: JSON string of the last event or nil if none.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides an accessibility summary string of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No service trends events recorded."
    }

    /// Returns the accessibility labels of recent audit events up to specified limit.
    /// - Parameter limit: Number of recent events to return.
    /// - Returns: Array of accessibility labels.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - Analytics Enhancements

    /// Computes the average service count from all logged events.
    static var averageServiceCount: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.serviceCount }
        return Double(total) / Double(log.count)
    }

    /// Determines the most frequently occurring top service in the logs.
    static var mostFrequentTopService: String? {
        let services = log.compactMap { $0.topService }
        guard !services.isEmpty else { return nil }
        let frequency = Dictionary(grouping: services, by: { $0 })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of audit events recorded.
    static var totalWidgetDisplays: Int {
        log.count
    }

    // MARK: - CSV Export Enhancement

    /// Exports all audit events as CSV string with headers:
    /// timestamp,serviceCount,topService,valueRange,tags
    /// - Returns: CSV formatted string of all audit events.
    static func exportCSV() -> String {
        let header = "timestamp,serviceCount,topService,valueRange,tags"
        let rows = log.map { event -> String in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            let topServiceEscaped = (event.topService ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let valueRangeEscaped = event.valueRange.replacingOccurrences(of: "\"", with: "\"\"")
            let tagsEscaped = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap fields that may contain commas in quotes
            return "\"\(dateStr)\",\(event.serviceCount),\"\(topServiceEscaped)\",\"\(valueRangeEscaped)\",\"\(tagsEscaped)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - Model

public struct ServiceTrend: Identifiable {
    public let id = UUID()
    public let name: String
    public let count: Int
    public let trend: Double  // percent change (e.g., +8.0 for +8%)

    public init(name: String, count: Int, trend: Double) {
        self.name = name
        self.count = count
        self.trend = trend
    }
}

// MARK: - ServiceTrendsWidget

public struct ServiceTrendsWidget: View {
    public let trends: [ServiceTrend]

    private var valueRange: String {
        guard let min = trends.map(\.count).min(),
              let max = trends.map(\.count).max() else { return "n/a" }
        return "min \(min), max \(max)"
    }
    private var topService: String? {
        trends.max(by: { $0.count < $1.count })?.name
    }

    // Accessibility notification publisher for VoiceOver announcements
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var voiceOverAnnouncement: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Service Trends")
                    .font(.headline)
                    .accessibilityIdentifier("ServiceTrendsWidget-Title")
            }
            .padding(.bottom, 2)

            if trends.isEmpty {
                Text("No service trends available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("ServiceTrendsWidget-Empty")
            } else {
                ForEach(trends) { trend in
                    HStack {
                        Text(trend.name)
                            .font(.subheadline)
                            .accessibilityIdentifier("ServiceTrendsWidget-ServiceName-\(trend.name)")
                        Spacer()
                        Text("\(trend.count)")
                            .font(.subheadline.weight(.bold))
                            .accessibilityIdentifier("ServiceTrendsWidget-ServiceCount-\(trend.name)")
                        TrendIndicator(value: trend.trend)
                            .accessibilityIdentifier("ServiceTrendsWidget-TrendIndicator-\(trend.name)")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("ServiceTrendsWidget-Container")
        // Post VoiceOver announcement if serviceCount > 10 for accessibility enhancement
        .accessibilityAnnouncement(voiceOverAnnouncement ?? "")
        .onAppear {
            ServiceTrendsAudit.record(
                serviceCount: trends.count,
                topService: topService,
                valueRange: valueRange
            )
            if trends.count > 10 && voiceOverEnabled {
                voiceOverAnnouncement = "High service variety: More than ten service types trending."
            }
        }
        // DEV overlay showing audit summary and recent events in DEBUG builds
        #if DEBUG
        .overlay(
            AuditDevOverlay()
                .padding(.top, 8),
            alignment: .bottom
        )
        #endif
    }

    private var accessibilitySummary: String {
        if trends.isEmpty {
            return "No service trends available"
        } else {
            let top = topService ?? "none"
            return "Service trends. \(trends.count) services. Top: \(top). Value range: \(valueRange)"
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ServiceTrendsWidgetAuditAdmin {
    /// Last audit event's accessibility summary.
    public static var lastSummary: String { ServiceTrendsAudit.accessibilitySummary }
    /// Last audit event JSON export.
    public static var lastJSON: String? { ServiceTrendsAudit.exportLastJSON() }
    /// Recent audit event accessibility labels.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ServiceTrendsAudit.recentEvents(limit: limit)
    }

    // Expose analytics computed properties
    /// Average service count across all audit events.
    public static var averageServiceCount: Double { ServiceTrendsAudit.averageServiceCount }
    /// Most frequent top service in audit logs.
    public static var mostFrequentTopService: String? { ServiceTrendsAudit.mostFrequentTopService }
    /// Total number of widget display audit events.
    public static var totalWidgetDisplays: Int { ServiceTrendsAudit.totalWidgetDisplays }

    // Expose CSV export
    /// CSV export of all audit events.
    public static func exportCSV() -> String {
        ServiceTrendsAudit.exportCSV()
    }
}

// MARK: - DEV Overlay for Debug Builds

#if DEBUG
/// SwiftUI overlay view showing audit analytics and recent events for development and debugging.
private struct AuditDevOverlay: View {
    @State private var recentEvents: [String] = []
    @State private var averageCount: Double = 0
    @State private var frequentTopService: String = "N/A"
    @State private var totalDisplays: Int = 0

    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Audit Summary (DEV)")
                .font(.caption).bold()
                .foregroundColor(.white)
            Text("Avg Service Count: \(String(format: "%.2f", averageCount))")
                .font(.caption2).foregroundColor(.white)
            Text("Most Frequent Top Service: \(frequentTopService)")
                .font(.caption2).foregroundColor(.white)
            Text("Total Widget Displays: \(totalDisplays)")
                .font(.caption2).foregroundColor(.white)
            Divider().background(Color.white)
            Text("Recent Events:")
                .font(.caption2).bold().foregroundColor(.white)
            ForEach(recentEvents, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
        .onReceive(timer) { _ in
            updateData()
        }
        .onAppear {
            updateData()
        }
    }

    /// Updates the displayed audit data from the audit log.
    private func updateData() {
        recentEvents = ServiceTrendsAudit.recentEvents(limit: 3)
        averageCount = ServiceTrendsAudit.averageServiceCount
        frequentTopService = ServiceTrendsAudit.mostFrequentTopService ?? "N/A"
        totalDisplays = ServiceTrendsAudit.totalWidgetDisplays
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct ServiceTrendsWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = [
            ServiceTrend(name: "Full Groom", count: 35, trend: 4.5),
            ServiceTrend(name: "Bath", count: 21, trend: -1.2),
            ServiceTrend(name: "Nail Trim", count: 18, trend: 2.1),
            ServiceTrend(name: "Other", count: 7, trend: 0.0)
        ]
        ServiceTrendsWidget(trends: sample)
            .frame(width: 320)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
