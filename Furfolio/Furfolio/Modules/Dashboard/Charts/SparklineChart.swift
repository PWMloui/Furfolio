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

fileprivate final class SparklineChartAudit {
    static private(set) var log: [SparklineChartAuditEvent] = []

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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No sparkline chart events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
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

public enum SparklineChartAuditAdmin {
    public static var lastSummary: String { SparklineChartAudit.accessibilitySummary }
    public static var lastJSON: String? { SparklineChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        SparklineChartAudit.recentEvents(limit: limit)
    }
}

#if DEBUG
struct SparklineChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            SparklineChart(data: [1, 3, 2, 5, 4, 6, 5])
            SparklineChart(data: [5, 4, 4, 3, 2, 1])
            SparklineChart(data: [2, 2, 2, 2, 2])
            SparklineChart(data: [])
        }
        .frame(height: 48)
        .padding(.horizontal)
        .previewLayout(.sizeThatFits)
    }
}
#endif
