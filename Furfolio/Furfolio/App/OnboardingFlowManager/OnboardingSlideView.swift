//
//  OnboardingSlideView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

/// A modular onboarding slide view that is accessible, localizable,
/// and ready for analytics and audit logging.
/// 
/// This view presents an image, title, and description for each onboarding slide,
/// using design tokens for styling and spacing where available.
/// 
/// TODO: Support dynamic localization or remote config for slide content.
/// TODO: Implement analytics logging for slide views.

import SwiftUI

/// A single slide in the onboarding flow.
struct OnboardingSlideView: View {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(AppColors.accent)
                .padding(.top, AppSpacing.large)
                .accessibilityLabel(title)
                .accessibilityHint(description)

            Text(title)
                .font(AppFonts.title2Bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.large)
        .accessibilityElement(children: .contain)
        // Analytics: Log slide view event here for onboarding analytics
    }
}

// MARK: - Preview

#Preview {
    Group {
        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."
        )
        .previewDisplayName("Light Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: "Welcome to Furfolio!",
            description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")
    }
}
