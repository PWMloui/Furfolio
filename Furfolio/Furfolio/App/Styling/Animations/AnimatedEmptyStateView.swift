//
//  AnimatedEmptyStateView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, and robust.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol EmptyStateAnalyticsLogger {
    func log(event: String, emoji: String, title: String)
}
public struct NullEmptyStateAnalyticsLogger: EmptyStateAnalyticsLogger {
    public init() {}
    public func log(event: String, emoji: String, title: String) {}
}

/// An animated placeholder view for empty states in lists or onboarding screens.
/// Now analytics/audit–ready, fully tokenized, accessible, and test/preview–injectable.
struct AnimatedEmptyStateView: View {
    var emoji: String = "🐾"
    var title: String = "No Data Yet"
    var message: String = "Once you add items, they’ll show up here!"
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    var analyticsLogger: EmptyStateAnalyticsLogger = NullEmptyStateAnalyticsLogger()

    @State private var animate = false

    // MARK: - Design Tokens (robust fallback)
    private enum Style {
        static let circleSize: CGFloat = AppSpacing.xxxLarge ?? 110
        static let emojiSize: CGFloat = AppFonts.emptyStateEmoji ?? 60
        static let animationDuration: Double = 1.2
        static let scaleRange: ClosedRange<CGFloat> = 0.94...1.08
        static let rotationAngle: Double = 9
        static let offsetRange: ClosedRange<CGFloat> = -7...7
        static let verticalSpacing: CGFloat = AppSpacing.large ?? 18
        static let frameMax: CGFloat = 350
        static let verticalPad: CGFloat = AppSpacing.xLarge ?? 34
        static let topPad: CGFloat = AppSpacing.medium ?? 16
        static let actionTopPad: CGFloat = AppSpacing.small ?? 8
        static let titleFont: Font = AppFonts.title2Bold ?? .title2.bold()
        static let msgFont: Font = AppFonts.body ?? .body
        static let accent: Color = AppColors.accent ?? .accentColor
        static let primary: Color = AppColors.primary ?? .primary
        static let secondary: Color = AppColors.secondary ?? .secondary
        static let bg: Color = AppColors.emptyStateBg ?? Color.accentColor.opacity(0.13)
    }

    var body: some View {
        VStack(spacing: Style.verticalSpacing) {
            ZStack {
                Circle()
                    .fill(Style.bg)
                    .frame(width: Style.circleSize, height: Style.circleSize)
                    .scaleEffect(animate ? Style.scaleRange.upperBound : Style.scaleRange.lowerBound)
                    .animation(.easeInOut(duration: Style.animationDuration).repeatForever(autoreverses: true), value: animate)

                Text(emoji)
                    .font(.system(size: Style.emojiSize))
                    .rotationEffect(.degrees(animate ? Style.rotationAngle : -Style.rotationAngle))
                    .offset(y: animate ? Style.offsetRange.lowerBound : Style.offsetRange.upperBound)
                    .animation(.interpolatingSpring(stiffness: 140, damping: 9).repeatForever(autoreverses: true), value: animate)
                    .accessibilityLabel(Text("Empty state icon: \(emoji)"))
            }
            .padding(.top, Style.topPad)

            Text(title)
                .font(Style.titleFont)
                .multilineTextAlignment(.center)
                .foregroundColor(Style.primary)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(Style.msgFont)
                .multilineTextAlignment(.center)
                .foregroundColor(Style.secondary)
                .accessibilityLabel(Text(message))

            if let label = actionLabel, let action = action {
                Button(label, action: {
                    analyticsLogger.log(event: "action_tapped", emoji: emoji, title: title)
                    action()
                })
                .buttonStyle(PulseButtonStyle(color: Style.accent))
                .padding(.top, Style.actionTopPad)
                .accessibilityLabel("Button: \(label)")
            }
        }
        .frame(maxWidth: Style.frameMax)
        .padding(.vertical, Style.verticalPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animate = true
            analyticsLogger.log(event: "empty_state_appeared", emoji: emoji, title: title)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedEmptyStateView_Previews: PreviewProvider {
    struct SpyLogger: EmptyStateAnalyticsLogger {
        func log(event: String, emoji: String, title: String) {
            print("Analytics: \(event), emoji: \(emoji), title: \(title)")
        }
    }
    static var previews: some View {
        Group {
            AnimatedEmptyStateView(
                emoji: "🐩",
                title: "No Dogs Added",
                message: "Add a new dog profile to see them listed here.",
                actionLabel: "Add Dog",
                action: {},
                analyticsLogger: SpyLogger()
            )
            .previewLayout(.sizeThatFits)

            AnimatedEmptyStateView(analyticsLogger: SpyLogger())
                .previewLayout(.sizeThatFits)
        }
        .padding()
        .background(AppColors.emptyStatePreviewBg ?? Color(.systemGroupedBackground))
        .preferredColorScheme(.light)
    }
}
#endif
