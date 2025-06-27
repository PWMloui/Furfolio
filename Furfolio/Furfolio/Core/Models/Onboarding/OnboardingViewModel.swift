//
//  OnboardingViewModel.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import Combine

// MARK: - Centralized Analytics + Audit Protocols

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
}

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isComplete: Bool = false

    // MARK: - Services

    private let analytics: AnalyticsServiceProtocol
    private let audit: AuditLoggerProtocol
    private let stepKey = "furfolio.onboarding.currentStep"
    private let completeKey = "furfolio.onboarding.isComplete"

    // MARK: - Init

    init(
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared
    ) {
        self.analytics = analytics
        self.audit = audit
        restore()
    }

    // MARK: - Step Control

    func goToNextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        setStep(next)
    }

    func goToPreviousStep() {
        guard let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        setStep(previous)
    }

    func skip() {
        analytics.log(event: "onboarding_skipped", parameters: ["step": currentStep.rawValue])
        audit.record("User skipped onboarding at step \(currentStep)", metadata: nil)
        completeOnboarding()
    }

    func reset() {
        isComplete = false
        currentStep = .welcome
        UserDefaults.standard.removeObject(forKey: completeKey)
        UserDefaults.standard.set(currentStep.rawValue, forKey: stepKey)
        analytics.log(event: "onboarding_reset", parameters: nil)
        audit.record("User reset onboarding", metadata: nil)
    }

    // MARK: - State Persistence

    private func setStep(_ step: OnboardingStep) {
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: stepKey)

        analytics.log(event: "onboarding_step", parameters: [
            "step": step.rawValue,
            "label": String(describing: step.title)
        ])
        audit.record("Navigated to onboarding step: \(step)", metadata: nil)
    }

    private func completeOnboarding() {
        isComplete = true
        UserDefaults.standard.set(true, forKey: completeKey)

        analytics.log(event: "onboarding_completed", parameters: ["final_step": currentStep.rawValue])
        audit.record("User completed onboarding", metadata: nil)
    }

    private func restore() {
        if let raw = UserDefaults.standard.value(forKey: stepKey) as? Int,
           let step = OnboardingStep(rawValue: raw) {
            currentStep = step
        } else {
            currentStep = .welcome
        }

        isComplete = UserDefaults.standard.bool(forKey: completeKey)
    }
}
