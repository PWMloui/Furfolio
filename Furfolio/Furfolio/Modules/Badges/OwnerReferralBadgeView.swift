//
// MARK: - OwnerReferralBadgeView (Tokenized, Modular, Auditable Referral Badge UI)
//
//  OwnerReferralBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Referral Badge UI
//

import SwiftUI
import Combine
import AVFoundation

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

    /// Records an audit event with details about the referral badge operation.
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

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No referral badge events recorded."
    }

    // MARK: - Enhancement: CSV Export

    /// Exports all audit events as CSV string with headers:
    /// timestamp,operation,referralCount,lastReferralDate,tags,actor,context,detail
    static func exportCSV() -> String {
        var csvLines = ["timestamp,operation,referralCount,lastReferralDate,tags,actor,context,detail"]
        let formatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = formatter.string(from: event.timestamp)
            let operation = event.operation
            let referralCount = String(event.referralCount)
            let lastReferralDate = event.lastReferralDate.map { formatter.string(from: $0) } ?? ""
            let tags = event.tags.joined(separator: "|")
            let actor = event.actor ?? ""
            let context = event.context ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            // Escape detail field with quotes if contains comma or line breaks
            let detailEscaped = (detail.contains(",") || detail.contains("\n")) ? "\"\(detail)\"" : detail
            let line = [timestamp, operation, referralCount, lastReferralDate, tags, actor, context, detailEscaped].joined(separator: ",")
            csvLines.append(line)
        }
        return csvLines.joined(separator: "\n")
    }

    // MARK: - Enhancement: Badge Analytics

    /// The most frequent referral count shown in audit events, or nil if no events.
    static var mostFrequentReferralCount: Int? {
        let counts = log.map { $0.referralCount }
        guard !counts.isEmpty else { return nil }
        let frequency = counts.reduce(into: [:]) { countsDict, count in
            countsDict[count, default: 0] += 1
        }
        return frequency.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of "appear" events recorded.
    static var totalBadgeShows: Int {
        log.filter { $0.operation == "appear" }.count
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
            // Enhancement: Post VoiceOver announcement on appear
            let announcement = "Referral badge for \(referralCount) client\(referralCount == 1 ? "" : "s") displayed."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        #if DEBUG
        .overlay(
            // Enhancement: DEV overlay showing last 3 badge events and most frequent referral count
            OwnerReferralBadgeAuditDebugOverlay()
                .padding(.top, 8),
            alignment: .bottom
        )
        #endif
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

    /// Enhancement: Expose CSV export of audit log.
    public static func exportCSV() -> String {
        OwnerReferralBadgeAudit.exportCSV()
    }

    /// Enhancement: Expose most frequent referral count shown.
    public static var mostFrequentReferralCount: Int? {
        OwnerReferralBadgeAudit.mostFrequentReferralCount
    }

    /// Enhancement: Expose total number of badge shows.
    public static var totalBadgeShows: Int {
        OwnerReferralBadgeAudit.totalBadgeShows
    }
}

// MARK: - DEV Overlay View for Debugging (Shows last 3 events and analytics)

#if DEBUG
private struct OwnerReferralBadgeAuditDebugOverlay: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Badge Analytics")
                        .font(.caption2)
                        .bold()
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .padding(6)
                .background(Color.black.opacity(0.15))
                .clipShape(Capsule())
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Frequent Referral Count: \(OwnerReferralBadgeAudit.mostFrequentReferralCount.map(String.init) ?? "N/A")")
                        .font(.caption2)
                    Text("Total Badge Shows: \(OwnerReferralBadgeAudit.totalBadgeShows)")
                        .font(.caption2)
                    Divider()
                    Text("Last 3 Badge Events:")
                        .font(.caption2).bold()
                    ForEach(Array(OwnerReferralBadgeAudit.log.suffix(3).reversed().enumerated()), id: \.offset) { index, event in
                        Text("• \(event.accessibilityLabel)")
                            .font(.caption2)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(8)
        .frame(maxWidth: 320)
        .foregroundColor(.primary)
    }
}
#endif

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
