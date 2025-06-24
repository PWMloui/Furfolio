//
//  OnboardingProgressIndicator.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for clarity, accessibility, and extensibility.
//

/**
 OnboardingProgressIndicator.swift

 This file defines the onboarding progress indicator component, which visually represents the user's progression through the onboarding steps.

 Features:
 - Fully accessible with descriptive labels and values for assistive technologies.
 - Compliant with design tokens for colors and spacing.
 - Localized strings for all accessibility elements.
 - Prepared for audit and analytics integration with TODO placeholders for future logging of progress changes.
 - Handles edge cases gracefully to prevent UI breakage.
*/

import SwiftUI

/// A visual step-based indicator for the onboarding flow.
/// Displays capsules to represent each onboarding step and highlights the active one.
///
/// - Parameters:
///   - currentStep: The zero-based index of the current onboarding step.
///   - totalSteps: Total number of steps in the onboarding sequence.
///   - onProgressChange: Optional closure called whenever currentStep changes.
/// 
/// Edge Case Handling:
/// - If totalSteps is zero or negative, the view renders empty.
/// - currentStep is clamped to valid range 0..<totalSteps to prevent UI issues.
/// - Runtime assertions ensure parameters are valid during development.
struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    var onProgressChange: ((Int) -> Void)? = nil

    // Clamped current step to valid range, or zero if totalSteps <= 0
    private var safeCurrentStep: Int {
        guard totalSteps > 0 else { return 0 }
        return min(max(currentStep, 0), totalSteps - 1)
    }

    init(currentStep: Int, totalSteps: Int, onProgressChange: ((Int) -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onProgressChange = onProgressChange

        // Assert currentStep is within valid range for debug builds
        assert(totalSteps >= 0, "totalSteps should not be negative")
        if totalSteps > 0 {
            assert((0..<totalSteps).contains(currentStep), "currentStep is out of valid range")
        }
    }

    var body: some View {
        // If totalSteps is zero or negative, show empty view to prevent UI issues
        if totalSteps <= 0 {
            EmptyView()
        } else {
            HStack(spacing: {
                #if canImport(AppSpacing)
                AppSpacing.medium
                #else
                8 // Fallback spacing if AppSpacing is missing
                #endif
            }()) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill({
                            #if canImport(AppColors)
                            idx == safeCurrentStep ? AppColors.accent : AppColors.inactive.opacity(0.3)
                            #else
                            (idx == safeCurrentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            #endif
                        }())
                        .frame(width: idx == safeCurrentStep ? 28 : 10, height: 10)
                        .accessibilityLabel(
                            LocalizedStringKey("Step \(idx + 1) of \(totalSteps)")
                        )
                        .accessibilityValue(
                            idx == safeCurrentStep
                            ? LocalizedStringKey("Current step")
                            : LocalizedStringKey("Not current step")
                        )
                }
            }
            .padding(.vertical, {
                #if canImport(AppSpacing)
                AppSpacing.medium
                #else
                8 // Fallback vertical padding if AppSpacing is missing
                #endif
            }())
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: safeCurrentStep)
            .accessibilityElement(children: .combine)
            .accessibilityHint(LocalizedStringKey("Indicates your progress through the onboarding steps."))
            .onChange(of: safeCurrentStep) { newValue in
                onProgressChange?(newValue)
                // TODO: Add analytics/audit logging for progress changes here
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Group {
        VStack {
            OnboardingProgressIndicator(currentStep: 2, totalSteps: 5)
                .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Light Mode")

        VStack {
            OnboardingProgressIndicator(currentStep: 2, totalSteps: 5)
                .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        VStack {
            OnboardingProgressIndicator(currentStep: 2, totalSteps: 5)
                .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")

        VStack {
            OnboardingProgressIndicator(currentStep: 0, totalSteps: 0)
                .padding()
            Text("No steps to display (totalSteps = 0).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Zero Steps")

        VStack {
            OnboardingProgressIndicator(currentStep: 10, totalSteps: 5)
                .padding()
            Text("currentStep out of bounds (clamped to valid range).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Current Step Out of Bounds")
    }
}
