//
//  AnimatedBadgeView.swift
//  Furfolio
//
//  Canonical badge/retention tag view. Enhanced: role/staff/context audit, escalation, analytics-ready, token-compliant, accessible, modular, and preview/test-injectable.
//

import SwiftUI

// MARK: - Audit/Analytics Logger Protocol (Role/Staff/Context/Escalation)

public protocol BadgeAnalyticsLogger {
    var testMode: Bool { get }
    func log(event: String, badge: Badge, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func fetchRecentEvents(count: Int) async -> [BadgeAuditEvent]
}

public struct BadgeAuditEvent: Hashable {
    public let event: String
    public let badge: Badge
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let date: Date
}

// Default loggers
public struct NullBadgeAnalyticsLogger: BadgeAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, badge: Badge, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [BadgeAuditEvent] { [] }
}

public final class InMemoryBadgeAnalyticsLogger: BadgeAnalyticsLogger {
    public let testMode: Bool
    private let maxEventsStored: Int
    private var events: [BadgeAuditEvent] = []
    private let queue = DispatchQueue(label: "InMemoryBadgeAnalyticsLogger.queue", attributes: .concurrent)
    public init(testMode: Bool = false, maxEvents: Int = 20) {
        self.testMode = testMode
        self.maxEventsStored = maxEvents
    }
    public func log(event: String, badge: Badge, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let auditEvent = BadgeAuditEvent(event: event, badge: badge, role: role, staffID: staffID, context: context, escalate: escalate, date: Date())
        queue.async(flags: .barrier) {
            if self.events.count >= self.maxEventsStored {
                self.events.removeFirst()
            }
            self.events.append(auditEvent)
        }
        if testMode {
            print("[BadgeAnalytics] \(event): \(badge.title) [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
    }
    public func fetchRecentEvents(count: Int) async -> [BadgeAuditEvent] {
        await withCheckedContinuation { continuation in
            queue.async {
                let recent = self.events.suffix(count)
                continuation.resume(returning: Array(recent))
            }
        }
    }
}

// MARK: - Audit Context (set at login/session)

public struct BadgeAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedBadgeView"
}

// MARK: - BadgeType & Badge Model

enum BadgeType: Equatable, Hashable {
    case loyalty
    case retention
    case milestone
    case risk
    case custom(String)
}

struct Badge: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var type: BadgeType
    var title: String
    var description: String
    var color: Color? = nil
    var emoji: String? = nil
    var systemImage: String? = nil
    var awardedDate: Date? = nil
}

// MARK: - AnimatedBadgeView

struct AnimatedBadgeView: View {
    var badge: Badge
    var analyticsLogger: BadgeAnalyticsLogger = NullBadgeAnalyticsLogger()
    var onAnimationComplete: (() -> Void)? = nil

    @State private var animateIn: Bool = false
    @State private var pulseAnim: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Style Tokens
    private enum Style {
        static let horizontalPad: CGFloat = AppSpacing.medium ?? 14
        static let verticalPad: CGFloat = AppSpacing.xsmall ?? 7
        static let cornerRadius: CGFloat = AppRadius.medium ?? 16
        static let shadowRadius: CGFloat = 4
        static let font: Font = AppFonts.caption ?? .caption
        static let emojiFont: Font = AppFonts.title3 ?? .system(size: 19)
        static let iconFont: Font = AppFonts.body ?? .system(size: 15, weight: .semibold)
        static let spacing: CGFloat = AppSpacing.small ?? 7
        static let animationDuration: Double = 0.4
        static let pulseDuration: Double = 0.92
        static let baseScale: CGFloat = 0.80
        static let pulseScale: CGFloat = 1.12
    }

    private var badgeColor: Color {
        if let customColor = badge.color { return customColor }
        switch badge.type {
        case .loyalty: return AppColors.loyaltyYellow ?? .yellow
        case .retention: return AppColors.retentionOrange ?? .orange
        case .milestone: return AppColors.milestoneBlue ?? .blue
        case .risk: return AppColors.riskOrange ?? .orange
        case .custom: return AppColors.customPurple ?? .purple
        }
    }
    private var badgeEmoji: String? {
        badge.emoji ?? (badge.type == .milestone ? "🏆" : nil)
    }
    private var badgeSystemImage: String? {
        badge.systemImage ?? {
            switch badge.type {
            case .loyalty: return "star.fill"
            case .retention: return "clock.fill"
            case .risk: return "exclamationmark.triangle.fill"
            default: return nil
            }
        }()
    }
    private var shouldPulse: Bool {
        switch badge.type {
        case .loyalty, .risk: return true
        default: return false
        }
    }
    private var scaleFactor: CGFloat {
        guard animateIn else { return Style.baseScale }
        return shouldPulse && pulseAnim && !reduceMotion ? Style.pulseScale : 1.0
    }
    private var accessibilityLabel: Text {
        var components: [String] = []
        if let emoji = badgeEmoji { components.append(emoji) }
        if let icon = badgeSystemImage { components.append(icon) }
        components.append(badge.title)
        return Text(components.joined(separator: " "))
    }
    private var accessibilityHint: Text { Text(badge.description) }

