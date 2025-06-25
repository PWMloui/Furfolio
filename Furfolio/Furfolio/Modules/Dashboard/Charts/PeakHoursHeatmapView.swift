//
//  PeakHoursHeatmapView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Peak Hours Heatmap
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct PeakHoursHeatmapAuditEvent: Codable {
    let timestamp: Date
    let maxCount: Int
    let minCount: Int
    let mostPopular: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] PeakHoursHeatmap: max \(maxCount), min \(minCount), peak: \(mostPopular) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class PeakHoursHeatmapAudit {
    static private(set) var log: [PeakHoursHeatmapAuditEvent] = []

    static func record(
        maxCount: Int,
        minCount: Int,
        mostPopular: String,
        tags: [String] = ["peakHoursHeatmap"]
    ) {
        let event = PeakHoursHeatmapAuditEvent(
            timestamp: Date(),
            maxCount: maxCount,
            minCount: minCount,
            mostPopular: mostPopular,
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
        log.last?.accessibilityLabel ?? "No heatmap events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Main View

struct PeakHoursHeatmapView: View {
    // [DayOfWeek: [HourOfDay: Count]]
    let peakHoursData: [Int: [Int: Int]]

    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let hoursOfDay = Array(0..<24)

    private var maxCount: Int {
        peakHoursData.values.flatMap { $0.values }.max() ?? 1
    }
    private var minCount: Int {
        peakHoursData.values.flatMap { $0.values }.min() ?? 0
    }
    private var mostPopular: (day: String, hour: Int, count: Int)? {
        var peak: (day: Int, hour: Int, count: Int)? = nil
        for (d, hourDict) in peakHoursData {
            for (h, count) in hourDict {
                if peak == nil || count > peak!.count {
                    peak = (day: d, hour: h, count: count)
                }
            }
        }
        if let p = peak {
            return (day: daysOfWeek[p.day], hour: p.hour, count: p.count)
        }
        return nil
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack {
                    Text("").frame(width: 40)
                    ForEach(hoursOfDay, id: \.self) { hour in
                        Text("\(hour)")
                            .font(.caption2)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("PeakHoursHeatmapView-HourHeader-\(hour)")
                    }
                }

                // Rows for each day
                ForEach(0..<7, id: \.self) { dayIndex in
                    HStack(spacing: 4) {
                        Text(daysOfWeek[dayIndex])
                            .font(.caption2)
                            .frame(width: 40, height: 24)
                            .foregroundColor(.primary)
                            .accessibilityIdentifier("PeakHoursHeatmapView-DayHeader-\(daysOfWeek[dayIndex])")

                        ForEach(hoursOfDay, id: \.self) { hour in
                            let count = peakHoursData[dayIndex]?[hour] ?? 0
                            DayHourCellView(day: daysOfWeek[dayIndex], hour: hour, count: count, maxCount: maxCount)
                                .accessibilityIdentifier("PeakHoursHeatmapView-Cell-\(daysOfWeek[dayIndex])-\(hour)")
                        }
                    }
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 4)
        )
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heatmapSummary)
        .accessibilityIdentifier("PeakHoursHeatmapView-Container")
        .onAppear {
            PeakHoursHeatmapAudit.record(
                maxCount: maxCount,
                minCount: minCount,
                mostPopular: mostPopular != nil ? "\(mostPopular!.day) at \(mostPopular!.hour):00 (\(mostPopular!.count) appts)" : "none"
            )
        }
    }

    private var heatmapSummary: String {
        let max = maxCount
        let min = minCount
        let peak = mostPopular
        var summary = "Heatmap showing peak appointment hours across days of the week."
        summary += " Max cell: \(max), min cell: \(min)."
        if let p = peak {
            summary += " Most popular: \(p.day) at \(p.hour):00 with \(p.count) appointments."
        }
        return summary
    }
}

private struct DayHourCellView: View {
    let day: String
    let hour: Int
    let count: Int
    let maxCount: Int

    private var cellColor: Color {
        guard count > 0 else { return Color.gray.opacity(0.1) }
        let normalized = Double(count) / Double(maxCount)
        return Color.red.opacity(0.2 + 0.8 * normalized)
    }

    private var textColor: Color {
        cellColor.luminance > 0.6 ? .black : .white
    }

    var body: some View {
        Rectangle()
            .fill(cellColor)
            .frame(width: 24, height: 24)
            .cornerRadius(4)
            .overlay(
                count > 0
                    ? Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(textColor)
                        .accessibilityIdentifier("DayHourCellView-Count-\(day)-\(hour)")
                    : nil
            )
            .help("\(day), \(hour):00 — \(count) appointments")
            .accessibilityLabel("\(day), hour \(hour), \(count) appointments")
            .accessibilityIdentifier("DayHourCellView-\(day)-\(hour)")
    }
}

private extension Color {
    var luminance: Double {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
        #else
        return 1.0
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum PeakHoursHeatmapAuditAdmin {
    public static var lastSummary: String { PeakHoursHeatmapAudit.accessibilitySummary }
    public static var lastJSON: String? { PeakHoursHeatmapAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        PeakHoursHeatmapAudit.recentEvents(limit: limit)
    }
}

#if DEBUG
struct PeakHoursHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        var sampleData: [Int: [Int: Int]] = [:]
        for day in 0..<7 {
            var dayData: [Int: Int] = [:]
            for hour in 8..<20 {
                dayData[hour] = Int.random(in: 0...5)
            }
            sampleData[day] = dayData
        }

        return PeakHoursHeatmapView(peakHoursData: sampleData)
            .previewLayout(.sizeThatFits)
    }
}
#endif
