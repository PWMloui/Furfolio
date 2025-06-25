

//
//  DonutChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Donut Chart
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DonutChartAuditEvent: Codable {
    let timestamp: Date
    let segmentCount: Int
    let segments: [String]
    let total: Double
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] DonutChart: \(segmentCount) segments, segments: [\(segments.joined(separator: ", "))], total: \(total) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DonutChartAudit {
    static private(set) var log: [DonutChartAuditEvent] = []

    static func record(
        segmentCount: Int,
        segments: [String],
        total: Double,
        tags: [String] = ["donutChart"]
    ) {
        let event = DonutChartAuditEvent(
            timestamp: Date(),
            segmentCount: segmentCount,
            segments: segments,
            total: total,
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
        log.last?.accessibilityLabel ?? "No donut chart events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Model

public struct DonutChartSegment: Identifiable {
    public let id = UUID()
    public let label: String
    public let value: Double
    public let color: Color

    public init(label: String, value: Double, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
}

// MARK: - DonutChart

public struct DonutChart: View {
    public let segments: [DonutChartSegment]
    public var centerText: String?

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    public init(segments: [DonutChartSegment], centerText: String? = nil) {
        self.segments = segments
        self.centerText = centerText
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(segments.indices, id: \.self) { index in
                    let startAngle = angle(for: index)
                    let endAngle = angle(for: index + 1)
                    DonutSegmentShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        thickness: size * 0.22
                    )
                    .fill(segments[index].color)
                    .accessibilityLabel("\(segments[index].label), \(percentage(for: segments[index]))%")
                    .accessibilityIdentifier("DonutChart-Segment-\(segments[index].label)")
                }
                if let text = centerText {
                    Text(text)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("DonutChart-CenterText")
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Donut chart with \(segments.count) segments, total \(total)")
        .accessibilityIdentifier("DonutChart-Container")
        .onAppear {
            DonutChartAudit.record(
                segmentCount: segments.count,
                segments: segments.map { $0.label },
                total: total
            )
        }
    }

    private func angle(for index: Int) -> Angle {
        let sum = segments.prefix(index).reduce(0) { $0 + $1.value }
        return .degrees((sum / max(total, 1)) * 360 - 90)
    }

    private func percentage(for segment: DonutChartSegment) -> String {
        total > 0 ? String(format: "%.1f", (segment.value / total) * 100) : "0"
    }
}

// MARK: - DonutSegmentShape

private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let innerRadius = radius - thickness

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Audit/Admin Accessors

public enum DonutChartAuditAdmin {
    public static var lastSummary: String { DonutChartAudit.accessibilitySummary }
    public static var lastJSON: String? { DonutChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DonutChartAudit.recentEvents(limit: limit)
    }
}

// MARK: - Preview

#if DEBUG
struct DonutChart_Previews: PreviewProvider {
    static var previews: some View {
        let segments = [
            DonutChartSegment(label: "Grooming", value: 58, color: .green),
            DonutChartSegment(label: "Bath", value: 22, color: .blue),
            DonutChartSegment(label: "Nail", value: 14, color: .orange),
            DonutChartSegment(label: "Other", value: 6, color: .pink)
        ]
        VStack {
            DonutChart(segments: segments, centerText: "100")
                .frame(width: 200, height: 200)
            Text("Audit Summary: \(DonutChartAuditAdmin.lastSummary)").font(.caption)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
