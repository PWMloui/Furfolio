
//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for clarity, extensibility, and robustness
//

import Foundation
import SwiftUI

/// Enum representing each onboarding step.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case dataImport
    case tutorial
    case faq
    case permissions
    case finish

    var id: Int { rawValue }

    /// Localized title for each step.
    var title: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome"
        case .dataImport: return "Import Data"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .permissions: return "Permissions"
        case .finish: return "Finish"
        }
    }
}

/// Observable manager for onboarding flow state.
@MainActor
final class OnboardingFlowManager: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published private(set) var isOnboardingComplete: Bool = false

    private static let onboardingCompleteKey = "isOnboardingComplete"

    /// Returns true if a next onboarding step exists.
    var hasNextStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue + 1) != nil
    }

    /// Returns true if a previous step exists.
    var hasPreviousStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue - 1) != nil
    }

    /// Advance to the next onboarding step, or complete if at the end.
    func goToNextStep() {
        if hasNextStep {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1)!
        } else {
            completeOnboarding()
        }
    }

    /// Go back to the previous onboarding step.
    func goToPreviousStep() {
        if hasPreviousStep {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1)!
        }
    }

    /// Skip the remaining steps and mark onboarding as complete.
    func skipOnboarding() {
        completeOnboarding()
    }

    /// Finalize onboarding and persist the state.
    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
    }

    /// Load onboarding status from persistent storage.
    func loadOnboardingState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey)
    }

    /// Reset onboarding progress for testing or development.
    func resetOnboarding() {
        isOnboardingComplete = false
        UserDefaults.standard.set(false, forKey: Self.onboardingCompleteKey)
        currentStep = .welcome
    }
}
