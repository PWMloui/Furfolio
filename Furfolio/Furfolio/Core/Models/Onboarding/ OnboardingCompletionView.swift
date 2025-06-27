//
//  OnboardingCompletionView.swift
//  Furfolio
//
//  Enhanced: Fully tokenized, analytics/audit–ready, modular, accessible, preview/testable, robust.
//

import SwiftUI

// MARK: - Centralized Analytics + Audit Protocols

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
}

// MARK: - Onboarding Completion View

struct OnboardingCompletionView: View {
    let onGetStarted: () -> Void
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

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
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
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
        self.analytics = analytics
        self.audit = audit
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
                analytics.log(event: "onboarding_get_started_tap", parameters: nil)
                audit.record("User tapped 'Get Started' on onboarding completion", metadata: nil)
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
    struct PreviewAnalyticsLogger: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) {
            print("[Preview] Analytics: \(event)")
        }
        func screenView(_ name: String) {}
    }

    struct PreviewAuditLogger: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) {
            print("[Preview] Audit: \(message)")
        }
        func recordSensitive(_ action: String, userId: String) {}
    }

    static var previews: some View {
        Group {
            OnboardingCompletionView(
                onGetStarted: {},
                analytics: PreviewAnalyticsLogger(),
                audit: PreviewAuditLogger()
            )
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

            OnboardingCompletionView(
                onGetStarted: {},
                analytics: PreviewAnalyticsLogger(),
                audit: PreviewAuditLogger()
            )
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

            OnboardingCompletionView(
                onGetStarted: {},
                analytics: PreviewAnalyticsLogger(),
                audit: PreviewAuditLogger()
            )
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        }
    }
}
