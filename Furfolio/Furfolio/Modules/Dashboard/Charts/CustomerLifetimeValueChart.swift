//
//  CustomerLifetimeValueChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Customer Lifetime Value Chart
//

import SwiftUI
import Charts

// MARK: - Audit/Event Logging

fileprivate struct CustomerLifetimeValueChartAuditEvent: Codable {
    let timestamp: Date
    let pointCount: Int
    let valueRange: String
    let dateRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Customer Lifetime Value Chart: \(pointCount) points, \(valueRange), \(dateRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class CustomerLifetimeValueChartAudit {
    static private(set) var log: [CustomerLifetimeValueChartAuditEvent] = []

    static func record(
        pointCount: Int,
        valueRange: String,
        dateRange: String,
        tags: [String] = ["customerLifetimeValueChart"]
    ) {
        let event = CustomerLifetimeValueChartAuditEvent(
            timestamp: Date(),
            pointCount: pointCount,
            valueRange: valueRange,
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
        log.last?.accessibilityLabel ?? "No CLV chart events recorded."
    }

    // MARK: - Enhancement: CSV export of audit events
    /// Exports the last audit event as a CSV string with columns: timestamp,pointCount,valueRange,dateRange,tags
    static func exportCSV() -> String? {
        guard let last = log.last else { return nil }
        // Escape commas in valueRange and dateRange if needed by quoting
        let escapedValueRange = "\"\(last.valueRange.replacingOccurrences(of: "\"", with: "\"\""))\""
        let escapedDateRange = "\"\(last.dateRange.replacingOccurrences(of: "\"", with: "\"\""))\""
        let escapedTags = "\"\(last.tags.joined(separator: ",").replacingOccurrences(of: "\"", with: "\"\""))\""
        let timestampStr = ISO8601DateFormatter().string(from: last.timestamp)
        return "\(timestampStr),\(last.pointCount),\(escapedValueRange),\(escapedDateRange),\(escapedTags)"
    }

    // MARK: - Enhancement: Analytics computed properties

    /// Calculates the average lifetime value from all events' valueRange minimum and maximum values, averaged.
    /// Returns nil if no events or unable to parse.
    static var averageLifetimeValue: Double? {
        // Parse min and max from each event's valueRange string "min $X, max $Y"
        let values = log.compactMap { event -> (Double, Double)? in
            // Extract min and max strings
            // Expected format: "min $X, max $Y"
            let pattern = #"min \$([\d,]+), max \$([\d,]+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: event.valueRange, options: [], range: NSRange(location: 0, length: event.valueRange.utf16.count)),
                  match.numberOfRanges == 3,
                  let minRange = Range(match.range(at: 1), in: event.valueRange),
                  let maxRange = Range(match.range(at: 2), in: event.valueRange)
            else { return nil }

            let minStr = event.valueRange[minRange].replacingOccurrences(of: ",", with: "")
            let maxStr = event.valueRange[maxRange].replacingOccurrences(of: ",", with: "")
            if let minVal = Double(minStr), let maxVal = Double(maxStr) {
                return (minVal, maxVal)
            }
            return nil
        }
        guard !values.isEmpty else { return nil }
        let averages = values.map { ($0.0 + $0.1) / 2.0 }
        let sum = averages.reduce(0, +)
        return sum / Double(averages.count)
    }

    /// Returns the most frequent pointCount value across all audit log events.
    /// Returns nil if no events.
    static var mostFrequentPointCount: Int? {
        guard !log.isEmpty else { return nil }
        let counts = Dictionary(grouping: log, by: { $0.pointCount })
            .mapValues { $0.count }
        if let (pointCount, _) = counts.max(by: { $0.value < $1.value }) {
            return pointCount
        }
        return nil
    }
}

// MARK: - Model

struct CustomerLifetimeValuePoint: Identifiable {
    var id = UUID()
    var date: Date
    var lifetimeValue: Double
}

// MARK: - CustomerLifetimeValueChart

