//
//  SparklineChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Sparkline Chart
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct SparklineChartAuditEvent: Codable {
    let timestamp: Date
    let dataCount: Int
    let valueRange: String
    let latest: Double?
    let trend: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let latestStr = latest != nil ? String(format: "%.2f", latest!) : "none"
        return "[Appear] SparklineChart: \(dataCount) points, range: \(valueRange), latest: \(latestStr), trend: \(trend) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

/// Audit/event log manager for SparklineChart.
/// - Business enhancement: analytics, CSV export
/// - Accessibility: VoiceOver warning for decreasing trend
fileprivate final class SparklineChartAudit {
    static private(set) var log: [SparklineChartAuditEvent] = []

    /// Record a new audit event and post accessibility warning if needed.
    static func record(
        data: [Double],
        tags: [String] = ["sparklineChart"]
    ) {
        let count = data.count
        let min = data.min() ?? 0
        let max = data.max() ?? 0
        let valueRange = count > 0 ? String(format: "%.2f–%.2f", min, max) : "n/a"
        let latest = data.last
        let trend: String
        if count >= 2, let last = latest {
            let previous = data[count - 2]
            trend = last > previous ? "increasing" : (last < previous ? "decreasing" : "stable")
        } else {
            trend = "no trend"
        }
        let event = SparklineChartAuditEvent(
            timestamp: Date(),
            dataCount: count,
            valueRange: valueRange,
            latest: latest,
            trend: trend,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }

        // Accessibility: If any event's trend is "decreasing", post VoiceOver warning.
        if trend == "decreasing" {
            #if os(iOS)
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: "Warning: Trend is decreasing.")
            }
            #elseif os(macOS)
            // macOS accessibility announcement
            #endif
        }
    }

    /// Export the last event as JSON (for debugging/admin).
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Export the audit log as CSV.
    /// - Business enhancement: CSV includes timestamp, dataCount, valueRange, latest, trend, tags
    static func exportCSV() -> String {
        let header = "timestamp,dataCount,valueRange,latest,trend,tags"
        let df = ISO8601DateFormatter()
        let rows = log.map { event in
            let ts = df.string(from: event.timestamp)
            let dc = "\(event.dataCount)"
            let vr = "\"\(event.valueRange)\""
            let latestStr = event.latest.map { String(format: "%.4f", $0) } ?? ""
            let trend = event.trend
            let tags = "\"\(event.tags.joined(separator: ","))\""
            return [ts, dc, vr, latestStr, trend, tags].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Accessibility summary for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No sparkline chart events recorded."
    }

    /// Return recent audit event descriptions.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - Analytics Enhancements

    /// Mean of all latest values in the log (ignoring nils). Business analytics enhancement.
    static var averageLatest: Double? {
        let values = log.compactMap { $0.latest }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    /// Most frequent trend string in the log. Business analytics enhancement.
    static var mostFrequentTrend: String? {
        let trends = log.map { $0.trend }
        guard !trends.isEmpty else { return nil }
        let freq = trends.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return freq.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - SparklineChart

/// A minimalistic sparkline chart for visualizing small data trends.
struct SparklineChart: View {
    var data: [Double]
    var lineColor: Color = .accentColor
    var fillColor: Color = Color.accentColor.opacity(0.25)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let points = normalizedPoints(size: size)

            if points.count > 1 {
                ZStack {
                    filledPath(points: points, size: size)
                        .fill(fillColor)
                        .accessibilityIdentifier("SparklineChart-FillPath")

                    sparklinePath(points: points)
                        .stroke(lineColor, lineWidth: 2)
                        .shadow(color: lineColor.opacity(0.20), radius: 1, x: 0, y: 1)
                        .accessibilityIdentifier("SparklineChart-LinePath")
                }
            } else {
                // Single point or empty: draw horizontal midline if needed
                if let centerY = points.first?.y {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: centerY))
                        path.addLine(to: CGPoint(x: size.width, y: centerY))
                    }
                    .stroke(lineColor, lineWidth: 1)
                    .accessibilityIdentifier("SparklineChart-Midline")
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("SparklineChart-Container")
        .onAppear {
            SparklineChartAudit.record(data: data)
        }
    }

    private func filledPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: points.first!.x, y: size.height))
            for pt in points {
                path.addLine(to: pt)
            }
            path.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func sparklinePath(points: [CGPoint]) -> Path {
        Path { path in
            path.move(to: points.first!)
            for pt in points.dropFirst() {
                path.addLine(to: pt)
            }
        }
    }

    /// Normalizes data points to fit within the given size.
    private func normalizedPoints(size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        let count = data.count
        let min = data.min() ?? 0
        let max = data.max() ?? 0

        return data.enumerated().map { idx, value in
            let x = CGFloat(idx) / CGFloat(max(1, count - 1)) * size.width
            let y: CGFloat
            if max != min {
                y = size.height * (1 - CGFloat((value - min) / (max - min)))
            } else {
                y = size.height / 2
            }
            return CGPoint(x: x, y: y)
        }
    }

    private var accessibilityLabel: String {
        guard let last = data.last else {
            return "No data available"
        }
        let trend: String
        if data.count >= 2 {
            let previous = data[data.count - 2]
            trend = last > previous ? "increasing" : (last < previous ? "decreasing" : "stable")
        } else {
            trend = "no trend"
        }
        return String(format: "Latest value %.2f, trend is %@", last, trend)
    }
}

