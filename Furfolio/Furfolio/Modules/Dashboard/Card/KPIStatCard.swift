//
//  KPIStatCard.swift
//  Furfolio
//
//  ENHANCED: Audit Logging, Accessibility Identifiers, Modular Styling, CSV Export, Analytics, VoiceOver Announcement, and DEV Overlay.
//

import SwiftUI
import Combine

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

    // Records an audit event and keeps log size capped at 30 entries
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

    // Exports the last audit event as a JSON string
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // Accessibility summary for the last event
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No KPIStatCard events recorded."
    }
    
    // MARK: - ENHANCEMENTS
    
    /// Export all audit events as CSV string with headers:
    /// timestamp,title,value,subtitle,iconName,iconColor,tags
    static func exportCSV() -> String {
        let header = "timestamp,title,value,subtitle,iconName,iconColor,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            // Escape quotes and commas in text fields
            func escape(_ str: String?) -> String {
                guard let str = str else { return "" }
                if str.contains(",") || str.contains("\"") || str.contains("\n") {
                    let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return str
            }
            let subtitleEscaped = escape(event.subtitle)
            let tagsJoined = event.tags.joined(separator: ";")
            return [
                timestampStr,
                escape(event.title),
                escape(event.value),
                subtitleEscaped,
                escape(event.iconName),
                escape(event.iconColor),
                escape(tagsJoined)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Returns the card title with the highest frequency in the audit log
    static var mostFrequentTitle: String? {
        let freq = Dictionary(grouping: log, by: { $0.title }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of audit events recorded
    static var totalCardsShown: Int {
        log.count
    }
}

// MARK: - KPIStatCard

struct KPIStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemIconName: String
    let iconBackgroundColor: Color
    
    // Publisher for VoiceOver announcements
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    @State private var announcement: String = ""
    
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
            // VoiceOver announcement on appear
            if voiceOverEnabled {
                let announcement = "\(title) stat card shown. Value: \(value)."
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
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
    
    // Expose CSV export for audit log
    public static func exportCSV() -> String {
        KPIStatCardAudit.exportCSV()
    }
    
    // Expose analytics: most frequent card title and total cards shown
    public static var mostFrequentTitle: String? {
        KPIStatCardAudit.mostFrequentTitle
    }
    public static var totalCardsShown: Int {
        KPIStatCardAudit.totalCardsShown
    }
}

#if DEBUG
// MARK: - DEV Overlay View for Audit Info

private struct KPIStatCardAuditOverlay: View {
    @State private var auditLog: [KPIStatCardAuditEvent] = []
    @State private var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("KPIStatCard Audit Overlay")
                .font(.caption)
                .bold()
                .foregroundColor(.white)
            Divider().background(Color.white)
            Text("Last 3 Events:")
                .font(.caption2)
                .foregroundColor(.white)
            ForEach(auditLog.suffix(3).reversed(), id: \.timestamp) { event in
                Text("- \(event.title): \(event.value) \(event.subtitle ?? "")")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Divider().background(Color.white)
            Text("Most Frequent Title: \(KPIStatCardAudit.mostFrequentTitle ?? "N/A")")
                .font(.caption2)
                .foregroundColor(.white)
            Text("Total Cards Shown: \(KPIStatCardAudit.totalCardsShown)")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .padding()
        .onReceive(timer) { _ in
            auditLog = KPIStatCardAudit.log
        }
    }
}

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
        // DEV Overlay added on preview for debug builds
        .overlay(KPIStatCardAuditOverlay(), alignment: .bottom)
    }
}
#endif