struct CustomerLifetimeValueChart: View {
    let data: [CustomerLifetimeValuePoint]

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter
    }

    // For audit/accessibility
    private var valueRange: String {
        guard let min = data.map(\.lifetimeValue).min(),
              let max = data.map(\.lifetimeValue).max() else { return "n/a" }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer Lifetime Value Over Time")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("CustomerLifetimeValueChart-Header")

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Lifetime Value", point.lifetimeValue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
                .symbolSize(40)
                .annotation(position: .top) {
                    Text(currencyFormatter.string(from: NSNumber(value: point.lifetimeValue)) ?? "$0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("CustomerLifetimeValueChart-PointLabel-\(point.id)")
                }
                .accessibilityLabel("\(currencyFormatter.string(from: NSNumber(value: point.lifetimeValue)) ?? "$0") on \(point.date.formatted(.dateTime.year().month()))")
                .accessibilityIdentifier("CustomerLifetimeValueChart-Point-\(point.id)")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
            .frame(height: 220)
            .accessibilityIdentifier("CustomerLifetimeValueChart-MainChart")

            // MARK: - Enhancement: DEV overlay in DEBUG builds showing audit info
            #if DEBUG
            AuditInfoOverlay()
                .padding(.top, 12)
            #endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Customer lifetime value line chart showing values from \(dateRange), \(valueRange)")
        .accessibilityIdentifier("CustomerLifetimeValueChart-Container")
        .onAppear {
            CustomerLifetimeValueChartAudit.record(
                pointCount: data.count,
                valueRange: valueRange,
                dateRange: dateRange
            )
            // MARK: - Enhancement: Accessibility announcement if any lifetimeValue == 0
            if data.contains(where: { $0.lifetimeValue == 0 }) {
                UIAccessibility.post(notification: .announcement, argument: "A customer has zero lifetime value.")
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum CustomerLifetimeValueChartAuditAdmin {
    public static var lastSummary: String { CustomerLifetimeValueChartAudit.accessibilitySummary }
    public static var lastJSON: String? { CustomerLifetimeValueChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        CustomerLifetimeValueChartAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - Enhancement: Expose CSV export
    public static var exportCSV: String? { CustomerLifetimeValueChartAudit.exportCSV() }

    // MARK: - Enhancement: Expose analytics
    public static var averageLifetimeValue: Double? { CustomerLifetimeValueChartAudit.averageLifetimeValue }
    public static var mostFrequentPointCount: Int? { CustomerLifetimeValueChartAudit.mostFrequentPointCount }
}

#if DEBUG
// MARK: - Enhancement: DEV overlay view showing audit info
private struct AuditInfoOverlay: View {
    private let recentEvents: [String] = CustomerLifetimeValueChartAudit.log.suffix(3).map { $0.accessibilityLabel }
    private let averageLifetimeValue: Double? = CustomerLifetimeValueChartAudit.averageLifetimeValue
    private let mostFrequentPointCount: Int? = CustomerLifetimeValueChartAudit.mostFrequentPointCount

    private var formattedAverageLifetimeValue: String {
        guard let avg = averageLifetimeValue else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: avg)) ?? "$0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Info (Last 3 Events):")
                .font(.caption)
                .bold()
            ForEach(recentEvents, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            Divider()
            HStack {
                Text("Avg Lifetime Value:")
                    .font(.caption2)
                    .bold()
                Spacer()
                Text(formattedAverageLifetimeValue)
                    .font(.caption2)
            }
            HStack {
                Text("Most Frequent Point Count:")
                    .font(.caption2)
                    .bold()
                Spacer()
                Text(mostFrequentPointCount.map(String.init) ?? "N/A")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground).opacity(0.9))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Debug audit information overlay")
    }
}

struct CustomerLifetimeValueChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sampleData = (0..<12).map { offset in
            CustomerLifetimeValuePoint(
                date: calendar.date(byAdding: .month, value: -offset, to: today)!,
                lifetimeValue: Double.random(in: 200...1000)
            )
        }.reversed()

        return CustomerLifetimeValueChart(data: Array(sampleData))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
