//
//  DashboardSummaryRow.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Summary Row
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DashboardSummaryRowAuditEvent: Codable {
    let timestamp: Date
    let iconName: String
    let iconColor: String
    let title: String
    let value: String
    let valueColor: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(title): \(value), icon: \(iconName), iconColor: \(iconColor), valueColor: \(valueColor) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DashboardSummaryRowAudit {
    static private(set) var log: [DashboardSummaryRowAuditEvent] = []

    static func record(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String,
        valueColor: Color,
        tags: [String] = ["summaryRow"]
    ) {
        let colorName: (Color) -> String = { color in
            switch color {
            case .blue: return "blue"
            case .green: return "green"
            case .orange: return "orange"
            case .red: return "red"
            case .primary: return "primary"
            default: return color.description
            }
        }
        let event = DashboardSummaryRowAuditEvent(
            timestamp: Date(),
            iconName: iconName,
            iconColor: colorName(iconColor),
            title: title,
            value: value,
            valueColor: colorName(valueColor),
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
        log.last?.accessibilityLabel ?? "No dashboard summary row events recorded."
    }
}

// MARK: - DashboardSummaryRow

struct DashboardSummaryRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(valueColor)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .onAppear {
            DashboardSummaryRowAudit.record(
                iconName: iconName,
                iconColor: iconColor,
                title: title,
                value: value,
                valueColor: valueColor
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardSummaryRowAuditAdmin {
    public static var lastSummary: String { DashboardSummaryRowAudit.accessibilitySummary }
    public static var lastJSON: String? { DashboardSummaryRowAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardSummaryRowAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct DashboardSummaryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardSummaryRow(
                iconName: "chart.bar.fill",
                iconColor: .blue,
                title: "Total Revenue",
                value: "$12,345",
                valueColor: .green
            )
            .previewLayout(.sizeThatFits)
            .padding()

            DashboardSummaryRow(
                iconName: "calendar",
                iconColor: .orange,
                title: "Upcoming Appointments",
                value: "5",
                valueColor: .primary
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif
