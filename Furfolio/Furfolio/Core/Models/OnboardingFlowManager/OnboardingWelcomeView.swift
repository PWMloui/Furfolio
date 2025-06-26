//
//  OnboardingWelcomeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced for accessibility, localization, and reusability.
//

import SwiftUI

/// The first onboarding screen introducing the Furfolio app.
struct OnboardingWelcomeView: View {
    /// Callback triggered when the user taps the primary continue button.
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.large) { // TODO: Confirm AppSpacing.large == 36
            Spacer(minLength: AppSpacing.medium) // TODO: Confirm AppSpacing.medium == 20

            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(AppColors.accent)
                .padding(.top, AppSpacing.small) // TODO: Confirm AppSpacing.small == 16
                .accessibilityLabel(Text(LocalizedStringKey("Furfolio app icon")))

            Text(LocalizedStringKey("Welcome to Furfolio!"))
                .font(AppFonts.title.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(LocalizedStringKey("Welcome to Furfolio"))
                .accessibilityHint(LocalizedStringKey("Introduction to the Furfolio app"))

            Text(LocalizedStringKey("The modern business toolkit for dog grooming professionals.\n\nEasily manage appointments, clients, pets, and business growth—all in one place."))
                .font(AppFonts.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.mediumLarge) // TODO: Confirm AppSpacing.mediumLarge == 24

            Spacer()

            Button(action: {
                onContinue?()
            }) {
                Text(LocalizedStringKey("Get Started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, AppSpacing.mediumLarge) // TODO: Confirm AppSpacing.mediumLarge == 24
            .padding(.bottom, AppSpacing.extraLarge) // TODO: Confirm AppSpacing.extraLarge == 32
            .accessibilityLabel(LocalizedStringKey("Continue to next step"))
            .accessibilityHint(LocalizedStringKey("Navigates to the next step in onboarding"))
        }
        .padding()
        .background(gradientBackground)
        .accessibilityElement(children: .contain)
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [AppColors.background, AppColors.secondaryBackground]), // TODO: Confirm these tokens exist
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    Group {
        OnboardingWelcomeView {
            print("Next step triggered")
        }
        .environment(\.colorScheme, .light)
        .environment(\.sizeCategory, .large)

        OnboardingWelcomeView {
            print("Next step triggered")
        }
        .environment(\.colorScheme, .dark)
        .environment(\.sizeCategory, .accessibilityExtraLarge)
    }
}
