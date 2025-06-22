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
        VStack(spacing: 36) {
            Spacer(minLength: 20)

            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.accentColor)
                .padding(.top, 16)
                .accessibilityLabel(Text("Furfolio app icon"))

            Text("Welcome to Furfolio!")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Text("The modern business toolkit for dog grooming professionals.\n\nEasily manage appointments, clients, pets, and business growth—all in one place.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: {
                onContinue?()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Continue to next step")
        }
        .padding()
        .background(gradientBackground)
        .accessibilityElement(children: .contain)
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingWelcomeView {
        print("Next step triggered")
    }
}
