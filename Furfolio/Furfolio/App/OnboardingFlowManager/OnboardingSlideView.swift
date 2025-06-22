//
//  OnboardingSlideView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A single slide in the onboarding flow.
struct OnboardingSlideView: View {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.accentColor)
                .padding(.top, 32)
                .accessibilityLabel(Text(title))

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview {
    OnboardingSlideView(
        imageName: "pawprint.fill",
        title: "Welcome to Furfolio!",
        description: "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."
    )
}
