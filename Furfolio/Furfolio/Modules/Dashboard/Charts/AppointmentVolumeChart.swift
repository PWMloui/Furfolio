//
//  AppointmentVolumeChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Appointment Volume Chart
//

import SwiftUI
import Charts
import AVFoundation

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

    // MARK: - Analytics Enhancements

    /// Computes the average number of appointments (pointCount) across all logged events.
    static var averageAppointments: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.pointCount }
        return Double(total) / Double(log.count)
    }

    /// Finds the minValue that appears most frequently in the log.
    static var mostFrequentMinValue: Int? {
        guard !log.isEmpty else { return nil }
        let frequency = Dictionary(grouping: log, by: { $0.minValue })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - CSV Export Enhancement

    /// Exports the last audit event as a CSV string with columns: timestamp,pointCount,dateRange,minValue,maxValue,tags
    static func exportCSV() -> String? {
        guard let last = log.last else { return nil }
        let formatter = ISO8601DateFormatter()
        let timestampStr = formatter.string(from: last.timestamp)
        let tagsStr = last.tags.joined(separator: ";")
        let csvLine = "\"\(timestampStr)\",\(last.pointCount),\"\(last.dateRange)\",\(last.minValue),\(last.maxValue),\"\(tagsStr)\""
        let header = "timestamp,pointCount,dateRange,minValue,maxValue,tags"
        return "\(header)\n\(csvLine)"
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
            // Accessibility Enhancement: VoiceOver announcement if minValue is zero
            if minValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, argument: "Some days had zero appointments.")
                }
            }
        }
        #if DEBUG
        .overlay(
            // DEV Overlay: Show last 3 audit events, averageAppointments, and mostFrequentMinValue
            VStack(alignment: .leading, spacing: 4) {
                Text("DEV Audit Overlay")
                    .font(.caption).bold()
                    .foregroundColor(.white)
                ForEach(AppointmentVolumeChartAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                Text(String(format: "Avg Appointments: %.2f", AppointmentVolumeChartAudit.averageAppointments))
                    .font(.caption2)
                    .foregroundColor(.white)
                if let mostFreqMin = AppointmentVolumeChartAudit.mostFrequentMinValue {
                    Text("Most Frequent Min Value: \(mostFreqMin)")
                        .font(.caption2)
                        .foregroundColor(.white)
                } else {
                    Text("Most Frequent Min Value: n/a")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding(),
            alignment: .bottomLeading
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentVolumeChartAuditAdmin {
    public static var lastSummary: String { AppointmentVolumeChartAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentVolumeChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentVolumeChartAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    // Expose analytics properties
    public static var averageAppointments: Double { AppointmentVolumeChartAudit.averageAppointments }
    public static var mostFrequentMinValue: Int? { AppointmentVolumeChartAudit.mostFrequentMinValue }

    // Expose CSV export
    public static func exportCSV() -> String? { AppointmentVolumeChartAudit.exportCSV() }
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
