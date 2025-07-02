//
//  RevenueTrendChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Revenue Trend Chart
//

import SwiftUI
import Charts
import Combine

// MARK: - Audit/Event Logging

fileprivate struct RevenueTrendChartAuditEvent: Codable {
    let timestamp: Date
    let pointCount: Int
    let valueRange: String
    let dateRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] RevenueTrendChart: \(pointCount) points, \(valueRange), \(dateRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class RevenueTrendChartAudit {
    static private(set) var log: [RevenueTrendChartAuditEvent] = []

    /// Records a new audit event with the given parameters.
    static func record(
        pointCount: Int,
        valueRange: String,
        dateRange: String,
        tags: [String] = ["revenueTrendChart"]
    ) {
        let event = RevenueTrendChartAuditEvent(
            timestamp: Date(),
            pointCount: pointCount,
            valueRange: valueRange,
            dateRange: dateRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides a summary string for accessibility based on the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No revenue trend chart events recorded."
    }

    /// Returns the accessibility labels of recent audit events up to the specified limit.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - New Analytics Enhancements

    /// Computes the average point count from all logged audit events.
    static var averagePointCount: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.pointCount }
        return Double(total) / Double(log.count)
    }

    /// Finds the most frequent valueRange string in the audit log.
    static var mostFrequentValueRange: String {
        guard !log.isEmpty else { return "n/a" }
        let frequency = Dictionary(grouping: log, by: { $0.valueRange })
            .mapValues { $0.count }
        if let (valueRange, _) = frequency.max(by: { $0.value < $1.value }) {
            return valueRange
        }
        return "n/a"
    }

    // MARK: - New CSV Export Enhancement

    /// Exports all audit events as a CSV string with headers: timestamp,pointCount,valueRange,dateRange,tags.
    static func exportCSV() -> String {
        let header = "timestamp,pointCount,valueRange,dateRange,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let pointCountStr = String(event.pointCount)
            let valueRangeStr = "\"\(event.valueRange)\""
            let dateRangeStr = "\"\(event.dateRange)\""
            let tagsStr = "\"\(event.tags.joined(separator: ","))\""
            return [timestampStr, pointCountStr, valueRangeStr, dateRangeStr, tagsStr].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - Model

struct RevenuePoint: Identifiable {
    var id = UUID()
    var date: Date
    var revenue: Double
}

// MARK: - RevenueTrendChart

struct RevenueTrendChart: View {
    let data: [RevenuePoint]

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter
    }

    // For audit/accessibility
    private var valueRange: String {
        guard let min = data.map(\.revenue).min(),
              let max = data.map(\.revenue).max() else { return "n/a" }
        let minStr = currencyFormatter.string(from: NSNumber(value: min)) ?? "$0"
        let maxStr = currencyFormatter.string(from: NSNumber(value: max)) ?? "$0"
        return "min \(minStr), max \(maxStr)"
    }

    private var dateRange: String {
        guard let first = data.first?.date, let last = data.last?.date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    // Publisher to trigger VoiceOver announcements
    @State private var voiceOverAnnouncement: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Revenue Trend")
                .font(.headline)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("RevenueTrendChart-Header")

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Revenue", point.revenue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
                .symbolSize(40)
                .annotation(position: .top) {
                    Text(currencyFormatter.string(from: NSNumber(value: point.revenue)) ?? "$0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("RevenueTrendChart-PointLabel-\(point.id)")
                }
                .accessibilityLabel("\(currencyFormatter.string(from: NSNumber(value: point.revenue)) ?? "$0") in \(point.date.formatted(.dateTime.year().month()))")
                .accessibilityIdentifier("RevenueTrendChart-Point-\(point.id)")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
            .frame(height: 220)
            .accessibilityIdentifier("RevenueTrendChart-MainChart")

#if DEBUG
            // DEV overlay showing last 3 audit events, averagePointCount, and mostFrequentValueRange
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("DEV Audit Overlay")
                    .font(.caption).bold()
                    .foregroundColor(.accentColor)
                ForEach(RevenueTrendChartAudit.recentEvents(limit: 3), id: \.self) { eventLabel in
                    Text(eventLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text("Average Point Count: \(String(format: "%.2f", RevenueTrendChartAudit.averagePointCount))")
                    .font(.caption2)
                Text("Most Frequent Value Range: \(RevenueTrendChartAudit.mostFrequentValueRange)")
                    .font(.caption2)
            }
            .padding(8)
            .background(Color(.systemGray6).opacity(0.9))
            .cornerRadius(8)
            .padding(.top, 8)
#endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Revenue trend chart from \(dateRange), values \(valueRange)")
        .accessibilityIdentifier("RevenueTrendChart-Container")
        // Accessibility: Post VoiceOver announcement if minimum revenue is zero
        .onAppear {
            RevenueTrendChartAudit.record(
                pointCount: data.count,
                valueRange: valueRange,
                dateRange: dateRange
            )
            if let minRevenue = data.map(\.revenue).min(), minRevenue == 0 {
                // Post a VoiceOver announcement warning about zero revenue month(s)
                let announcement = "Warning: At least one month had zero revenue."
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum RevenueTrendChartAuditAdmin {
    public static var lastSummary: String { RevenueTrendChartAudit.accessibilitySummary }
    public static var lastJSON: String? { RevenueTrendChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        RevenueTrendChartAudit.recentEvents(limit: limit)
    }

    // Expose new analytics properties for external use
    public static var averagePointCount: Double {
        RevenueTrendChartAudit.averagePointCount
    }

    public static var mostFrequentValueRange: String {
        RevenueTrendChartAudit.mostFrequentValueRange
    }

    // Expose CSV export for audit events
    public static func exportCSV() -> String {
        RevenueTrendChartAudit.exportCSV()
    }
}

#if DEBUG
struct RevenueTrendChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sampleData: [RevenuePoint] = (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: today)!
            return RevenuePoint(date: date, revenue: Double.random(in: 5000...15000))
        }.reversed()

        RevenueTrendChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
