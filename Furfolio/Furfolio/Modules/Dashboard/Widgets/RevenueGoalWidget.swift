
//  RevenueGoalWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Revenue Goal Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct RevenueGoalAuditEvent: Codable {
    let timestamp: Date
    let goal: Double
    let actual: Double
    let percent: Double
    let status: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let percentStr = String(format: "%.1f", percent * 100)
        return "[Appear] RevenueGoalWidget: goal \(goal), actual \(actual), \(percentStr)%% (\(status)) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class RevenueGoalAudit {
    static private(set) var log: [RevenueGoalAuditEvent] = []

    static func record(
        goal: Double,
        actual: Double,
        percent: Double,
        status: String,
        tags: [String] = ["revenueGoalWidget"]
    ) {
        let event = RevenueGoalAuditEvent(
            timestamp: Date(),
            goal: goal,
            actual: actual,
            percent: percent,
            status: status,
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
        log.last?.accessibilityLabel ?? "No revenue goal widget events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - RevenueGoalWidget

public struct RevenueGoalWidget: View {
    public let goal: Double
    public let actual: Double
    public let period: String

    private var percent: Double {
        goal > 0 ? min(actual / goal, 1.0) : 0
    }
    private var status: String {
        percent >= 1.0 ? "achieved" : (percent >= 0.9 ? "almost" : "in progress")
    }
    private var color: Color {
        percent >= 1.0 ? .green : (percent >= 0.9 ? .yellow : .accentColor)
    }
    private var currency: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencySymbol = "$"
        return f
    }

    public init(goal: Double, actual: Double, period: String) {
        self.goal = goal
        self.actual = actual
        self.period = period
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Revenue Goal (\(period))")
                    .font(.headline)
                    .accessibilityIdentifier("RevenueGoalWidget-Title")
            }
            .padding(.bottom, 2)

            ProgressView(value: percent)
                .accentColor(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(height: 16)
                .accessibilityLabel("Revenue progress bar")
                .accessibilityIdentifier("RevenueGoalWidget-ProgressBar")

            HStack {
                VStack(alignment: .leading) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency.string(from: NSNumber(value: goal)) ?? "$0")
                        .font(.headline)
                        .accessibilityIdentifier("RevenueGoalWidget-GoalValue")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency.string(from: NSNumber(value: actual)) ?? "$0")
                        .font(.headline)
                        .foregroundColor(color)
                        .accessibilityIdentifier("RevenueGoalWidget-ActualValue")
                }
            }
            .padding(.top, 4)

            HStack {
                Text(String(format: "%.0f%%", percent * 100))
                    .font(.title2.bold())
                    .foregroundColor(color)
                    .accessibilityIdentifier("RevenueGoalWidget-PercentLabel")
                Text(status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("RevenueGoalWidget-StatusLabel")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("RevenueGoalWidget-Container")
        .onAppear {
            RevenueGoalAudit.record(
                goal: goal,
                actual: actual,
                percent: percent,
                status: status
            )
        }
    }

    private var accessibilitySummary: String {
        let percentStr = String(format: "%.0f", percent * 100)
        return "Revenue goal progress for \(period). Goal \(currency.string(from: NSNumber(value: goal)) ?? "$0"), actual \(currency.string(from: NSNumber(value: actual)) ?? "$0"), \(percentStr) percent, status: \(status)"
    }
}

// MARK: - Audit/Admin Accessors

public enum RevenueGoalWidgetAuditAdmin {
    public static var lastSummary: String { RevenueGoalAudit.accessibilitySummary }
    public static var lastJSON: String? { RevenueGoalAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        RevenueGoalAudit.recentEvents(limit: limit)
    }
}

// MARK: - Preview

#if DEBUG
struct RevenueGoalWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RevenueGoalWidget(goal: 15000, actual: 13300, period: "June")
                .previewLayout(.sizeThatFits)
                .padding()
            RevenueGoalWidget(goal: 15000, actual: 15500, period: "June")
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
#endif
