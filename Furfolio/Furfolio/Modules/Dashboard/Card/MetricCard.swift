//
//  MetricCard.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Metric Card
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct MetricCardAuditEvent: Codable {
    let timestamp: Date
    let metric: String
    let value: String
    let icon: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(metric): \(value), icon: \(icon) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class MetricCardAudit {
    static private(set) var log: [MetricCardAuditEvent] = []

    static func record(
        metric: String,
        value: String,
        icon: String,
        tags: [String] = ["MetricCard"]
    ) {
        let event = MetricCardAuditEvent(
            timestamp: Date(),
            metric: metric,
            value: value,
            icon: icon,
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
        log.last?.accessibilityLabel ?? "No MetricCard events recorded."
    }
}

// MARK: - MetricCard

struct MetricCard: View {
    let metric: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("MetricCard-IconBG-\(metric)")
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("MetricCard-Icon-\(metric)")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("MetricCard-Title-\(metric)")
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("MetricCard-Value-\(metric)")
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric), value \(value)")
        .accessibilityIdentifier("MetricCard-Container-\(metric)")
        .onAppear {
            MetricCardAudit.record(
                metric: metric,
                value: value,
                icon: icon
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum MetricCardAuditAdmin {
    public static var lastSummary: String { MetricCardAudit.accessibilitySummary }
    public static var lastJSON: String? { MetricCardAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        MetricCardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct MetricCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MetricCard(metric: "Total Revenue", value: "$12,345", icon: "dollarsign.circle.fill", iconColor: .green)
            MetricCard(metric: "Upcoming Appointments", value: "5", icon: "calendar", iconColor: .blue)
            MetricCard(metric: "Inactive Customers", value: "3", icon: "person.fill.xmark", iconColor: .red)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