// MARK: - Audit/Admin Accessors

/// Admin/business accessors for SparklineChart audit, analytics, and export.
public enum SparklineChartAuditAdmin {
    /// Accessibility summary of last event.
    public static var lastSummary: String { SparklineChartAudit.accessibilitySummary }
    /// Last event as JSON.
    public static var lastJSON: String? { SparklineChartAudit.exportLastJSON() }
    /// Recent event descriptions.
    public static func recentEvents(limit: Int = 5) -> [String] {
        SparklineChartAudit.recentEvents(limit: limit)
    }
    /// Export audit log as CSV (business enhancement).
    public static func exportCSV() -> String {
        SparklineChartAudit.exportCSV()
    }
    /// Mean of all latest values in log (business analytics).
    public static var averageLatest: Double? { SparklineChartAudit.averageLatest }
    /// Most frequent trend string in log (business analytics).
    public static var mostFrequentTrend: String? { SparklineChartAudit.mostFrequentTrend }
}

#if DEBUG
/// DEV overlay: Shows last 3 audit events, averageLatest, mostFrequentTrend at the bottom in DEBUG builds.
struct SparklineChartDevOverlay: View {
    /// Show last 3 events, averageLatest, and mostFrequentTrend
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SparklineChart DEV Overlay")
                .font(.caption)
                .foregroundColor(.secondary)
            let events = SparklineChartAuditAdmin.recentEvents(limit: 3)
            ForEach(events.indices, id: \.self) { idx in
                Text(events[idx])
                    .font(.caption2)
                    .lineLimit(2)
            }
            HStack(spacing: 16) {
                Text("Average latest: \(SparklineChartAuditAdmin.averageLatest.map { String(format: "%.2f", $0) } ?? "--")")
                    .font(.caption2)
                Text("Most frequent trend: \(SparklineChartAuditAdmin.mostFrequentTrend ?? "--")")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct SparklineChart_Previews: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                SparklineChart(data: [1, 3, 2, 5, 4, 6, 5])
                SparklineChart(data: [5, 4, 4, 3, 2, 1])
                SparklineChart(data: [2, 2, 2, 2, 2])
                SparklineChart(data: [])
            }
            .frame(height: 48)
            .padding(.horizontal)
            if !SparklineChartAuditAdmin.recentEvents(limit: 1).isEmpty {
                SparklineChartDevOverlay()
                    .transition(.move(edge: .bottom))
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
