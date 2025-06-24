//
//  AnimatedBadgeView.swift
//  Furfolio

// This is the canonical badge/retention tag view. AnimatedRetentionTagView.swift is deprecated and should be deleted.

import SwiftUI

/// Defines the type of badge.
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

struct AnimatedBadgeView: View {
    
    /// The badge model instance to display.
    var badge: Badge
    
    /// Optional callback called when animation completes (for analytics/audit).
    var onAnimationComplete: (() -> Void)? = nil
    
    @State private var animateIn: Bool = false
    @State private var pulseAnim: Bool = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private enum Constants {
        static let baseScale: CGFloat = 0.8
        static let pulseScale: CGFloat = 1.08
        static let appearDuration: Double = 0.4
        static let pulseDuration: Double = 0.9
        
        // TODO: Replace hardcoded font sizes with AppFonts when available
        static let emojiFontSize: CGFloat = 17
        static let iconFontSize: CGFloat = 14
    }
    
    // MARK: - Computed properties for styling based on badge type
    
    private var badgeColor: Color {
        if let customColor = badge.color {
            return customColor
        }
        switch badge.type {
        case .loyalty:
            return AppColors.loyaltyYellow // TODO: define in AppColors
        case .retention:
            return AppColors.retentionOrange // TODO: define in AppColors
        case .milestone:
            return AppColors.milestoneBlue // TODO: define in AppColors
        case .risk:
            return AppColors.riskOrange // TODO: define in AppColors
        case .custom:
            return AppColors.customPurple // TODO: define in AppColors
        }
    }
    
    private var badgeEmoji: String? {
        if let customEmoji = badge.emoji {
            return customEmoji
        }
        switch badge.type {
        case .loyalty:
            return nil
        case .retention:
            return nil
        case .milestone:
            return "🏆"
        case .risk:
            return nil
        case .custom:
            return nil
        }
    }
    
    private var badgeSystemImage: String? {
        if let customIcon = badge.systemImage {
            return customIcon
        }
        switch badge.type {
        case .loyalty:
            return "star.fill"
        case .retention:
            return "clock.fill"
        case .milestone:
            return nil
        case .risk:
            return "exclamationmark.triangle.fill"
        case .custom:
            return nil
        }
    }
    
    private var shouldPulse: Bool {
        switch badge.type {
        case .loyalty, .risk:
            return true
        case .retention, .milestone, .custom:
            return false
        }
    }
    
    private var scaleFactor: CGFloat {
        guard animateIn else { return Constants.baseScale }
        return shouldPulse && pulseAnim && !reduceMotion ? Constants.pulseScale : 1.0
    }
    
    private var accessibilityLabel: Text {
        var components: [String] = []
        if let emoji = badgeEmoji {
            components.append(emoji)
        }
        if let icon = badgeSystemImage {
            components.append(icon)
        }
        components.append(badge.title)
        return Text(components.joined(separator: " "))
    }
    
    private var accessibilityHint: Text {
        Text(badge.description)
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            if let emoji = badgeEmoji {
                Text(emoji)
                    .font(.system(size: Constants.emojiFontSize))
                    .accessibilityHidden(true)
            }
            
            if let systemImage = badgeSystemImage {
                Image(systemName: systemImage)
                    .font(.system(size: Constants.iconFontSize, weight: .semibold))
                    .accessibilityHidden(true)
            }
            
            Text(badge.title)
                .font(AppFonts.caption) // TODO: Replace with actual AppFonts token
                .fontWeight(.semibold)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.xsmall)
        .background(badgeColor.opacity(animateIn ? 0.93 : 0.68))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .scaleEffect(scaleFactor)
        .shadow(color: badgeColor.opacity(0.24), radius: animateIn ? 4 : 1, x: 0, y: 1)
        .opacity(animateIn ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onAppear {
            withAnimation(.spring(response: Constants.appearDuration, dampingFraction: 0.7)) {
                animateIn = true
            }
            if shouldPulse && !reduceMotion {
                withAnimation(.easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true)) {
                    pulseAnim = true
                }
            }
            // Call analytics hook after appear animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.appearDuration) {
                onAnimationComplete?()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loyalty badge
            AnimatedBadgeView(badge: Badge(type: .loyalty, title: "Loyalty", description: "Awarded for loyal customers"))
                .previewDisplayName("Loyalty - Light")
            
            // Retention badge
            AnimatedBadgeView(badge: Badge(type: .retention, title: "Retention", description: "Retention tag with special styling"))
                .preferredColorScheme(.dark)
                .previewDisplayName("Retention - Dark")
            
            // Milestone badge
            AnimatedBadgeView(badge: Badge(type: .milestone, title: "Milestone", description: "Achievement milestone", emoji: "🏆"))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .previewDisplayName("Milestone - Large Text")
            
            // Risk badge
            AnimatedBadgeView(badge: Badge(type: .risk, title: "Risk", description: "Warning for potential risk"))
                .previewDisplayName("Risk - Light")
            
            // Custom badge
            AnimatedBadgeView(badge: Badge(type: .custom("special"), title: "Special", description: "Custom badge", color: Color.purple, emoji: "✨"))
                .previewDisplayName("Custom - Light")
        }
        .padding()
        .background(Color(.systemBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
