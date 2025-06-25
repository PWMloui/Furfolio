//
//  AppointmentVolumeChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Appointment Volume Chart
//

import SwiftUI
import Charts

// MARK: - Audit/Event Logging

fileprivate struct AppointmentVolumeChartAuditEvent: Codable {
    let timestamp: Date
    let pointCount: Int
    let dateRange: String
    let minValue: Int
    let maxValue: Int
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Appointment Volume Chart: \(pointCount) points, \(dateRange), min \(minValue), max \(maxValue) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class AppointmentVolumeChartAudit {
    static private(set) var log: [AppointmentVolumeChartAuditEvent] = []

    static func record(
        pointCount: Int,
        dateRange: String,
        minValue: Int,
        maxValue: Int,
        tags: [String] = ["appointmentVolumeChart"]
    ) {
        let event = AppointmentVolumeChartAuditEvent(
            timestamp: Date(),
            pointCount: pointCount,
            dateRange: dateRange,
            minValue: minValue,
            maxValue: maxValue,
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
        log.last?.accessibilityLabel ?? "No appointment volume chart events recorded."
    }
}

// MARK: - AppointmentVolumeChart

struct AppointmentVolumeChart: View {
    let appointmentsByDate: [Date: Int]

    private var sortedData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let past14Days = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()
        return past14Days.map { date in
            (date, appointmentsByDate[date] ?? 0)
        }
    }

    // For audit/accessibility
    private var minValue: Int { sortedData.map(\.count).min() ?? 0 }
    private var maxValue: Int { sortedData.map(\.count).max() ?? 0 }
    private var dateRange: String {
        guard let first = sortedData.first?.date, let last = sortedData.last?.date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appointments (Last 14 Days)")
                .font(.title3).bold()
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("AppointmentVolumeChart-Header")

            Chart(sortedData, id: \.date) { entry in
                BarMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Appointments", entry.count)
                )
                .foregroundStyle(Color.accentColor)
                .annotation(position: .top) {
                    if entry.count > 0 {
                        Text("\(entry.count)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .accessibilityIdentifier("AppointmentVolumeChart-BarLabel-\(entry.date.timeIntervalSince1970)")
                    }
                }
                .accessibilityLabel("\(entry.count) appointments on \(entry.date.formatted(.dateTime.month(.abbreviated).day()))")
                .accessibilityIdentifier("AppointmentVolumeChart-Bar-\(entry.date.timeIntervalSince1970)")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .padding(.horizontal)
            .accessibilityIdentifier("AppointmentVolumeChart-Chart")
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appointment volume chart for the last 14 days. \(dateRange), minimum \(minValue), maximum \(maxValue) appointments.")
        .accessibilityIdentifier("AppointmentVolumeChart-Container")
        .onAppear {
            AppointmentVolumeChartAudit.record(
                pointCount: sortedData.count,
                dateRange: dateRange,
                minValue: minValue,
                maxValue: maxValue
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentVolumeChartAuditAdmin {
    public static var lastSummary: String { AppointmentVolumeChartAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentVolumeChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentVolumeChartAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct AppointmentVolumeChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sampleData: [Date: Int] = [:]
        for i in 0..<14 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                sampleData[date] = Int.random(in: 0...5)
            }
        }
        return AppointmentVolumeChart(appointmentsByDate: sampleData)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
