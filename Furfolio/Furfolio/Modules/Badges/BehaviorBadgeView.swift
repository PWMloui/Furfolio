//
//  BehaviorBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Behavior Badge Display
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct BehaviorBadgeAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "appear", "tap", "popoverOpen", "popoverClose"
    let badgeType: String
    let badgeLabel: String
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(badgeType) (\(badgeLabel)) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class BehaviorBadgeAudit {
    static private(set) var log: [BehaviorBadgeAuditEvent] = []

    static func record(
        operation: String,
        badge: Badge,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "BehaviorBadgeView",
        detail: String? = nil
    ) {
        let event = BehaviorBadgeAuditEvent(
            timestamp: Date(),
            operation: operation,
            badgeType: badge.type.rawValue,
            badgeLabel: badge.type.label,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
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
        log.last?.accessibilityLabel ?? "No badge events recorded."
    }
}

// MARK: - BehaviorBadgeView (Auditable, Tokenized, Modular)

struct BehaviorBadgeView: View {
    let badges: [Badge]
    var showLabels: Bool = false // Show icon only, or icon + label

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(badges) { badge in
                    BadgeItemView(badge: badge, showLabel: showLabels)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Behavior and status badges")
        }
        .onAppear {
            for badge in badges {
                BehaviorBadgeAudit.record(
                    operation: "appear",
                    badge: badge,
                    tags: ["appear"]
                )
            }
        }
    }
}

private struct BadgeItemView: View {
    let badge: Badge
    let showLabel: Bool

    @State private var showInfo: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Button(action: {
                withAnimation { showInfo.toggle() }
                BehaviorBadgeAudit.record(
                    operation: "tap",
                    badge: badge,
                    tags: [showInfo ? "popoverOpen" : "popoverClose", badge.type.rawValue]
                )
            }) {
                Text(badge.type.icon)
                    .font(AppFonts.iconLarge)
                    .accessibilityLabel(badge.type.label)
                    .accessibilityHint(badge.type.description)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("badge-\(badge.type.label)")
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(AppColors.backgroundSecondary)
                            .shadow(color: showInfo ? AppColors.primary.opacity(0.25) : .clear, radius: 4)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                VStack(spacing: 10) {
                    Text(badge.type.icon)
                        .font(AppFonts.title1)
                    Text(badge.type.label)
                        .font(AppFonts.headline)
                    Text(badge.type.description)
                        .font(AppFonts.subheadline)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(width: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.background)
                        .shadow(radius: 5)
                )
                .onAppear {
                    BehaviorBadgeAudit.record(
                        operation: "popoverOpen",
                        badge: badge,
                        tags: ["popoverOpen", badge.type.rawValue]
                    )
                }
                .onDisappear {
                    BehaviorBadgeAudit.record(
                        operation: "popoverClose",
                        badge: badge,
                        tags: ["popoverClose", badge.type.rawValue]
                    )
                }
            }

            if showLabel {
                Text(badge.type.label)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum BehaviorBadgeAuditAdmin {
    public static var lastSummary: String { BehaviorBadgeAudit.accessibilitySummary }
    public static var lastJSON: String? { BehaviorBadgeAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        BehaviorBadgeAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#Preview {
    BehaviorBadgeView(
        badges: [
            Badge(type: .behaviorGood),
            Badge(type: .behaviorChallenging),
            Badge(type: .birthday),
            Badge(type: .retentionRisk),
            Badge(type: .topSpender)
        ],
        showLabels: true
    )
    .padding()
    .background(AppColors.backgroundSecondary)
}
