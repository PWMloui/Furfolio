//
//  BehaviorTrendChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Behavior Trend Chart
//

import SwiftUI
import Charts

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
    }
}

// MARK: - Audit/Admin Accessors

public enum BehaviorTrendChartAuditAdmin {
    public static var lastSummary: String { BehaviorTrendChartAudit.accessibilitySummary }
    public static var lastJSON: String? { BehaviorTrendChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        BehaviorTrendChartAudit.recentEvents(limit: limit)
    }
}

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
