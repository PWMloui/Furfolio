//
//  OnboardingCompletionView.swift
//  Furfolio
//
//  Enhanced: Fully tokenized, analytics/audit–ready, modular, accessible, preview/testable, robust.
//

import SwiftUI

/// Protocol for audit/analytics logging; inject for compliance and business BI.
public protocol OnboardingAnalyticsLogger {
    func log(event: String)
}

/// Default no-op logger for previews/tests.
public struct NullOnboardingAnalyticsLogger: OnboardingAnalyticsLogger {
    public init() {}
    public func log(event: String) {}
}

/// The final screen displayed at the end of the onboarding flow.
/// Now fully tokenized, modular, analytics/audit–ready, and accessible.
struct OnboardingCompletionView: View {
    let onGetStarted: () -> Void
    let analyticsLogger: OnboardingAnalyticsLogger
    // Design tokens with safe fallback
    let accent: Color
    let secondary: Color
    let background: Color
    let titleFont: Font
    let bodyFont: Font
    let cornerRadius: CGFloat
    let padding: CGFloat
    let spacing: CGFloat

    /// Dependency-injectable initializer for test, preview, or production.
    init(
        onGetStarted: @escaping () -> Void,
        analyticsLogger: OnboardingAnalyticsLogger = NullOnboardingAnalyticsLogger(),
        accent: Color = AppColors.accent ?? .accentColor,
        secondary: Color = AppColors.secondary ?? .secondary,
        background: Color = AppColors.background ?? Color(UIColor.systemBackground),
        titleFont: Font = AppFonts.titleBold ?? .title.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        cornerRadius: CGFloat = AppRadius.large ?? 24,
        padding: CGFloat = AppSpacing.large ?? 24,
        spacing: CGFloat = AppSpacing.xxLarge ?? 32
    ) {
        self.onGetStarted = onGetStarted
        self.analyticsLogger = analyticsLogger
        self.accent = accent
        self.secondary = secondary
        self.background = background
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.spacing = spacing
    }

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(height: padding * 3)
                .foregroundColor(accent)
                .accessibilityLabel(LocalizedStringKey("Onboarding complete"))

            Text(LocalizedStringKey("You're all set!"))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Start using Furfolio to grow and simplify your grooming business."))
                .font(bodyFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(secondary)

            Button(action: {
                analyticsLogger.log(event: "onboarding_get_started_tap")
                onGetStarted()
            }) {
                Text(LocalizedStringKey("Get Started"))
                    .frame(maxWidth: .infinity)
                    .font(titleFont)
                    .padding(padding * 0.5)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .padding(.top, padding * 0.5)
            .accessibilityLabel(LocalizedStringKey("Get Started"))
            .accessibilityHint(LocalizedStringKey("Begin using the app and complete onboarding"))
        }
        .padding(padding)
        .background(background.ignoresSafeArea())
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

struct OnboardingCompletionView_Previews: PreviewProvider {
    struct AnalyticsLoggerSpy: OnboardingAnalyticsLogger {
        func log(event: String) {
            print("Analytics Event: \(event)")
        }
    }

    static var previews: some View {
        Group {
            OnboardingCompletionView(
                onGetStarted: {},
                analyticsLogger: AnalyticsLoggerSpy()
            )
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

            OnboardingCompletionView(
                onGetStarted: {},
                analyticsLogger: AnalyticsLoggerSpy()
            )
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

            OnboardingCompletionView(
                onGetStarted: {},
                analyticsLogger: AnalyticsLoggerSpy()
            )
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        }
    }
}
