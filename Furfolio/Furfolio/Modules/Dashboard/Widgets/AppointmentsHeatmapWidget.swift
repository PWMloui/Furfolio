//
//  AppointmentsHeatmapWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Appointments Heatmap Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentsHeatmapAuditEvent: Codable {
    let timestamp: Date
    let rowCount: Int
    let colCount: Int
    let maxValue: Int
    let minValue: Int
    let peakCell: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] AppointmentsHeatmap: \(rowCount)x\(colCount), max \(maxValue) at \(peakCell), min \(minValue) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class AppointmentsHeatmapAudit {
    static private(set) var log: [AppointmentsHeatmapAuditEvent] = []

    static func record(
        rowCount: Int,
        colCount: Int,
        maxValue: Int,
        minValue: Int,
        peakCell: String,
        tags: [String] = ["appointmentsHeatmap"]
    ) {
        let event = AppointmentsHeatmapAuditEvent(
            timestamp: Date(),
            rowCount: rowCount,
            colCount: colCount,
            maxValue: maxValue,
            minValue: minValue,
            peakCell: peakCell,
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
        log.last?.accessibilityLabel ?? "No appointments heatmap events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - AppointmentsHeatmapWidget

public struct AppointmentsHeatmapWidget: View {
    public let data: [[Int]]
    public let rowLabels: [String]
    public let colLabels: [String]

    private var rowCount: Int { data.count }
    private var colCount: Int { data.first?.count ?? 0 }
    private var maxValue: Int { data.flatMap { $0 }.max() ?? 1 }
    private var minValue: Int { data.flatMap { $0 }.min() ?? 0 }

    private var peakCell: (row: Int, col: Int, value: Int)? {
        var best: (Int, Int, Int)? = nil
        for (rowIdx, row) in data.enumerated() {
            for (colIdx, value) in row.enumerated() {
                if best == nil || value > best!.2 {
                    best = (rowIdx, colIdx, value)
                }
            }
        }
        return best
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Col labels
            HStack(spacing: 2) {
                Text("") // Spacer for row labels
                    .frame(width: 44)
                ForEach(colLabels.indices, id: \.self) { c in
                    Text(colLabels[c])
                        .font(.caption2)
                        .frame(width: 28, height: 18)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("AppointmentsHeatmapWidget-ColLabel-\(colLabels[c])")
                }
            }

            // Rows
            ForEach(data.indices, id: \.self) { r in
                HStack(spacing: 2) {
                    Text(rowLabels[r])
                        .font(.caption2)
                        .frame(width: 44, height: 24)
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("AppointmentsHeatmapWidget-RowLabel-\(rowLabels[r])")
                    ForEach(data[r].indices, id: \.self) { c in
                        let value = data[r][c]
                        Rectangle()
                            .fill(cellColor(for: value))
                            .frame(width: 28, height: 24)
                            .cornerRadius(3)
                            .overlay(
                                value > 0
                                ? Text("\(value)")
                                    .font(.caption2)
                                    .foregroundColor(textColor(for: value))
                                    .accessibilityIdentifier("AppointmentsHeatmapWidget-CellValue-\(r)-\(c)")
                                : nil
                            )
                            .accessibilityLabel("\(rowLabels[r]), \(colLabels[c]), value \(value)")
                            .accessibilityIdentifier("AppointmentsHeatmapWidget-Cell-\(r)-\(c)")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heatmapSummary)
        .accessibilityIdentifier("AppointmentsHeatmapWidget-Container")
        .onAppear {
            AppointmentsHeatmapAudit.record(
                rowCount: rowCount,
                colCount: colCount,
                maxValue: maxValue,
                minValue: minValue,
                peakCell: peakCell != nil ? "\(rowLabels[peakCell!.row]),\(colLabels[peakCell!.col])" : "none"
            )
        }
    }

    private func cellColor(for value: Int) -> Color {
        guard maxValue > minValue else { return Color.gray.opacity(0.12) }
        let normalized = Double(value - minValue) / Double(maxValue - minValue)
        return Color.blue.opacity(0.20 + 0.80 * normalized)
    }
    private func textColor(for value: Int) -> Color {
        cellColor(for: value).luminance > 0.6 ? .black : .white
    }

    private var heatmapSummary: String {
        let peak = peakCell
        var summary = "Appointments heatmap \(rowCount) by \(colCount). Max value \(maxValue), min value \(minValue)."
        if let p = peak {
            summary += " Peak cell: \(rowLabels[p.row]), \(colLabels[p.col]) (\(p.value))."
        }
        return summary
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentsHeatmapWidgetAuditAdmin {
    public static var lastSummary: String { AppointmentsHeatmapAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentsHeatmapAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentsHeatmapAudit.recentEvents(limit: limit)
    }
}

// MARK: - Color Luminance Extension

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

// MARK: - Preview

#if DEBUG
struct AppointmentsHeatmapWidget_Previews: PreviewProvider {
    static var previews: some View {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let hours = (8...19).map { "\($0)" }
        let data = (0..<days.count).map { _ in
            (0..<hours.count).map { _ in Int.random(in: 0...7) }
        }
        AppointmentsHeatmapWidget(data: data, rowLabels: days, colLabels: hours)
            .frame(width: 440, height: 280)
    }
}
#endif
