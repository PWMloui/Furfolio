//
//  Heatmap.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Heatmap
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct HeatmapAuditEvent: Codable {
    let timestamp: Date
    let rowCount: Int
    let colCount: Int
    let maxValue: Double
    let minValue: Double
    let peakCell: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Heatmap: \(rowCount)x\(colCount), max \(maxValue) at \(peakCell), min \(minValue) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class HeatmapAudit {
    static private(set) var log: [HeatmapAuditEvent] = []

    /// Records a new heatmap audit event with given parameters.
    static func record(
        rowCount: Int,
        colCount: Int,
        maxValue: Double,
        minValue: Double,
        peakCell: String,
        tags: [String] = ["heatmap"]
    ) {
        let event = HeatmapAuditEvent(
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

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides an accessibility summary string for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No heatmap events recorded."
    }

    /// Returns the accessibility labels of recent audit events up to the specified limit.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - New Enhancements for Analytics and CSV Export

    /// Computes the average maxValue across all logged events.
    static var averageMaxValue: Double {
        guard !log.isEmpty else { return 0 }
        let sum = log.reduce(0) { $0 + $1.maxValue }
        return sum / Double(log.count)
    }

    /// Determines the most frequently occurring peakCell string in the log.
    static var mostFrequentPeakCell: String {
        guard !log.isEmpty else { return "none" }
        var frequency: [String: Int] = [:]
        for event in log {
            frequency[event.peakCell, default: 0] += 1
        }
        return frequency.max(by: { $0.value < $1.value })?.key ?? "none"
    }

    /// Exports all audit events to CSV format with columns:
    /// timestamp,rowCount,colCount,maxValue,minValue,peakCell,tags
    static func exportCSV() -> String {
        let header = "timestamp,rowCount,colCount,maxValue,minValue,peakCell,tags"
        let rows = log.map { event in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|")
            return "\(dateStr),\(event.rowCount),\(event.colCount),\(event.maxValue),\(event.minValue),\"\(event.peakCell)\",\"\(tagsStr)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - Heatmap View

public struct Heatmap: View {
    /// 2D array of Double values, [row][col]
    public let data: [[Double]]
    public let rowLabels: [String]
    public let colLabels: [String]

    private var rowCount: Int { data.count }
    private var colCount: Int { data.first?.count ?? 0 }
    private var maxValue: Double { data.flatMap { $0 }.max() ?? 1 }
    private var minValue: Double { data.flatMap { $0 }.min() ?? 0 }

    private var peakCell: (row: Int, col: Int, value: Double)? {
        var best: (Int, Int, Double)? = nil
        for (rowIdx, row) in data.enumerated() {
            for (colIdx, value) in row.enumerated() {
                if best == nil || value > best!.2 {
                    best = (rowIdx, colIdx, value)
                }
            }
        }
        return best
    }

    /// Publisher to trigger VoiceOver announcements.
    @State private var voiceOverAnnouncement: String?

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
                        .accessibilityIdentifier("Heatmap-ColLabel-\(colLabels[c])")
                }
            }

            // Rows
            ForEach(data.indices, id: \.self) { r in
                HStack(spacing: 2) {
                    Text(rowLabels[r])
                        .font(.caption2)
                        .frame(width: 44, height: 24)
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("Heatmap-RowLabel-\(rowLabels[r])")
                    ForEach(data[r].indices, id: \.self) { c in
                        let value = data[r][c]
                        Rectangle()
                            .fill(cellColor(for: value))
                            .frame(width: 28, height: 24)
                            .cornerRadius(3)
                            .overlay(
                                value > 0
                                ? Text("\(Int(value))")
                                    .font(.caption2)
                                    .foregroundColor(textColor(for: value))
                                    .accessibilityIdentifier("Heatmap-CellValue-\(r)-\(c)")
                                : nil
                            )
                            .accessibilityLabel("\(rowLabels[r]), \(colLabels[c]), value \(Int(value))")
                            .accessibilityIdentifier("Heatmap-Cell-\(r)-\(c)")
                    }
                }
            }

            #if DEBUG
            // DEV overlay showing last 3 audit events and analytics
            HeatmapAuditOverlay()
                .padding(.top, 8)
            #endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heatmapSummary)
        .accessibilityIdentifier("Heatmap-Container")
        .onAppear {
            HeatmapAudit.record(
                rowCount: rowCount,
                colCount: colCount,
                maxValue: maxValue,
                minValue: minValue,
                peakCell: peakCell != nil ? "\(rowLabels[peakCell!.row]),\(colLabels[peakCell!.col])" : "none"
            )
            // Accessibility enhancement: VoiceOver announcement if minValue is zero
            if minValue == 0 {
                // Post notification to announce warning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, argument: "Warning: At least one cell has a value of zero.")
                }
            }
        }
    }

    private func cellColor(for value: Double) -> Color {
        guard maxValue > minValue else { return Color.gray.opacity(0.12) }
        let normalized = (value - minValue) / (maxValue - minValue)
        return Color.red.opacity(0.25 + 0.75 * normalized)
    }
    private func textColor(for value: Double) -> Color {
        cellColor(for: value).luminance > 0.6 ? .black : .white
    }

    private var heatmapSummary: String {
        let peak = peakCell
        var summary = "Heatmap \(rowCount) by \(colCount). Max value \(Int(maxValue)), min value \(Int(minValue))."
        if let p = peak {
            summary += " Peak cell: \(rowLabels[p.row]), \(colLabels[p.col]) (\(Int(p.value)))."
        }
        return summary
    }
}

// MARK: - Audit/Admin Accessors

public enum HeatmapAuditAdmin {
    public static var lastSummary: String { HeatmapAudit.accessibilitySummary }
    public static var lastJSON: String? { HeatmapAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        HeatmapAudit.recentEvents(limit: limit)
    }

    // Expose new analytics properties
    /// Average of all maxValue entries in audit log.
    public static var averageMaxValue: Double { HeatmapAudit.averageMaxValue }

    /// Most frequent peakCell string in audit log.
    public static var mostFrequentPeakCell: String { HeatmapAudit.mostFrequentPeakCell }

    /// Exports audit log as CSV string.
    public static func exportCSV() -> String {
        HeatmapAudit.exportCSV()
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

// MARK: - DEV Overlay View for Debugging

#if DEBUG
/// SwiftUI overlay view showing recent audit events and analytics for development purposes.
private struct HeatmapAuditOverlay: View {
    private let recentEvents: [String] = HeatmapAudit.recentEvents(limit: 3)
    private let averageMax: Double = HeatmapAudit.averageMaxValue
    private let frequentPeak: String = HeatmapAudit.mostFrequentPeakCell

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEV Audit Overlay")
                .font(.headline)
                .foregroundColor(.blue)
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Last 3 Events:")
                    .font(.subheadline)
                    .bold()
                ForEach(recentEvents, id: \.self) { event in
                    Text(event)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
            }
            Divider()
            Text(String(format: "Average Max Value: %.2f", averageMax))
                .font(.footnote)
                .foregroundColor(.primary)
            Text("Most Frequent Peak Cell: \(frequentPeak)")
                .font(.footnote)
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.9))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct Heatmap_Previews: PreviewProvider {
    static var previews: some View {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let hours = (8...19).map { "\($0)" }
        let data = (0..<days.count).map { _ in
            (0..<hours.count).map { _ in Double(Int.random(in: 0...7)) }
        }
        Heatmap(data: data, rowLabels: days, colLabels: hours)
            .frame(width: 440, height: 280)
    }
}
#endif
