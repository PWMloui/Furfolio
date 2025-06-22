//
//   OnboardingCompletionView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

/// Final screen displayed at the end of the onboarding flow.
struct OnboardingCompletionView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(.accentColor)
                .accessibilityLabel("Onboarding complete")

            Text("You're all set!")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Start using Furfolio to grow and simplify your grooming business.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Get Started", action: onGetStarted)
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
