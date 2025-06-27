//
//  ActionableInsightsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Actionable Insights View
//

import SwiftUI

// MARK: - Actionable Insights View

struct ActionableInsightsView: View {
    struct InsightMetric: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let icon: String
        let color: Color
        let tags: [String]
        let description: String?
        let accessibilityLabel: String
    }

    let insights: [InsightMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actionable Insights")
                .font(.title2.bold())
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(10)

            ForEach(insights) { metric in
                InsightCard(
                    title: metric.title,
                    value: metric.value,
                    systemImage: metric.icon,
                    color: metric.color,
                    description: metric.description,
                    accessibilityLabel: metric.accessibilityLabel
                )
                .onAppear {
                    InsightAudit.record(
                        metric: metric.title,
                        value: metric.value,
                        color: metric.color,
                        tags: metric.tags
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - InsightCard

private struct InsightCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    let description: String?
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .bold()
                .foregroundColor(color)

            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)

            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilitySortPriority(5)
    }
}

// MARK: - Audit Tracker

fileprivate struct InsightAuditEvent: Codable {
    let timestamp: Date
    let metric: String
    let value: String
    let color: String
    let context: String
    let tags: [String]

    var accessibilityLabel: String {
        let timeStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(metric): \(value), color: \(color), tags: \(tags.joined(separator: \", \")) at \(timeStr)"
    }
}

fileprivate final class InsightAudit {
    static private(set) var log: [InsightAuditEvent] = []

    static func record(
        metric: String,
        value: String,
        color: Color,
        context: String = "ActionableInsightsView",
        tags: [String] = []
    ) {
        let colorName: String
        switch color {
        case .blue: colorName = "blue"
        case .green: colorName = "green"
        case .red: colorName = "red"
        case .yellow: colorName = "yellow"
        default: colorName = color.description
        }

        let event = InsightAuditEvent(
            timestamp: Date(),
            metric: metric,
            value: value,
            color: colorName,
            context: context,
            tags: tags
        )

        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func resetLog() {
        log.removeAll()
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No actionable insight events recorded."
    }
}

// MARK: - Admin Summary Access

public enum InsightAuditAdmin {
    public static var lastSummary: String { InsightAudit.accessibilitySummary }
    public static var lastJSON: String? { InsightAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        InsightAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    public static func reset() {
        InsightAudit.resetLog()
    }
}

// MARK: - Preview

#if DEBUG
struct ActionableInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        ActionableInsightsView(insights: [
            .init(title: "Upcoming Appointments", value: "5", icon: "calendar", color: .blue, tags: ["appointments"], description: nil, accessibilityLabel: "5 upcoming appointments"),
            .init(title: "Total Revenue", value: "$3,450", icon: "dollarsign.circle", color: .green, tags: ["revenue"], description: nil, accessibilityLabel: "Total revenue $3,450"),
            .init(title: "Inactive Customers", value: "3", icon: "person.fill.xmark", color: .red, tags: ["inactive"], description: "Consider sending a re-engagement offer", accessibilityLabel: "3 inactive customers"),
            .init(title: "Loyalty Progress", value: "65%", icon: "star.circle.fill", color: .yellow, tags: ["loyalty"], description: "65% progress toward next reward", accessibilityLabel: "Loyalty program progress 65 percent")
        ])
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
