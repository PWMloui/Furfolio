//
//  OnboardingProgressIndicator.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for clarity, accessibility, and extensibility.
//

import SwiftUI

/// A visual step-based indicator for the onboarding flow.
/// Displays capsules to represent each onboarding step and highlights the active one.
///
/// - Parameters:
///   - currentStep: The zero-based index of the current onboarding step.
///   - totalSteps: Total number of steps in the onboarding sequence.
struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: idx == currentStep ? 28 : 10, height: 10)
                    .accessibilityLabel(
                        idx == currentStep
                            ? LocalizedStringKey("Current step \(idx + 1) of \(totalSteps)")
                            : LocalizedStringKey("Step \(idx + 1)")
                    )
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Onboarding progress indicator.")
    }
}

// MARK: - Preview

#Preview {
    VStack {
        OnboardingProgressIndicator(currentStep: 2, totalSteps: 5)
            .padding()
        Text("Example step content goes here.")
            .padding(.bottom, 40)
    }
}