    var body: some View {
        HStack(spacing: Style.spacing) {
            if let emoji = badgeEmoji {
                Text(emoji)
                    .font(Style.emojiFont)
                    .accessibilityHidden(true)
            }
            if let systemImage = badgeSystemImage {
                Image(systemName: systemImage)
                    .font(Style.iconFont)
                    .accessibilityHidden(true)
            }
            Text(badge.title)
                .font(Style.font)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding(.horizontal, Style.horizontalPad)
        .padding(.vertical, Style.verticalPad)
        .background(badgeColor.opacity(animateIn ? 0.93 : 0.68))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .scaleEffect(scaleFactor)
        .shadow(color: badgeColor.opacity(0.24), radius: animateIn ? Style.shadowRadius : 1, x: 0, y: 1)
        .opacity(animateIn ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .task {
            // Animate in with spring
            withAnimation(.spring(response: Style.animationDuration, dampingFraction: 0.7)) {
                animateIn = true
            }
            // Pulse if required and motion allowed
            if shouldPulse && !reduceMotion {
                withAnimation(.easeInOut(duration: Style.pulseDuration).repeatForever(autoreverses: true)) {
                    pulseAnim = true
                }
            }
            await logBadgeAppeared()
        }
    }

    // MARK: - Audit/Analytics Logging

    private func logBadgeAppeared() async {
        let eventName = NSLocalizedString("badge_appeared", comment: "Analytics event when a badge appears")
        let role = BadgeAuditContext.role
        let staffID = BadgeAuditContext.staffID
        let context = BadgeAuditContext.context
        let escalate = badge.type == .risk // Example: escalate all risk-type badges
        await analyticsLogger.log(event: eventName, badge: badge, role: role, staffID: staffID, context: context, escalate: escalate)
        onAnimationComplete?()
    }

    // MARK: - Public Diagnostics API

    static func fetchRecentAuditEvents(from logger: BadgeAnalyticsLogger, count: Int = 20) async -> [BadgeAuditEvent] {
        await logger.fetchRecentEvents(count: count)
    }
}

// MARK: - Preview

#Preview {
    struct SpyLogger: BadgeAnalyticsLogger {
        let testMode: Bool = true
        private static var calls: [BadgeAuditEvent] = []
        func log(event: String, badge: Badge, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let entry = BadgeAuditEvent(event: event, badge: badge, role: role, staffID: staffID, context: context, escalate: escalate, date: Date())
            SpyLogger.calls.append(entry)
            print("[BadgeAnalytics] \(event): \(badge.title) [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
        func fetchRecentEvents(count: Int) async -> [BadgeAuditEvent] {
            Array(Self.calls.suffix(count))
        }
    }
    BadgeAuditContext.role = "Owner"
    BadgeAuditContext.staffID = "staff001"
    BadgeAuditContext.context = "AnimatedBadgePreview"
    return Group {
        AnimatedBadgeView(
            badge: Badge(type: .loyalty, title: NSLocalizedString("Loyalty", comment: "Badge title for loyalty"), description: NSLocalizedString("Awarded for loyal customers", comment: "Badge description for loyalty")),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Loyalty - Light")

        AnimatedBadgeView(
            badge: Badge(type: .retention, title: NSLocalizedString("Retention", comment: "Badge title for retention"), description: NSLocalizedString("Retention tag with special styling", comment: "Badge description for retention")),
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Retention - Dark")

        AnimatedBadgeView(
            badge: Badge(type: .milestone, title: NSLocalizedString("Milestone", comment: "Badge title for milestone"), description: NSLocalizedString("Achievement milestone", comment: "Badge description for milestone"), emoji: "🏆"),
            analyticsLogger: SpyLogger()
        )
        .environment(\.sizeCategory, .extraExtraExtraLarge)
        .previewDisplayName("Milestone - Large Text")

        AnimatedBadgeView(
            badge: Badge(type: .risk, title: NSLocalizedString("Risk", comment: "Badge title for risk"), description: NSLocalizedString("Warning for potential risk", comment: "Badge description for risk")),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Risk - Light")

        AnimatedBadgeView(
            badge: Badge(type: .custom("special"), title: NSLocalizedString("Special", comment: "Badge title for custom special badge"), description: NSLocalizedString("Custom badge", comment: "Badge description for custom badge"), color: .purple, emoji: "✨"),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Custom - Light")
    }
}
