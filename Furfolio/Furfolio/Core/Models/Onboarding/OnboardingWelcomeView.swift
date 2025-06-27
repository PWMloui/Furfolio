//
//  OnboardingWelcomeView.swift
//  Furfolio
//
//  Enhanced for accessibility, localization, analytics/audit logging, and testability.
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

// MARK: - OnboardingWelcomeView

/// The first onboarding screen introducing the Furfolio app.
struct OnboardingWelcomeView: View {
    /// Callback triggered when the user taps the primary continue button.
    var onContinue: (() -> Void)? = nil

    /// Injected logging services
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens
    let accentColor: Color
    let textSecondary: Color
    let background: Color
    let secondaryBackground: Color
    let titleFont: Font
    let bodyFont: Font
    let spacingLarge: CGFloat
    let spacingMedium: CGFloat
    let spacingMediumLarge: CGFloat
    let spacingExtraLarge: CGFloat
    let imageHeight: CGFloat

    init(
        onContinue: (() -> Void)? = nil,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accentColor: Color = AppColors.accent ?? .accentColor,
        textSecondary: Color = AppColors.textSecondary ?? .secondary,
        background: Color = AppColors.background ?? Color(.systemBackground),
        secondaryBackground: Color = AppColors.secondaryBackground ?? Color(.secondarySystemBackground),
        titleFont: Font = AppFonts.title.bold() ?? .title.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        spacingLarge: CGFloat = AppSpacing.large ?? 36,
        spacingMedium: CGFloat = AppSpacing.medium ?? 20,
        spacingMediumLarge: CGFloat = AppSpacing.mediumLarge ?? 24,
        spacingExtraLarge: CGFloat = AppSpacing.extraLarge ?? 32,
        imageHeight: CGFloat = 100
    ) {
        self.onContinue = onContinue
        self.analytics = analytics
        self.audit = audit
        self.accentColor = accentColor
        self.textSecondary = textSecondary
        self.background = background
        self.secondaryBackground = secondaryBackground
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.spacingLarge = spacingLarge
        self.spacingMedium = spacingMedium
        self.spacingMediumLarge = spacingMediumLarge
        self.spacingExtraLarge = spacingExtraLarge
        self.imageHeight = imageHeight
    }

    var body: some View {
        VStack(spacing: spacingLarge) {
            Spacer(minLength: spacingMedium)

            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)
                .foregroundColor(accentColor)
                .padding(.top, spacingMedium)
                .accessibilityLabel(Text("Furfolio app icon"))

            Text(LocalizedStringKey("Welcome to Furfolio!"))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(LocalizedStringKey("Welcome to Furfolio"))
                .accessibilityHint(LocalizedStringKey("Introduction to the Furfolio app"))

            Text(LocalizedStringKey("The modern business toolkit for dog grooming professionals.\n\nEasily manage appointments, clients, pets, and business growth—all in one place."))
                .font(bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(textSecondary)
                .padding(.horizontal, spacingMediumLarge)

            Spacer()

            Button(action: {
                analytics.log(event: "onboarding_welcome_continue", parameters: nil)
                audit.record("User continued from welcome screen", metadata: nil)
                onContinue?()
            }) {
                Text(LocalizedStringKey("Get Started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, spacingMediumLarge)
            .padding(.bottom, spacingExtraLarge)
            .accessibilityLabel(LocalizedStringKey("Continue to next step"))
            .accessibilityHint(LocalizedStringKey("Navigates to the next step in onboarding"))
        }
        .padding()
        .background(gradientBackground)
        .accessibilityElement(children: .contain)
        .onAppear {
            analytics.screenView("OnboardingWelcome")
            audit.record("User landed on onboarding welcome screen", metadata: nil)
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [background, secondaryBackground]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) {
            print("[Analytics] \(event) \(parameters ?? [:])")
        }
        func screenView(_ name: String) {
            print("[Analytics] screenView: \(name)")
        }
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) {}
    }

    return Group {
        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .previewDisplayName("Light Mode")

        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Large Font")
    }
}
