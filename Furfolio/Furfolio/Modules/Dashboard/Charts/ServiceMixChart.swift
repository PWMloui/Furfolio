//
//  ServiceMixChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Service Mix Chart
//

import SwiftUI
import Charts

// MARK: - Audit/Event Logging

fileprivate struct ServiceMixChartAuditEvent: Codable {
    let timestamp: Date
    let segmentCount: Int
    let services: [String]
    let valueRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] ServiceMixChart: \(segmentCount) segments, services: \(services.joined(separator: ", ")), \(valueRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ServiceMixChartAudit {
    static private(set) var log: [ServiceMixChartAuditEvent] = []

    static func record(
        segmentCount: Int,
        services: [String],
        valueRange: String,
        tags: [String] = ["serviceMixChart"]
    ) {
        let event = ServiceMixChartAuditEvent(
            timestamp: Date(),
            segmentCount: segmentCount,
            services: services,
            valueRange: valueRange,
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
        log.last?.accessibilityLabel ?? "No service mix chart events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Model

struct ServiceMixData: Identifiable {
    var id = UUID()
    var service: String
    var count: Int
}

// MARK: - ServiceMixChart

struct ServiceMixChart: View {
    let data: [ServiceMixData]

    // Predefined colors for segments
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .yellow
    ]

    // Total count for calculating percentages
    private var totalCount: Int {
        data.reduce(0) { $0 + $1.count }
    }

    // For audit/accessibility
    private var valueRange: String {
        guard let min = data.map(\.count).min(),
              let max = data.map(\.count).max() else { return "n/a" }
        return "min \(min), max \(max)"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Service Mix")
                .font(.headline)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ServiceMixChart-Header")

            Chart(data) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Service", item.service))
                .annotation(position: .overlay, alignment: .center) {
                    if totalCount > 0 {
                        let percent = Double(item.count) / Double(totalCount) * 100
                        Text("\(item.service)\n\(String(format: "%.1f", percent))%")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .accessibilityIdentifier("ServiceMixChart-Annotation-\(item.service)")
                    }
                }
                .accessibilityLabel("\(item.service), \(item.count) appointments (\(String(format: "%.1f", Double(item.count)/Double(max(totalCount, 1))*100))%)")
                .accessibilityIdentifier("ServiceMixChart-Sector-\(item.service)")
            }
            .chartForegroundStyleScale(
                Dictionary(uniqueKeysWithValues: data.enumerated().map { (index, item) in
                    (item.service, colors[index % colors.count])
                })
            )
            .frame(height: 260)
            .accessibilityIdentifier("ServiceMixChart-MainChart")

            // Legend
            VStack(alignment: .leading, spacing: 8) {
                ForEach(data.indices, id: \.self) { idx in
                    HStack {
                        Rectangle()
                            .fill(colors[idx % colors.count])
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                            .accessibilityHidden(true)
                        Text(data[idx].service)
                            .font(.subheadline)
                            .accessibilityIdentifier("ServiceMixChart-Legend-\(data[idx].service)")
                    }
                }
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Service mix legend: \(data.map { $0.service }.joined(separator: ", "))")
            .accessibilityIdentifier("ServiceMixChart-Legend")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Service mix pie chart with \(data.count) segments, showing distribution of services. \(valueRange)")
        .accessibilityIdentifier("ServiceMixChart-Container")
        .onAppear {
            ServiceMixChartAudit.record(
                segmentCount: data.count,
                services: data.map { $0.service },
                valueRange: valueRange
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ServiceMixChartAuditAdmin {
    public static var lastSummary: String { ServiceMixChartAudit.accessibilitySummary }
    public static var lastJSON: String? { ServiceMixChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ServiceMixChartAudit.recentEvents(limit: limit)
    }
}

#if DEBUG
struct ServiceMixChart_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = [
            ServiceMixData(service: "Full Groom", count: 45),
            ServiceMixData(service: "Bath Only", count: 25),
            ServiceMixData(service: "Nail Trim", count: 15),
            ServiceMixData(service: "Other", count: 10)
        ]

        ServiceMixChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
