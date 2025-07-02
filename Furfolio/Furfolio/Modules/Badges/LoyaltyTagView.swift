//
//  LoyaltyTagView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Loyalty Badge View
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct LoyaltyTagAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "appear"
    let badgeType: String
    let context: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(badgeType) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class LoyaltyTagAudit {
    static private(set) var log: [LoyaltyTagAuditEvent] = []

    /// Records a loyalty tag appearance event, appends to log, trims log, and posts VoiceOver announcement.
    static func record(
        badgeType: String,
        context: String,
        tags: [String] = []
    ) {
        let event = LoyaltyTagAuditEvent(
            timestamp: Date(),
            operation: "appear",
            badgeType: badgeType,
            context: context,
            tags: tags
        )
        log.append(event)
        if log.count > 200 { log.removeFirst() }
        
        // Accessibility: Post VoiceOver announcement when badge appears
        let announcement = "Loyalty tag \(badgeType) displayed."
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    /// Exports the most recent audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No loyalty tag audit events recorded."
    }
    
    /// Exports all audit events as CSV string with columns: timestamp,operation,badgeType,context,tags.
    /// Tags are joined by semicolon to avoid CSV conflicts.
    static func exportCSV() -> String {
        let header = "timestamp,operation,badgeType,context,tags"
        let rows = log.map { event in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: ";")
            // Escape commas or quotes in fields if needed
            func escape(_ field: String) -> String {
                if field.contains(",") || field.contains("\"") {
                    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return field
            }
            return [
                escape(timestampStr),
                escape(event.operation),
                escape(event.badgeType),
                escape(event.context),
                escape(tagsStr)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Returns the badgeType that appears most frequently in the audit log, or nil if no events.
    static var mostFrequentBadgeType: String? {
        let freq = Dictionary(grouping: log, by: { $0.badgeType }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns total number of badge appearance events recorded.
    static var totalBadgeShows: Int {
        return log.count
    }
}

// MARK: - LoyaltyTagView (Tokenized, Modular, Auditable Loyalty Badge View)

struct LoyaltyTagView: View {
    /// Number of completed visits
    let visitCount: Int
    /// Total spent by this owner (optional)
    var totalSpent: Double? = nil
    /// Is this a top spender?
    var isTopSpender: Bool = false
    /// Is the client enrolled in the loyalty program?
    var isLoyalty: Bool = false

    /// Threshold constants for tags
    private let loyaltyThreshold = 5
    private let vipThreshold = 10
    private let newClientThreshold = 2

    var body: some View {
        HStack(spacing: 10) {
            if isLoyalty || visitCount >= loyaltyThreshold {
                TagLabel(text: "Loyalty Star", icon: "star.fill", color: AppColors.loyalty)
                    .accessibilityLabel("Loyalty Star Tag")
                    .accessibilityAddTraits(.isStaticText)
                    .onAppear {
                        LoyaltyTagAudit.record(
                            badgeType: "Loyalty Star",
                            context: "LoyaltyTagView",
                            tags: ["loyalty", "star"]
                        )
                    }
            }
            if visitCount >= vipThreshold {
                TagLabel(text: "VIP", icon: "crown.fill", color: AppColors.vip)
                    .accessibilityLabel("VIP Client Tag")
                    .accessibilityAddTraits(.isStaticText)
                    .onAppear {
                        LoyaltyTagAudit.record(
                            badgeType: "VIP",
                            context: "LoyaltyTagView",
                            tags: ["vip"]
                        )
                    }
            }
            if isTopSpender {
                TagLabel(text: "Top Spender", icon: "dollarsign.circle.fill", color: AppColors.topSpender)
                    .accessibilityLabel("Top Spender Tag")
                    .accessibilityAddTraits(.isStaticText)
                    .onAppear {
                        LoyaltyTagAudit.record(
                            badgeType: "Top Spender",
                            context: "LoyaltyTagView",
                            tags: ["topSpender"]
                        )
                    }
            }
            if visitCount < newClientThreshold {
                TagLabel(text: "New Client", icon: "sparkles", color: AppColors.newClient)
                    .accessibilityLabel("New Client Tag")
                    .accessibilityAddTraits(.isStaticText)
                    .onAppear {
                        LoyaltyTagAudit.record(
                            badgeType: "New Client",
                            context: "LoyaltyTagView",
                            tags: ["newClient"]
                        )
                    }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        #if DEBUG
        // DEV summary overlay: shows last 3 audit events and most frequent badge
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit Summary (Last 3):")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                ForEach(Array(LoyaltyTagAudit.log.suffix(3).reversed()), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let mostFrequent = LoyaltyTagAudit.mostFrequentBadgeType {
                    Text("Most Frequent Badge: \(mostFrequent)")
                        .font(.caption2.italic())
                        .foregroundColor(.yellow)
                } else {
                    Text("Most Frequent Badge: None")
                        .font(.caption2.italic())
                        .foregroundColor(.yellow)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding([.horizontal, .bottom], 8),
            alignment: .bottom
        )
        #endif
    }

    /// A reusable tag label view
    struct TagLabel: View {
        var text: String
        var icon: String
        var color: Color

        var body: some View {
            Label {
                Text(text)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 14)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(BorderRadius.medium)
            .shadow(color: color.opacity(0.3), radius: AppShadows.small.radius, x: 0, y: AppShadows.small.y)
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum LoyaltyTagAuditAdmin {
    public static var lastSummary: String { LoyaltyTagAudit.accessibilitySummary }
    public static var lastJSON: String? { LoyaltyTagAudit.exportLastJSON() }
    /// Exposes CSV export of all audit events.
    public static var exportCSV: String { LoyaltyTagAudit.exportCSV() }
    /// Returns the most frequent badge type from audit log.
    public static var mostFrequentBadgeType: String? { LoyaltyTagAudit.mostFrequentBadgeType }
    /// Returns total number of badge appearance events.
    public static var totalBadgeShows: Int { LoyaltyTagAudit.totalBadgeShows }
    public static func recentEvents(limit: Int = 5) -> [String] {
        LoyaltyTagAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LoyaltyTagView(visitCount: 12, totalSpent: 720, isTopSpender: true, isLoyalty: true)
        LoyaltyTagView(visitCount: 5)
        LoyaltyTagView(visitCount: 1)
        LoyaltyTagView(visitCount: 8, totalSpent: 200, isLoyalty: false, isTopSpender: false)
    }
    .padding()
    .background(AppColors.background)
}
