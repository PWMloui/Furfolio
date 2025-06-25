//
//  AnimatedBadgeView.swift
//  Furfolio
//
//  This is the canonical badge/retention tag view. AnimatedRetentionTagView.swift is deprecated and should be deleted.
//  Enhanced: audit/analytics-ready, token-compliant, accessible, modular, and preview/test-injectable.
//

import SwiftUI

// MARK: - Audit/Analytics Logger Protocol

public protocol BadgeAnalyticsLogger {
    func log(event: String, badge: Badge)
}
public struct NullBadgeAnalyticsLogger: BadgeAnalyticsLogger {
    public init() {}
    public func log(event: String, badge: Badge) {}
}

// MARK: - BadgeType, Badge model (as before, not changed)

enum BadgeType: Equatable, Hashable {
    case loyalty
    case retention
    case milestone
    case risk
    case custom(String)
}

/// Model representing any business badge or tag in Furfolio.
/// Use this as the canonical badge/retention/milestone model throughout the app.
struct Badge: Identifiable, Equatable, Hashable {
    /// Unique identifier (autogenerates unless overridden for static/test data)
    var id: UUID = UUID()
    /// The type of badge (loyalty, retention, milestone, risk, or custom)
    var type: BadgeType
    /// Localized title (use NSLocalizedString or LocalizedStringKey at point of display)
    var title: String
    /// Localized description for accessibility/audit/tooltips
    var description: String
    /// Optional custom color (otherwise use type-based defaults in the view)
    var color: Color? = nil
    /// Optional emoji (shown in preference to SFSymbol)
    var emoji: String? = nil
    /// Optional SFSymbol name (fallback if no emoji)
    var systemImage: String? = nil
    /// Date when badge was awarded (for business logic/auditing)
    var awardedDate: Date? = nil
}

// MARK: - AnimatedBadgeView

struct AnimatedBadgeView: View {
    /// The badge model instance to display.
    var badge: Badge

    /// Analytics/audit logger (DI for preview/test/enterprise)
    var analyticsLogger: BadgeAnalyticsLogger = NullBadgeAnalyticsLogger()

    /// Optional callback called when animation completes (for analytics/audit).
    var onAnimationComplete: (() -> Void)? = nil

    @State private var animateIn: Bool = false
    @State private var pulseAnim: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Style Tokens (robust fallback, never use TODO)
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

    // MARK: - Computed properties for styling based on badge type

    private var badgeColor: Color {
        if let customColor = badge.color { return customColor }
        switch badge.type {
        case .loyalty:
            return AppColors.loyaltyYellow ?? .yellow
        case .retention:
            return AppColors.retentionOrange ?? .orange
        case .milestone:
            return AppColors.milestoneBlue ?? .blue
        case .risk:
            return AppColors.riskOrange ?? .orange
        case .custom:
            return AppColors.customPurple ?? .purple
        }
    }

    private var badgeEmoji: String? {
        if let customEmoji = badge.emoji { return customEmoji }
        switch badge.type {
        case .milestone: return "🏆"
        default: return nil
        }
    }

    private var badgeSystemImage: String? {
        if let customIcon = badge.systemImage { return customIcon }
        switch badge.type {
        case .loyalty: return "star.fill"
        case .retention: return "clock.fill"
        case .risk: return "exclamationmark.triangle.fill"
        default: return nil
        }
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
        .onAppear {
            withAnimation(.spring(response: Style.animationDuration, dampingFraction: 0.7)) {
                animateIn = true
            }
            if shouldPulse && !reduceMotion {
                withAnimation(.easeInOut(duration: Style.pulseDuration).repeatForever(autoreverses: true)) {
                    pulseAnim = true
                }
            }
            // Analytics hook after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + Style.animationDuration) {
                analyticsLogger.log(event: "badge_appeared", badge: badge)
                onAnimationComplete?()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct SpyLogger: BadgeAnalyticsLogger {
        func log(event: String, badge: Badge) {
            print("Analytics Event: \(event), Badge: \(badge.title)")
        }
    }
    return Group {
        AnimatedBadgeView(
            badge: Badge(type: .loyalty, title: "Loyalty", description: "Awarded for loyal customers"),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Loyalty - Light")

        AnimatedBadgeView(
            badge: Badge(type: .retention, title: "Retention", description: "Retention tag with special styling"),
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Retention - Dark")

        AnimatedBadgeView(
            badge: Badge(type: .milestone, title: "Milestone", description: "Achievement milestone", emoji: "🏆"),
            analyticsLogger: SpyLogger()
        )
        .environment(\.sizeCategory, .extraExtraExtraLarge)
        .previewDisplayName("Milestone - Large Text")

        AnimatedBadgeView(
            badge: Badge(type: .risk, title: "Risk", description: "Warning for potential risk"),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Risk - Light")

        AnimatedBadgeView(
            badge: Badge(type: .custom("special"), title: "Special", description: "Custom badge", color: .purple, emoji: "✨"),
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Custom - Light")
    }
}
