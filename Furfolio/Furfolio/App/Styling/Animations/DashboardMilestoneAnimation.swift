//
//  DashboardMilestoneAnimation.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, accessible, preview/testable, enterprise-grade.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol MilestoneAnalyticsLogger {
    func log(event: String, emoji: String, label: String, subtitle: String?)
}
public struct NullMilestoneAnalyticsLogger: MilestoneAnalyticsLogger {
    public init() {}
    public func log(event: String, emoji: String, label: String, subtitle: String?) {}
}

/// Animated badge for milestone celebration (revenue goals, appointment streaks, loyalty, etc).
struct DashboardMilestoneAnimation: View {
    @Binding var trigger: Bool
    var emoji: String = "🏆"
    var label: String = "Milestone!"
    var color: Color = AppColors.milestoneYellow ?? .yellow
    var subtitle: String? = nil
    var showConfetti: Bool = true
    var analyticsLogger: MilestoneAnalyticsLogger = NullMilestoneAnalyticsLogger()

    @State private var animate: Bool = false
    @State private var shine: Bool = false

    private enum Tokens {
        static let appearDelay: Double = 0.05
        static let shineStartDelay: Double = 0.38
        static let shineDuration: Double = 0.66
        static let hPad: CGFloat = AppSpacing.xLarge ?? 28
        static let vPad: CGFloat = AppSpacing.medium ?? 18
        static let badgeFont: Font = AppFonts.headlineBold ?? .headline.bold()
        static let subtitleFont: Font = AppFonts.subheadline ?? .subheadline
        static let emojiFont: Font = AppFonts.milestoneEmoji ?? .system(size: 38)
        static let badgeBgOpacity: Double = 0.11
        static let badgeShadowOpacity: Double = 0.19
        static let emojiShadowOpacity: Double = 0.21
        static let shadowRadiusActive: CGFloat = 16
        static let shadowRadiusInactive: CGFloat = 7
        static let capsuleRadius: CGFloat = AppRadius.large ?? 36
        static let spacing: CGFloat = AppSpacing.large ?? 12
        static let subtitleSpacing: CGFloat = 2
        static let scaleActive: CGFloat = 1.0
        static let scaleInactive: CGFloat = 0.8
        static let emojiScaleActive: CGFloat = 1.13
        static let emojiScaleInactive: CGFloat = 0.88
    }

    var body: some View {
        ZStack {
            // Confetti overlay if enabled
            if showConfetti && trigger {
                AnimatedConfettiView(trigger: $trigger, colors: [color, .orange, .yellow])
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            // Main animated badge
            HStack(spacing: Tokens.spacing) {
                Text(emoji)
                    .font(Tokens.emojiFont)
                    .scaleEffect(animate ? Tokens.emojiScaleActive : Tokens.emojiScaleInactive)
                    .shadow(color: color.opacity(Tokens.emojiShadowOpacity), radius: 6, x: 0, y: 4)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Tokens.subtitleSpacing) {
                    Text(label)
                        .font(Tokens.badgeFont)
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.24), radius: animate ? 4 : 1, x: 0, y: 1)
                        .overlay(
                            shine ?
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.97), color.opacity(0.3)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .blendMode(.screen)
                                .mask(Text(label).font(Tokens.badgeFont))
                                .animation(.linear(duration: Tokens.shineDuration), value: shine)
                            : nil
                        )
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Tokens.subtitleFont)
                            .foregroundColor(AppColors.textSecondary ?? .secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .padding(.horizontal, Tokens.hPad)
            .padding(.vertical, Tokens.vPad)
            .background(
                Capsule()
                    .fill(color.opacity(Tokens.badgeBgOpacity))
                    .shadow(color: color.opacity(Tokens.badgeShadowOpacity), radius: animate ? Tokens.shadowRadiusActive : Tokens.shadowRadiusInactive, x: 0, y: 2)
            )
            .scaleEffect(animate ? Tokens.scaleActive : Tokens.scaleInactive)
            .opacity(animate ? 1.0 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label) + (subtitle != nil ? Text(". \(subtitle!)") : Text("")))
            .accessibilityHint(Text("Milestone achieved: \(label)\(subtitle != nil ? ". \(subtitle!)" : "")"))
            .onAppear {
                if trigger {
                    animateBadge()
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    animateBadge()
                }
            }
        }
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: animate)
    }

    /// Triggers the milestone badge and shine animation, and logs analytics.
    private func animateBadge() {
        animate = false
        shine = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.appearDelay) {
            withAnimation {
                animate = true
            }

            analyticsLogger.log(event: "milestone_appeared", emoji: emoji, label: label, subtitle: subtitle)

            DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.shineStartDelay) {
                shine = true
                analyticsLogger.log(event: "milestone_shine", emoji: emoji, label: label, subtitle: subtitle)
                DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.shineDuration) {
                    shine = false
                    analyticsLogger.log(event: "milestone_shine_end", emoji: emoji, label: label, subtitle: subtitle)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardMilestoneAnimation_Previews: PreviewProvider {
    struct SpyLogger: MilestoneAnalyticsLogger {
        func log(event: String, emoji: String, label: String, subtitle: String?) {
            print("MilestoneAnalytics: \(event), \(emoji) \(label) \(subtitle ?? "")")
        }
    }
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 36) {
                Button("Trigger Milestone") { show.toggle() }
                DashboardMilestoneAnimation(
                    trigger: $show,
                    emoji: "💸",
                    label: "Revenue Goal!",
                    color: .green,
                    subtitle: "You hit $10K this month!",
                    showConfetti: true,
                    analyticsLogger: SpyLogger()
                )
            }
            .padding()
        }
    }
    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
            .background(Color(.systemGroupedBackground))
    }
}
#endif
