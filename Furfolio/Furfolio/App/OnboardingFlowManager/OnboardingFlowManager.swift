//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for clarity, extensibility, and robustness
//
//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  This file defines the OnboardingFlowManager, which orchestrates the user onboarding process in Furfolio.
//
//  Responsibilities:
//  - Manages the current onboarding step, completion state, and navigation logic.
//  - Designed for accessibility: all user-facing strings are localizable, enabling screen reader support and internationalization.
//  - Provides hooks for analytics and audit logging (see TODOs).
//  - Easily extensible: onboarding steps and flow logic can be modified by updating the OnboardingStep enum and related navigation.
//
//  Accessibility Notes:
//  - All user-facing text is localized for screen reader compatibility and internationalization.
//
//  Analytics & Audit Logging:
//  - TODO comments are present at key navigation points for integrating analytics or audit trail hooks.
//
//  Extensibility:
//  - See comments above OnboardingStep for safe modification guidance.
//

import Foundation
import SwiftUI

/// OnboardingStep defines the sequence of onboarding screens.
/// ------------------------------------------------------------------------
/// Extensibility Guidance:
/// - To add a new step:
///     1. Add a new case to the enum (e.g., `case profileSetup`).
///     2. Update any switch statements (e.g., `title`, UI rendering) to handle the new step.
///     3. Ensure navigation logic (hasNextStep, hasPreviousStep) is robust and that onboarding completion remains accurate.
/// - To remove a step:
///     1. Remove the enum case and related UI logic.
///     2. Consider migration for users mid-onboarding (if needed).
/// - Always keep the order of cases as the intended onboarding sequence.
/// - Use only rawValue-based navigation for forward/back logic.
/// ------------------------------------------------------------------------
enum OnboardingStep: Int, CaseIterable, Identifiable, CustomStringConvertible {
    /// Introduction screen.
    case welcome
    /// Option to import demo or file-based data.
    case dataImport
    /// Swipeable tutorial on core features.
    case tutorial
    /// Frequently asked questions about the app.
    case faq
    /// Request permissions (e.g., notifications).
    case permissions
    /// Completion screen.
    case finish

    var id: Int { rawValue }

    /// Localized title for each onboarding step.
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .welcome: return LocalizedStringKey("Welcome")
        case .dataImport: return LocalizedStringKey("Import Data")
        case .tutorial: return LocalizedStringKey("Tutorial")
        case .faq: return LocalizedStringKey("FAQ")
        case .permissions: return LocalizedStringKey("Permissions")
        case .finish: return LocalizedStringKey("Finish")
        }
    }

    /// Localized, descriptive text for accessibility, onboarding guides,
    /// and analytics/audit events.
    ///
    /// Useful for VoiceOver announcements, onboarding progress indicators,
    /// and detailed event logging.
    var localizedDescription: LocalizedStringKey {
        switch self {
        case .welcome:
            return LocalizedStringKey("Introduction and welcome screen of the onboarding process.")
        case .dataImport:
            return LocalizedStringKey("Step to import demo or file-based data.")
        case .tutorial:
            return LocalizedStringKey("Swipeable tutorial explaining core features.")
        case .faq:
            return LocalizedStringKey("Frequently asked questions about the app.")
        case .permissions:
            return LocalizedStringKey("Requesting permissions such as notifications.")
        case .finish:
            return LocalizedStringKey("Completion screen signaling the end of onboarding.")
        }
    }

    /// Text-only representation for debugging.
    var description: String {
        String(describing: localizedTitle)
    }

    // MARK: - Future Expansion
    
    // Add additional properties here to extend onboarding steps, for example:
    // var iconName: String { ... }
    // var detailText: LocalizedStringKey { ... }
}

/// Usage example for onboarding navigation and analytics logging:
///
/// ```swift
/// func proceedToNextStep(currentStep: OnboardingStep) {
///     if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
///         // Navigate to next onboarding screen
///         navigateTo(step: nextStep)
///         // Log analytics event with descriptive info
///         Analytics.logEvent("OnboardingStepViewed", parameters: [
///             "step": nextStep.localizedTitle.description,
///             "description": nextStep.localizedDescription.description
///         ])
///     } else {
///         // Onboarding finished
///         completeOnboarding()
///     }
/// }
/// ```

