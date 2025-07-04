//
//  LineChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Line Chart
//

import SwiftUI
import Charts

// MARK: - Audit/Event Logging

fileprivate struct LineChartAuditEvent: Codable {
    let timestamp: Date
    let pointCount: Int
    let valueRange: String
    let dateRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] LineChart: \(pointCount) points, \(valueRange), \(dateRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class LineChartAudit {
    static private(set) var log: [LineChartAuditEvent] = []

    /// Records a new audit event and posts a VoiceOver announcement if high data volume is detected.
    static func record(
        pointCount: Int,
        valueRange: String,
        dateRange: String,
        tags: [String] = ["lineChart"]
    ) {
        let event = LineChartAuditEvent(
            timestamp: Date(),
            pointCount: pointCount,
            valueRange: valueRange,
            dateRange: dateRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
        
        // Accessibility enhancement: Announce high data volume if any event has pointCount > 20
        if pointCount > 20 {
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: "Chart shows high data volume: over 20 points.")
            }
        }
    }

    /// Exports the last audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No line chart events recorded."
    }
    /// Returns recent audit event accessibility labels, limited by the specified count.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    // MARK: - New Analytics Properties
    
    /// Computes the average point count across all logged events.
    static var averagePointCount: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.pointCount }
        return Double(total) / Double(log.count)
    }
    
    /// Finds the most frequent valueRange string in the audit log.
    static var mostFrequentValueRange: String {
        guard !log.isEmpty else { return "n/a" }
        let freq = Dictionary(grouping: log, by: { $0.valueRange }).mapValues { $0.count }
        let maxEntry = freq.max { $0.value < $1.value }
        return maxEntry?.key ?? "n/a"
    }
    
    // MARK: - CSV Export
    
    /// Exports all audit events as CSV string with headers: timestamp,pointCount,valueRange,dateRange,tags.
    static func exportCSV() -> String {
        let header = "timestamp,pointCount,valueRange,dateRange,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|") // Use | as separator to avoid CSV conflicts
            // Escape commas in valueRange and dateRange by wrapping in quotes if needed
            func csvEscape(_ str: String) -> String {
                if str.contains(",") || str.contains("\"") {
                    let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return str
            }
            return "\(timestampStr),\(event.pointCount),\(csvEscape(event.valueRange)),\(csvEscape(event.dateRange)),\(tagsStr)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - Model

public struct LineChartPoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

// MARK: - LineChart

public struct LineChart: View {
    public let data: [LineChartPoint]
    public let valueLabel: String

    private var valueRange: String {
        guard let min = data.map(\.value).min(),
              let max = data.map(\.value).max() else { return "n/a" }
        return String(format: "min %.2f, max %.2f", min, max)
    }

    private var dateRange: String {
        guard let first = data.first?.date, let last = data.last?.date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("Line Chart")
                .font(.headline)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("LineChart-Header")

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(valueLabel, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
                .symbolSize(30)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", point.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("LineChart-PointLabel-\(point.id)")
                }
                .accessibilityLabel("\(valueLabel): \(String(format: "%.1f", point.value)) on \(point.date.formatted(.dateTime.year().month().day()))")
                .accessibilityIdentifier("LineChart-Point-\(point.id)")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: data.count / 8 > 0 ? data.count / 8 : 1)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 220)
            .accessibilityIdentifier("LineChart-MainChart")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Line chart showing \(valueLabel) from \(dateRange), values \(valueRange)")
        .accessibilityIdentifier("LineChart-Container")
        .onAppear {
            LineChartAudit.record(
                pointCount: data.count,
                valueRange: valueRange,
                dateRange: dateRange
            )
        }
        #if DEBUG
        // DEV overlay showing audit info for debugging and analytics
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit Events (last 3):")
                    .font(.caption).bold()
                ForEach(LineChartAudit.recentEvents(limit: 3), id: \.self) { eventLabel in
                    Text(eventLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(String(format: "Average Point Count: %.2f", LineChartAudit.averagePointCount))
                    .font(.caption2)
                Text("Most Frequent Value Range: \(LineChartAudit.mostFrequentValueRange)")
                    .font(.caption2)
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.85))
            .cornerRadius(8)
            .padding(),
            alignment: .bottomLeading
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum LineChartAuditAdmin {
    public static var lastSummary: String { LineChartAudit.accessibilitySummary }
    public static var lastJSON: String? { LineChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        LineChartAudit.recentEvents(limit: limit)
    }
    
    // Expose new analytics properties
    public static var averagePointCount: Double { LineChartAudit.averagePointCount }
    public static var mostFrequentValueRange: String { LineChartAudit.mostFrequentValueRange }
    
    // Expose CSV export
    public static func exportCSV() -> String {
        LineChartAudit.exportCSV()
    }
}

#if DEBUG
struct LineChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sampleData = (0..<15).map { offset in
            LineChartPoint(date: calendar.date(byAdding: .day, value: -offset, to: today)!, value: Double.random(in: 30...80))
        }.reversed()
        LineChart(data: Array(sampleData), valueLabel: "Revenue")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
