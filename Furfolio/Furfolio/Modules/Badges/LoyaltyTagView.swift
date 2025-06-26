//
//  LoyaltyTagView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Loyalty Badge View
//

import SwiftUI

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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No loyalty tag audit events recorded."
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
