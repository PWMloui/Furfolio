/**
 OnboardingViewModel
 -------------------
 Manages the state and progression of the Furfolio onboarding flow.

 - **Architecture**: ObservableObject on @MainActor for SwiftUI binding.
 - **Dependencies**: Injects `AnalyticsServiceProtocol` and `AuditLoggerProtocol` for event tracking.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking async Tasks.
 - **Audit Management**: Uses `OnboardingViewModelAuditManager` actor to record events for diagnostics.
 - **Localization**: Event names and messages can be localized via NSLocalizedString at the service level.
 - **Diagnostics**: Provides methods to fetch and export recent audit entries.
 - **Preview/Testability**: Services are injectable, enabling mock analytics and audit logging in tests and previews.
 */
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
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit message asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

/// A record of an OnboardingViewModel audit event.
public struct OnboardingViewModelAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let step: OnboardingStep?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, step: OnboardingStep? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.step = step
    }
}

/// Actor for concurrency-safe audit logging in OnboardingViewModel.
public actor OnboardingViewModelAuditManager {
    private var buffer: [OnboardingViewModelAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingViewModelAuditManager()

    /// Add an audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: OnboardingViewModelAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingViewModelAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
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
        Task {
            await analytics.log(event: "onboarding_skipped", parameters: ["step": currentStep.rawValue])
            await audit.record("User skipped onboarding at step \(currentStep)", metadata: nil)
            await OnboardingViewModelAuditManager.shared.add(
                OnboardingViewModelAuditEntry(event: "skipped", step: currentStep)
            )
            completeOnboarding()
        }
    }

    func reset() {
        isComplete = false
        currentStep = .welcome
        UserDefaults.standard.removeObject(forKey: completeKey)
        UserDefaults.standard.set(currentStep.rawValue, forKey: stepKey)
        Task {
            await analytics.log(event: "onboarding_reset", parameters: nil)
            await audit.record("User reset onboarding", metadata: nil)
            await OnboardingViewModelAuditManager.shared.add(
                OnboardingViewModelAuditEntry(event: "reset", step: nil)
            )
        }
    }

    // MARK: - State Persistence

    private func setStep(_ step: OnboardingStep) {
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: stepKey)

        Task {
            await analytics.log(event: "onboarding_step", parameters: [
                "step": step.rawValue,
                "label": String(describing: step.title)
            ])
            await audit.record("Navigated to onboarding step: \(step)", metadata: nil)
            await OnboardingViewModelAuditManager.shared.add(
                OnboardingViewModelAuditEntry(event: "step", step: step)
            )
        }
    }

    private func completeOnboarding() {
        isComplete = true
        UserDefaults.standard.set(true, forKey: completeKey)

        Task {
            await analytics.log(event: "onboarding_completed", parameters: ["final_step": currentStep.rawValue])
            await audit.record("User completed onboarding", metadata: nil)
            await OnboardingViewModelAuditManager.shared.add(
                OnboardingViewModelAuditEntry(event: "completed", step: currentStep)
            )
        }
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

// MARK: - Diagnostics

public extension OnboardingViewModel {
    /// Fetch recent onboarding audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingViewModelAuditEntry] {
        await OnboardingViewModelAuditManager.shared.recent(limit: limit)
    }

    /// Export onboarding audit log as a JSON string.
    static func exportAuditLogJSON() async -> String {
        await OnboardingViewModelAuditManager.shared.exportJSON()
    }
}
