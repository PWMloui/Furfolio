//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, tokenized, accessible, modular, test/preview-injectable.
//

import Foundation
import SwiftUI

// MARK: - Analytics/Audit Protocols

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
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

    // MARK: - Analytics/Audit Services
    private let analytics: AnalyticsServiceProtocol
    private let audit: AuditLoggerProtocol

    // MARK: - Initialization
    init(
        onboardingKey: String = "default",
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        initialStep: OnboardingStep = .welcome,
        isComplete: Bool? = nil
    ) {
        self.onboardingCompleteKey = "isOnboardingComplete_\(onboardingKey)"
        self.onboardingCurrentStepKey = "onboardingCurrentStep_\(onboardingKey)"
        self.analytics = analytics
        self.audit = audit

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
        analytics.log(event: "skip_onboarding", parameters: ["step": currentStep.rawValue])
        audit.record("User skipped onboarding at step \(currentStep)", metadata: nil)
        completeOnboarding()
    }

    // MARK: - Private Helpers

    private func setStep(_ step: OnboardingStep, event: String) {
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: onboardingCurrentStepKey)

        analytics.log(event: event, parameters: [
            "step": step.rawValue,
            "title": String(describing: step.localizedTitle)
        ])
        audit.record("Navigated to step \(step)", metadata: nil)
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)

        analytics.log(event: "onboarding_complete", parameters: ["final_step": currentStep.rawValue])
        audit.record("User completed onboarding at step \(currentStep)", metadata: nil)
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

        analytics.log(event: "reset_onboarding", parameters: ["step": OnboardingStep.welcome.rawValue])
        audit.record("User reset onboarding", metadata: nil)
    }
}
