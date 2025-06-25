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
}

#if DEBUG
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
