//
//  ServiceTrendsWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Service Trends Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ServiceTrendsAuditEvent: Codable {
    let timestamp: Date
    let serviceCount: Int
    let topService: String?
    let valueRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] ServiceTrendsWidget: \(serviceCount) services, top: \(topService ?? "n/a"), \(valueRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ServiceTrendsAudit {
    static private(set) var log: [ServiceTrendsAuditEvent] = []

    static func record(
        serviceCount: Int,
        topService: String?,
        valueRange: String,
        tags: [String] = ["serviceTrendsWidget"]
    ) {
        let event = ServiceTrendsAuditEvent(
            timestamp: Date(),
            serviceCount: serviceCount,
            topService: topService,
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
        log.last?.accessibilityLabel ?? "No service trends events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Model

public struct ServiceTrend: Identifiable {
    public let id = UUID()
    public let name: String
    public let count: Int
    public let trend: Double  // percent change (e.g., +8.0 for +8%)

    public init(name: String, count: Int, trend: Double) {
        self.name = name
        self.count = count
        self.trend = trend
    }
}

// MARK: - ServiceTrendsWidget

public struct ServiceTrendsWidget: View {
    public let trends: [ServiceTrend]

    private var valueRange: String {
        guard let min = trends.map(\.count).min(),
              let max = trends.map(\.count).max() else { return "n/a" }
        return "min \(min), max \(max)"
    }
    private var topService: String? {
        trends.max(by: { $0.count < $1.count })?.name
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Service Trends")
                    .font(.headline)
                    .accessibilityIdentifier("ServiceTrendsWidget-Title")
            }
            .padding(.bottom, 2)

            if trends.isEmpty {
                Text("No service trends available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("ServiceTrendsWidget-Empty")
            } else {
                ForEach(trends) { trend in
                    HStack {
                        Text(trend.name)
                            .font(.subheadline)
                            .accessibilityIdentifier("ServiceTrendsWidget-ServiceName-\(trend.name)")
                        Spacer()
                        Text("\(trend.count)")
                            .font(.subheadline.weight(.bold))
                            .accessibilityIdentifier("ServiceTrendsWidget-ServiceCount-\(trend.name)")
                        TrendIndicator(value: trend.trend)
                            .accessibilityIdentifier("ServiceTrendsWidget-TrendIndicator-\(trend.name)")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("ServiceTrendsWidget-Container")
        .onAppear {
            ServiceTrendsAudit.record(
                serviceCount: trends.count,
                topService: topService,
                valueRange: valueRange
            )
        }
    }

    private var accessibilitySummary: String {
        if trends.isEmpty {
            return "No service trends available"
        } else {
            let top = topService ?? "none"
            return "Service trends. \(trends.count) services. Top: \(top). Value range: \(valueRange)"
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ServiceTrendsWidgetAuditAdmin {
    public static var lastSummary: String { ServiceTrendsAudit.accessibilitySummary }
    public static var lastJSON: String? { ServiceTrendsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ServiceTrendsAudit.recentEvents(limit: limit)
    }
}

// MARK: - Preview

#if DEBUG
struct ServiceTrendsWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = [
            ServiceTrend(name: "Full Groom", count: 35, trend: 4.5),
            ServiceTrend(name: "Bath", count: 21, trend: -1.2),
            ServiceTrend(name: "Nail Trim", count: 18, trend: 2.1),
            ServiceTrend(name: "Other", count: 7, trend: 0.0)
        ]
        ServiceTrendsWidget(trends: sample)
            .frame(width: 320)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
