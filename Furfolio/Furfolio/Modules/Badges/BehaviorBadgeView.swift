//
//  BehaviorBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Behavior Badge Display
//

import SwiftUI
import AVFoundation // For VoiceOver announcement

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
    
    // MARK: - ENHANCEMENT: CSV export of all logged events
    static func exportCSV() -> String {
        let header = "timestamp,operation,badgeType,badgeLabel,tags,actor,context,detail"
        let rows = log.map { event in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|")
            let actorStr = event.actor ?? ""
            let contextStr = event.context ?? ""
            let detailStr = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            // Escape detail with quotes if contains comma or quotes
            let escapedDetail = detailStr.contains(",") || detailStr.contains("\"") ? "\"\(detailStr)\"" : detailStr
            return "\(timestampStr),\(event.operation),\(event.badgeType),\(event.badgeLabel),\(tagsStr),\(actorStr),\(contextStr),\(escapedDetail)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    // MARK: - ENHANCEMENT: Badge analytics
    
    /// Most frequent badgeType in the log (by count)
    static var mostFrequentBadgeType: String? {
        let counts = Dictionary(grouping: log, by: { $0.badgeType })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of badge taps recorded
    static var totalBadgeTaps: Int {
        log.filter { $0.operation == "tap" }.count
    }
}

// MARK: - BehaviorBadgeView (Auditable, Tokenized, Modular)

struct BehaviorBadgeView: View {
    let badges: [Badge]
    var showLabels: Bool = false // Show icon only, or icon + label
    
    // MARK: - ENHANCEMENT: DEV badge summary overlay (bottom)
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

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
        #if DEBUG
        // DEV-only overlay view at bottom showing last 3 badge events and most tapped badge
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Text("DEV Badge Audit Summary")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(BehaviorBadgeAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                if let mostFrequent = BehaviorBadgeAudit.mostFrequentBadgeType {
                    Text("Most Frequent Badge: \(mostFrequent)")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                Text("Total Badge Taps: \(BehaviorBadgeAudit.totalBadgeTaps)")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8),
            alignment: .bottom
        )
        #endif
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
                    // MARK: - ENHANCEMENT: VoiceOver announcement on popover open
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIAccessibility.post(notification: .announcement, argument: "Info for \(badge.type.label) opened.")
                    }
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
    
    // MARK: - ENHANCEMENT: Expose CSV export
    public static func exportCSV() -> String {
        BehaviorBadgeAudit.exportCSV()
    }
    
    // MARK: - ENHANCEMENT: Expose analytics
    public static var mostFrequentBadgeType: String? {
        BehaviorBadgeAudit.mostFrequentBadgeType
    }
    public static var totalBadgeTaps: Int {
        BehaviorBadgeAudit.totalBadgeTaps
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
