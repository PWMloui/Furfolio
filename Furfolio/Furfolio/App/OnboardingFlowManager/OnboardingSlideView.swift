//
//  OnboardingSlideView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, preview/testable, and accessible.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol SlideAnalyticsLogger {
    func log(event: String, slideTitle: String)
}
public struct NullSlideAnalyticsLogger: SlideAnalyticsLogger {
    public init() {}
    public func log(event: String, slideTitle: String) {}
}

// MARK: - OnboardingSlideView

struct OnboardingSlideView: View {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    // Analytics logger (injectable, defaults to no-op)
    let analyticsLogger: SlideAnalyticsLogger

    // Design tokens with safe fallback
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
        analyticsLogger: SlideAnalyticsLogger = NullSlideAnalyticsLogger(),
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
        self.analyticsLogger = analyticsLogger
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
            // Analytics: Log slide view event for onboarding analytics
            analyticsLogger.log(event: "onboarding_slide_viewed", slideTitle: String(localized: title))
        }
    }
}

// MARK: - Preview

#Preview {
    struct SpyLogger: SlideAnalyticsLogger {
        func log(event: String, slideTitle: String) {
            print("Analytics Event: \(event), Slide: \(slideTitle)")
        }
    }
    Group {
        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place.",
            analyticsLogger: SpyLogger()
        )
        .previewDisplayName("Light Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place.",
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place.",
            analyticsLogger: SpyLogger()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")
    }
}
