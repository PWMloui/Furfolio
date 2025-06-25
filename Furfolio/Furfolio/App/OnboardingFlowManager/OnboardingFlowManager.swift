//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, tokenized, accessible, modular, test/preview-injectable.
//

import Foundation
import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol OnboardingAnalyticsLogger {
    func log(event: String, step: OnboardingStep?, extra: [String: String]?)
}
public struct NullOnboardingAnalyticsLogger: OnboardingAnalyticsLogger {
    public init() {}
    public func log(event: String, step: OnboardingStep?, extra: [String: String]?) { }
}

// MARK: - Onboarding Steps

enum OnboardingStep: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case welcome
    case dataImport
    case tutorial
    case faq
    case permissions
    case finish

    var id: Int { rawValue }
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome"
        case .dataImport: return "Import Data"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .permissions: return "Permissions"
        case .finish: return "Finish"
        }
    }
    var localizedDescription: LocalizedStringKey {
        switch self {
        case .welcome: return "Introduction and welcome screen of the onboarding process."
        case .dataImport: return "Step to import demo or file-based data."
        case .tutorial: return "Swipeable tutorial explaining core features."
        case .faq: return "Frequently asked questions about the app."
        case .permissions: return "Requesting permissions such as notifications."
        case .finish: return "Completion screen signaling the end of onboarding."
        }
    }
    var description: String { String(localizedTitle) }
}

// MARK: - OnboardingFlowManager

@MainActor
final class OnboardingFlowManager: ObservableObject {
    // MARK: - State
    @Published private(set) var currentStep: OnboardingStep
    @Published private(set) var isOnboardingComplete: Bool

    // MARK: - Diagnostics
    var diagnosticsSummary: String {
        "Step: \(currentStep) | Complete: \(isOnboardingComplete)"
    }

    // MARK: - Persistence Keys
    private let onboardingCompleteKey: String
    private let onboardingCurrentStepKey: String

    // MARK: - Analytics/Audit
    private let analyticsLogger: OnboardingAnalyticsLogger

    // MARK: - Initialization
    init(
        onboardingKey: String = "default",
        analyticsLogger: OnboardingAnalyticsLogger = NullOnboardingAnalyticsLogger(),
        initialStep: OnboardingStep = .welcome,
        isComplete: Bool? = nil
    ) {
        self.onboardingCompleteKey = "isOnboardingComplete_\(onboardingKey)"
        self.onboardingCurrentStepKey = "onboardingCurrentStep_\(onboardingKey)"
        self.analyticsLogger = analyticsLogger

        // Load state if available, else use provided/default
        let storedIsComplete = UserDefaults.standard.object(forKey: onboardingCompleteKey) as? Bool
        let storedStepRaw = UserDefaults.standard.object(forKey: onboardingCurrentStepKey) as? Int
        self.isOnboardingComplete = isComplete ?? (storedIsComplete ?? false)
        self.currentStep = storedStepRaw.flatMap(OnboardingStep.init(rawValue:)) ?? initialStep
    }

    // MARK: - Navigation

    var hasNextStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue + 1) != nil
    }
    var hasPreviousStep: Bool {
        OnboardingStep(rawValue: currentStep.rawValue - 1) != nil
    }

    func goToNextStep() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            setStep(nextStep, event: "next_step")
        } else {
            completeOnboarding()
        }
    }

    func goToPreviousStep() {
        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            setStep(previousStep, event: "previous_step")
        }
    }

    func skipOnboarding() {
        analyticsLogger.log(event: "skip_onboarding", step: currentStep, extra: nil)
        completeOnboarding()
    }

    // MARK: - Private Helpers

    private func setStep(_ step: OnboardingStep, event: String) {
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: onboardingCurrentStepKey)
        analyticsLogger.log(event: event, step: step, extra: [
            "step": "\(step.rawValue)",
            "title": String(step.localizedTitle)
        ])
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
        analyticsLogger.log(event: "onboarding_complete", step: currentStep, extra: [
            "final_step": "\(currentStep.rawValue)"
        ])
    }

    // MARK: - Persistence

    func loadOnboardingState() {
        let storedIsComplete = UserDefaults.standard.object(forKey: onboardingCompleteKey) as? Bool
        let storedStepRaw = UserDefaults.standard.object(forKey: onboardingCurrentStepKey) as? Int
        isOnboardingComplete = storedIsComplete ?? false
        currentStep = storedStepRaw.flatMap(OnboardingStep.init(rawValue:)) ?? .welcome
    }

    func resetOnboarding() {
        isOnboardingComplete = false
        currentStep = .welcome
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(OnboardingStep.welcome.rawValue, forKey: onboardingCurrentStepKey)
        analyticsLogger.log(event: "reset_onboarding", step: .welcome, extra: nil)
    }
}
