//
//  BehaviorTrendChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Behavior Trend Chart
//

import SwiftUI
import Charts
import AVFoundation

// MARK: - Audit/Event Logging

fileprivate struct BehaviorTrendChartAuditEvent: Codable {
    let timestamp: Date
    let lineCount: Int
    let behaviors: [String]
    let dateRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] BehaviorTrendChart: \(lineCount) behaviors, \(dateRange), behaviors: [\(behaviors.joined(separator: ", "))] [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class BehaviorTrendChartAudit {
    static private(set) var log: [BehaviorTrendChartAuditEvent] = []

    static func record(
        lineCount: Int,
        behaviors: [String],
        dateRange: String,
        tags: [String] = ["behaviorTrendChart"]
    ) {
        let event = BehaviorTrendChartAuditEvent(
            timestamp: Date(),
            lineCount: lineCount,
            behaviors: behaviors,
            dateRange: dateRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }

        // Accessibility Enhancement:
        // If any behavior trend chart has more than 3 lines, post a VoiceOver announcement.
        if lineCount > 3 {
            let announcement = "Multiple behavior trends detected."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No behavior trend chart events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - Analytics Enhancements

    /// Computes the average line count across all audit events.
    static var averageLineCount: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.lineCount }
        return Double(total) / Double(log.count)
    }

    /// Finds the most frequent behavior across all audit events.
    static var mostFrequentBehavior: String {
        var behaviorCounts: [String: Int] = [:]
        for event in log {
            for behavior in event.behaviors {
                behaviorCounts[behavior, default: 0] += 1
            }
        }
        return behaviorCounts.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }

    // MARK: - CSV Export Enhancement

    /// Exports the last audit event as a CSV string with columns: timestamp,lineCount,behaviors,dateRange,tags.
    static func exportCSV() -> String? {
        guard let last = log.last else { return nil }
        // CSV header
        let header = "timestamp,lineCount,behaviors,dateRange,tags"
        // Escape behaviors and tags by wrapping in quotes and escaping internal quotes if any
        func escapeCSVField(_ field: String) -> String {
            var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        let timestampStr = ISO8601DateFormatter().string(from: last.timestamp)
        let lineCountStr = "\(last.lineCount)"
        let behaviorsStr = escapeCSVField(last.behaviors.joined(separator: ", "))
        let dateRangeStr = escapeCSVField(last.dateRange)
        let tagsStr = escapeCSVField(last.tags.joined(separator: ", "))
        let row = [timestampStr, lineCountStr, behaviorsStr, dateRangeStr, tagsStr].joined(separator: ",")
        return "\(header)\n\(row)"
    }
}

// MARK: - Data Model

struct BehaviorTrendPoint: Identifiable {
    var id = UUID()
    var behavior: String
    var date: Date
    var rating: Int
}

// MARK: - BehaviorTrendChart

struct BehaviorTrendChart: View {
    let data: [BehaviorTrendPoint]

    private var behaviors: [String] {
        Array(Set(data.map { $0.behavior })).sorted()
    }

    private let colors: [Color] = [
        .green, .orange, .red, .blue, .purple, .pink
    ]

    private var dateRange: String {
        guard let minDate = data.map({ $0.date }).min(),
              let maxDate = data.map({ $0.date }).max() else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Pet Behavior Trends")
                .font(.headline)
                .padding(.bottom, 8)
                .accessibilityIdentifier("BehaviorTrendChart-Header")

            Chart {
                ForEach(behaviors.indices, id: \.self) { index in
                    let behavior = behaviors[index]
                    let filteredData = data.filter { $0.behavior == behavior }

                    ForEach(filteredData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.rating)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(point.rating)")
                                .font(.caption2)
                                .foregroundColor(colors[index % colors.count])
                                .accessibilityIdentifier("BehaviorTrendChart-Annotation-\(behavior)-\(point.id)")
                        }
                        .accessibilityLabel("\(behavior), \(point.rating), \(point.date.formatted(.dateTime.month().year()))")
                        .accessibilityIdentifier("BehaviorTrendChart-Line-\(behavior)-\(point.id)")
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 240)
            .accessibilityIdentifier("BehaviorTrendChart-MainChart")

            // Legend
            HStack(spacing: 12) {
                ForEach(behaviors.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 14, height: 14)
                            .accessibilityIdentifier("BehaviorTrendChart-LegendColor-\(behaviors[index])")
                        Text(behaviors[index])
                            .font(.footnote)
                            .accessibilityIdentifier("BehaviorTrendChart-LegendLabel-\(behaviors[index])")
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityIdentifier("BehaviorTrendChart-Legend")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet behavior trend chart for \(behaviors.joined(separator: ", ")), date range \(dateRange)")
        .accessibilityIdentifier("BehaviorTrendChart-Container")
        .onAppear {
            BehaviorTrendChartAudit.record(
                lineCount: behaviors.count,
                behaviors: behaviors,
                dateRange: dateRange
            )
        }
        // DEV Overlay: Show last 3 audit events and analytics in DEBUG builds
        #if DEBUG
        .overlay(alignment: .bottom) {
            BehaviorTrendChartAuditDevOverlay()
                .padding()
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(12)
                .shadow(radius: 4)
                .padding()
        }
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum BehaviorTrendChartAuditAdmin {
    public static var lastSummary: String { BehaviorTrendChartAudit.accessibilitySummary }
    public static var lastJSON: String? { BehaviorTrendChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        BehaviorTrendChartAudit.recentEvents(limit: limit)
    }

    // Expose analytics properties
    public static var averageLineCount: Double { BehaviorTrendChartAudit.averageLineCount }
    public static var mostFrequentBehavior: String { BehaviorTrendChartAudit.mostFrequentBehavior }

    // Expose CSV export
    public static func exportCSV() -> String? {
        BehaviorTrendChartAudit.exportCSV()
    }
}

// MARK: - DEV Overlay View for Debugging

#if DEBUG
struct BehaviorTrendChartAuditDevOverlay: View {
    private let recentEvents: [String] = BehaviorTrendChartAudit.recentEvents(limit: 3)
    private let avgLineCount: Double = BehaviorTrendChartAudit.averageLineCount
    private let mostFreqBehavior: String = BehaviorTrendChartAudit.mostFrequentBehavior

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Events (Last 3):")
                .font(.headline)
            ForEach(recentEvents.indices, id: \.self) { idx in
                Text("• \(recentEvents[idx])")
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            Divider()
            Text(String(format: "Average Line Count: %.2f", avgLineCount))
                .font(.footnote)
            Text("Most Frequent Behavior: \(mostFreqBehavior)")
                .font(.footnote)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityIdentifier("BehaviorTrendChart-AuditDevOverlay")
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct BehaviorTrendChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let behaviors = ["Calm", "Anxious", "Aggressive"]

        var sampleData: [BehaviorTrendPoint] = []

        for behavior in behaviors {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let rating = Int.random(in: 1...5)
                    sampleData.append(BehaviorTrendPoint(behavior: behavior, date: date, rating: rating))
                }
            }
        }

        BehaviorTrendChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