/// Observable manager for onboarding flow state.
@MainActor
final class OnboardingFlowManager: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .welcome {
        didSet {
            // Persist current step whenever it changes (except on reset or complete).
            UserDefaults.standard.set(currentStep.rawValue, forKey: Self.onboardingCurrentStepKey)
        }
    }
    @Published private(set) var isOnboardingComplete: Bool = false

    private static let onboardingCompleteKey = "isOnboardingComplete"
    private static let onboardingCurrentStepKey = "onboardingCurrentStep"

    /// Returns true if a next onboarding step exists.
    var hasNextStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue + 1) != nil
    }

    /// Returns true if a previous step exists.
    var hasPreviousStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue - 1) != nil
    }

    /// Advance to the next onboarding step, or complete if at the end.
    ///
    /// Note: If onboarding flow becomes non-linear (not rawValue-ordered),
    /// navigation logic should be refactored to use an array-based or state-driven flow.
    func goToNextStep() {
        // TODO: Insert analytics or audit logging for advancing steps.
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        } else {
            // No next step found; complete onboarding.
            completeOnboarding()
        }
    }

    /// Go back to the previous onboarding step.
    ///
    /// Note: If onboarding flow becomes non-linear (not rawValue-ordered),
    /// navigation logic should be refactored to use an array-based or state-driven flow.
    func goToPreviousStep() {
        // TODO: Insert analytics or audit logging for returning to previous step.
        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previousStep
        }
        // If no previous step, do nothing (already at first step).
    }

    /// Skip the remaining steps and mark onboarding as complete.
    func skipOnboarding() {
        // TODO: Insert analytics or audit logging for skipping onboarding.
        completeOnboarding()
    }

    /// Finalize onboarding and persist the state.
    ///
    /// This method sets the completion flag, but does NOT update currentStep,
    /// so currentStep persistence is not updated here.
    private func completeOnboarding() {
        // TODO: Insert analytics or audit logging for onboarding completion.
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
    }

    /// Load onboarding status from persistent storage.
    ///
    /// Restores both completion state and current step (if available).
    func loadOnboardingState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey)
        if let savedStepRaw = UserDefaults.standard.value(forKey: Self.onboardingCurrentStepKey) as? Int,
           let savedStep = OnboardingStep(rawValue: savedStepRaw) {
            currentStep = savedStep
        } else {
            currentStep = .welcome
        }
    }

    /// Reset onboarding progress for testing or development.
    ///
    /// Clears completion state and current step, and persists changes.
    func resetOnboarding() {
        isOnboardingComplete = false
        UserDefaults.standard.set(false, forKey: Self.onboardingCompleteKey)
        currentStep = .welcome
    }
}

/*
// MARK: - Usage Example
//
// Example: Integrating OnboardingFlowManager in a SwiftUI view
//
// struct OnboardingView: View {
//     @StateObject private var flowManager = OnboardingFlowManager()
//
//     var body: some View {
//         VStack {
//             Text(flowManager.currentStep.title)
//                 .font(.largeTitle)
//                 .padding()
//
//             // Render content based on currentStep
//             switch flowManager.currentStep {
//             case .welcome:
//                 Text(LocalizedStringKey("Welcome to Furfolio!"))
//             case .dataImport:
//                 Text(LocalizedStringKey("Import your data to get started."))
//             case .tutorial:
//                 Text(LocalizedStringKey("Learn how to use the app."))
//             case .faq:
//                 Text(LocalizedStringKey("Frequently Asked Questions"))
//             case .permissions:
//                 Text(LocalizedStringKey("Enable permissions to continue."))
//             case .finish:
//                 Text(LocalizedStringKey("You're all set!"))
//             }
//
//             HStack {
//                 if flowManager.hasPreviousStep {
//                     Button(action: { flowManager.goToPreviousStep() }) {
//                         Text(LocalizedStringKey("Back"))
//                     }
//                 }
//                 Spacer()
//                 if flowManager.hasNextStep {
//                     Button(action: { flowManager.goToNextStep() }) {
//                         Text(LocalizedStringKey("Next"))
//                     }
//                 } else {
//                     Button(action: { flowManager.completeOnboarding() }) {
//                         Text(LocalizedStringKey("Finish"))
//                     }
//                 }
//             }
//             .padding()
//
//             Button(action: { flowManager.skipOnboarding() }) {
//                 Text(LocalizedStringKey("Skip"))
//             }
//             .padding(.top)
//         }
//         .onAppear {
//             flowManager.loadOnboardingState()
//         }
//     }
// }
//
// Place this view early in your app's flow, and observe isOnboardingComplete to determine when onboarding is finished.
*/
