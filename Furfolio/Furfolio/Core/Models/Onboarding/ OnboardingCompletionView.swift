//
//  OnboardingCompletionView.swift
//  Furfolio
//
//  Enhanced: Fully tokenized, analytics/audit–ready, modular, accessible, preview/testable, robust.
//

/**
 OnboardingCompletionView
 ------------------------
 A SwiftUI view that confirms onboarding completion in Furfolio.

 - **Purpose**: Celebrates successful onboarding and directs users to start the app.
 - **Architecture**: MVVM-capable, dependency-injectable for analytics and audit.
 - **Concurrency & Analytics**: Uses async/await for audit and analytics logging via protocols.
 - **Audit/Analytics Ready**: Defines async protocols and uses Task for non-blocking logging.
 - **Localization**: All user-facing strings use `LocalizedStringKey`.
 - **Accessibility**: Combines children, provides labels and hints.
 - **Preview/Testability**: Previews inject mock async loggers and demonstrate light/dark/accessibility modes.
 */

import SwiftUI

// MARK: - Centralized Analytics + Audit Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Track a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record a general audit message asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
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
                Task {
                    await analytics.log(event: "onboarding_get_started_tap", parameters: nil)
                    await audit.record("User tapped 'Get Started' on onboarding completion", metadata: nil)
                    onGetStarted()
                }
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
        .onAppear {
            Task {
                await analytics.screenView("OnboardingCompletion")
            }
        }
    }
}

// MARK: - Previews

struct OnboardingCompletionView_Previews: PreviewProvider {
    struct PreviewAnalyticsLogger: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) async {
            print("[Preview] Analytics: \(event)")
        }
        func screenView(_ name: String) async {}
    }

    struct PreviewAuditLogger: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) async {
            print("[Preview] Audit: \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
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
