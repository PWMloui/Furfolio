//
// MARK: - OwnerReferralBadgeView (Tokenized, Modular, Auditable Referral Badge UI)
//
//  OwnerReferralBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Referral Badge UI
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct OwnerReferralBadgeAuditEvent: Codable {
    let timestamp: Date
    let operation: String           // "appear"
    let referralCount: Int
    let lastReferralDate: Date?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        var label = "[\(operation.capitalized)] \(referralCount) referrals"
        if let date = lastReferralDate {
            label += ", last on \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))"
        }
        if referralCount >= 5 { label += " [Referral Star]" }
        if !tags.isEmpty { label += " [\(tags.joined(separator: ","))]" }
        label += " at \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short))"
        if let detail { label += ": \(detail)" }
        return label
    }
}

fileprivate final class OwnerReferralBadgeAudit {
    static private(set) var log: [OwnerReferralBadgeAuditEvent] = []

    static func record(
        operation: String,
        referralCount: Int,
        lastReferralDate: Date?,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "OwnerReferralBadgeView",
        detail: String? = nil
    ) {
        let event = OwnerReferralBadgeAuditEvent(
            timestamp: Date(),
            operation: operation,
            referralCount: referralCount,
            lastReferralDate: lastReferralDate,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 120 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No referral badge events recorded."
    }
}

// MARK: - OwnerReferralBadgeView

struct OwnerReferralBadgeView: View {
    let referralCount: Int
    let lastReferralDate: Date?

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            referralIcon
            referralDetails
            Spacer()
            referralStar
        }
        .padding(AppSpacing.medium)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.medium, style: .continuous))
        .shadow(color: AppShadows.light.color, radius: AppShadows.light.radius, x: AppShadows.light.x, y: AppShadows.light.y)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            OwnerReferralBadgeAudit.record(
                operation: "appear",
                referralCount: referralCount,
                lastReferralDate: lastReferralDate,
                tags: referralCount >= 5 ? ["star", "referral"] : referralCount == 0 ? ["noReferral"] : ["referral"]
            )
        }
    }

    private var referralIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: "person.3.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.accent)
        }
    }

    private var referralDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            if referralCount > 0 {
                Text("Referred \(referralCount) \(referralCount == 1 ? "client" : "clients")")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.accent)
                if let date = lastReferralDate {
                    Text("Last referral: \(date, style: .date)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            } else {
                Text("No referrals yet")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }

    private var referralStar: some View {
        Group {
            if referralCount >= 5 {
                Label("Referral Star", systemImage: "star.fill")
                    .font(AppFonts.caption2Bold)
                    .foregroundColor(AppColors.loyalty)
                    .padding(AppSpacing.small)
                    .background(AppColors.loyalty.opacity(0.13))
                    .clipShape(Capsule())
                    .accessibilityLabel("Referral star awarded")
            }
        }
    }

    private var accessibilityLabel: String {
        if referralCount == 0 {
            return "No referrals yet"
        } else {
            var label = "Referred \(referralCount) \(referralCount == 1 ? "client" : "clients")"
            if let date = lastReferralDate {
                label += ", last referral on \(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))"
            }
            if referralCount >= 5 {
                label += ". Referral star awarded."
            }
            return label
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum OwnerReferralBadgeAuditAdmin {
    public static var lastSummary: String { OwnerReferralBadgeAudit.accessibilitySummary }
    public static var lastJSON: String? { OwnerReferralBadgeAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        OwnerReferralBadgeAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppSpacing.medium) {
        OwnerReferralBadgeView(referralCount: 7, lastReferralDate: Date().addingTimeInterval(-86400 * 10))
        OwnerReferralBadgeView(referralCount: 2, lastReferralDate: Date().addingTimeInterval(-86400 * 45))
        OwnerReferralBadgeView(referralCount: 0, lastReferralDate: nil)
    }
    .padding()
    .background(AppColors.background)
}
