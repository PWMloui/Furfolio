//
//  ActionableInsightsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Actionable Insights View
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct InsightAuditEvent: Codable {
    let timestamp: Date
    let metric: String
    let value: String
    let color: String
    let context: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(metric): \(value), color: \(color) [\(tags.joined(separator: ","))] at \(dateStr)"
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
        if log.count > 40 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No actionable insight events recorded."
    }
}

// MARK: - ActionableInsightsView

struct ActionableInsightsView: View {
    let upcomingAppointments: Int = 5
    let totalRevenue: Double = 3450.75
    let inactiveCustomers: Int = 3
    let loyaltyProgress: Double = 0.65

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actionable Insights")
                .font(.title2.bold())
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 16) {
                InsightCard(
                    title: "Upcoming Appointments",
                    value: "\(upcomingAppointments)",
                    systemImage: "calendar",
                    color: .blue,
                    accessibilityLabel: "\(upcomingAppointments) upcoming appointments"
                )

                InsightCard(
                    title: "Total Revenue",
                    value: currencyFormatter.string(from: NSNumber(value: totalRevenue)) ?? "$0",
                    systemImage: "dollarsign.circle",
                    color: .green,
                    accessibilityLabel: "Total revenue \(currencyFormatter.string(from: NSNumber(value: totalRevenue)) ?? "$0")"
                )
            }

            HStack(spacing: 16) {
                InsightCard(
                    title: "Inactive Customers",
                    value: "\(inactiveCustomers)",
                    systemImage: "person.fill.xmark",
                    color: .red,
                    accessibilityLabel: "\(inactiveCustomers) inactive customers"
                )

                LoyaltyProgressCard(progress: loyaltyProgress)
            }
        }
        .padding()
        .onAppear {
            InsightAudit.record(
                metric: "Upcoming Appointments",
                value: "\(upcomingAppointments)",
                color: .blue,
                tags: ["appointments"]
            )
            InsightAudit.record(
                metric: "Total Revenue",
                value: currencyFormatter.string(from: NSNumber(value: totalRevenue)) ?? "$0",
                color: .green,
                tags: ["revenue"]
            )
            InsightAudit.record(
                metric: "Inactive Customers",
                value: "\(inactiveCustomers)",
                color: .red,
                tags: ["inactive"]
            )
            InsightAudit.record(
                metric: "Loyalty Progress",
                value: "\(Int(loyaltyProgress * 100))%",
                color: .yellow,
                tags: ["loyalty"]
            )
        }
    }
}

// MARK: - InsightCard

private struct InsightCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            InsightAudit.record(
                metric: title,
                value: value,
                color: color,
                tags: ["card", title]
            )
        }
    }
}

// MARK: - LoyaltyProgressCard

private struct LoyaltyProgressCard: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.yellow)
            Text("\(Int(progress * 100))%")
                .font(.title)
                .bold()
                .foregroundColor(.yellow)
            Text("Loyalty Progress")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.yellow.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement()
        .accessibilityLabel("Loyalty program progress \(Int(progress * 100)) percent")
        .onAppear {
            InsightAudit.record(
                metric: "Loyalty Progress",
                value: "\(Int(progress * 100))%",
                color: .yellow,
                tags: ["card", "loyalty"]
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum InsightAuditAdmin {
    public static var lastSummary: String { InsightAudit.accessibilitySummary }
    public static var lastJSON: String? { InsightAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        InsightAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct ActionableInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        ActionableInsightsView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
