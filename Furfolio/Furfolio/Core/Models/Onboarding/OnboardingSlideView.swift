//
//  OnboardingSlideView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, preview/testable, and accessible.
//

import SwiftUI

// MARK: - Centralized Analytics + Audit Logger Protocols

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
}

// MARK: - OnboardingSlideView

struct OnboardingSlideView: View {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    // Logging
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens
    let accent: Color
    let textSecondary: Color
    let spacingL: CGFloat
    let imageHeight: CGFloat
    let titleFont: Font
    let descFont: Font

    // MARK: - DI initializer for prod, preview, or test
    init(
        imageName: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accent: Color = AppColors.accent ?? .accentColor,
        textSecondary: Color = AppColors.textSecondary ?? .secondary,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        imageHeight: CGFloat = 100,
        titleFont: Font = AppFonts.title2Bold ?? .title2.bold(),
        descFont: Font = AppFonts.body ?? .body
    ) {
        self.imageName = imageName
        self.title = title
        self.description = description
        self.analytics = analytics
        self.audit = audit
        self.accent = accent
        self.textSecondary = textSecondary
        self.spacingL = spacingL
        self.imageHeight = imageHeight
        self.titleFont = titleFont
        self.descFont = descFont
    }

    var body: some View {
        VStack(spacing: spacingL) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)
                .foregroundColor(accent)
                .padding(.top, spacingL)
                .accessibilityLabel(title)
                .accessibilityHint(description)

            Text(title)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(descFont)
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.horizontal, spacingL)
        .accessibilityElement(children: .contain)
        .onAppear {
            let titleString = String(localized: title)
            analytics.log(event: "onboarding_slide_viewed", parameters: ["slide_title": titleString])
            audit.record("Viewed onboarding slide titled '\(titleString)'", metadata: nil)
        }
    }
}

// MARK: - Preview

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) {
            print("[Analytics] \(event): \(parameters ?? [:])")
        }
        func screenView(_ name: String) {}
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) {}
    }

    let title: LocalizedStringKey = "Welcome to Furfolio!"
    let desc: LocalizedStringKey = "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."

    return Group {
        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .previewDisplayName("Light Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")
    }
}
