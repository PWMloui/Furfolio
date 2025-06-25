//
//  KPIStatCard.swift
//  Furfolio
//
//  ENHANCED: Audit Logging, Accessibility Identifiers, and Modular Styling.
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct KPIStatCardAuditEvent: Codable {
    let timestamp: Date
    let title: String
    let value: String
    let subtitle: String?
    let iconName: String
    let iconColor: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[Appear] \(title): \(value)"
        if let subtitle { base += ", \(subtitle)" }
        base += ", icon: \(iconName), color: \(iconColor)"
        if !tags.isEmpty { base += " [\(tags.joined(separator: ","))]" }
        base += " at \(dateStr)"
        return base
    }
}

fileprivate final class KPIStatCardAudit {
    static private(set) var log: [KPIStatCardAuditEvent] = []

    static func record(
        title: String,
        value: String,
        subtitle: String?,
        iconName: String,
        iconColor: Color,
        tags: [String] = ["KPIStatCard"]
    ) {
        let colorDesc: String
        switch iconColor {
        case .green: colorDesc = "green"
        case .blue: colorDesc = "blue"
        case .red: colorDesc = "red"
        case .orange: colorDesc = "orange"
        default: colorDesc = iconColor.description
        }
        let event = KPIStatCardAuditEvent(
            timestamp: Date(),
            title: title,
            value: value,
            subtitle: subtitle,
            iconName: iconName,
            iconColor: colorDesc,
            tags: tags
        )
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No KPIStatCard events recorded."
    }
}

// MARK: - KPIStatCard

struct KPIStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemIconName: String
    let iconBackgroundColor: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("KPIStatCard-IconBG-\(title)")

                Image(systemName: systemIconName)
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("KPIStatCard-Icon-\(title)")
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .accessibilityIdentifier("KPIStatCard-Title-\(title)")

                Text(value)
                    .font(AppTheme.Fonts.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .accessibilityIdentifier("KPIStatCard-Value-\(title)")

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .accessibilityIdentifier("KPIStatCard-Subtitle-\(title)")
                }
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.card)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.card)
                .appShadow(AppTheme.Shadows.card)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), value \(value)\(subtitle != nil ? ", \(subtitle!)" : "")")
        .accessibilityIdentifier("KPIStatCard-Container-\(title)")
        .onAppear {
            KPIStatCardAudit.record(
                title: title,
                value: value,
                subtitle: subtitle,
                iconName: systemIconName,
                iconColor: iconBackgroundColor
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum KPIStatCardAuditAdmin {
    public static var lastSummary: String { KPIStatCardAudit.accessibilitySummary }
    public static var lastJSON: String? { KPIStatCardAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        KPIStatCardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct KPIStatCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            KPIStatCard(
                title: "Total Revenue",
                value: "$12,345",
                subtitle: "This month",
                systemIconName: "dollarsign.circle.fill",
                iconBackgroundColor: .green
            )
            KPIStatCard(
                title: "Upcoming Appointments",
                value: "5",
                subtitle: "Next 7 days",
                systemIconName: "calendar",
                iconBackgroundColor: .blue
            )
            KPIStatCard(
                title: "Inactive Customers",
                value: "3",
                subtitle: nil,
                systemIconName: "person.fill.xmark",
                iconBackgroundColor: .red
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
