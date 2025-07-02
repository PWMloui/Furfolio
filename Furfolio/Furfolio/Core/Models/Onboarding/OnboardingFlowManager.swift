//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, tokenized, accessible, modular, test/preview-injectable.
//
/**
 OnboardingFlowManager
 ---------------------
 Orchestrates user onboarding steps in Furfolio with async analytics and audit logging.

 - **Architecture**: ObservableObject singleton for MVVM binding.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in async Tasks.
 - **Audit Management**: Uses `OnboardingFlowAuditManager` actor to record events.
 - **Localization**: All event strings use `NSLocalizedString`.
 - **Diagnostics**: Provides async methods to fetch/export recent audit entries.
 - **Accessibility**: State changes are exposed via published properties for UI updates.
 - **Preview/Testability**: Analytics and audit services are injectable for mocks.
 */

import Foundation
import SwiftUI

// MARK: - Analytics/Audit Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

/// A record of an onboarding flow audit event.
public struct OnboardingFlowAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

/// Manages concurrency-safe audit logging for onboarding flow events.
public actor OnboardingFlowAuditManager {
    private var buffer: [OnboardingFlowAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingFlowAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: OnboardingFlowAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [OnboardingFlowAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as JSON.
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
        Task {
            await analytics.log(
                event: NSLocalizedString("skip_onboarding", comment: ""),
                parameters: ["step": currentStep.rawValue]
            )
            await audit.record(
                NSLocalizedString("User skipped onboarding at step \(currentStep)", comment: ""),
                metadata: nil
            )
            await OnboardingFlowAuditManager.shared.add(
                OnboardingFlowAuditEntry(
                    event: NSLocalizedString("skip_onboarding step \(currentStep.rawValue)", comment: "")
                )
            )
            completeOnboarding()
        }
    }

    // MARK: - Private Helpers

    private func setStep(_ step: OnboardingStep, event: String) {
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: onboardingCurrentStepKey)
        Task {
            await analytics.log(
                event: NSLocalizedString(event, comment: ""),
                parameters: [
                    "step": step.rawValue,
                    "title": String(describing: step.localizedTitle)
                ]
            )
            await audit.record(
                NSLocalizedString("Navigated to step \(step)", comment: ""),
                metadata: nil
            )
            await OnboardingFlowAuditManager.shared.add(
                OnboardingFlowAuditEntry(
                    event: NSLocalizedString("\(event) step \(step.rawValue)", comment: "")
                )
            )
        }
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
        Task {
            await analytics.log(
                event: NSLocalizedString("onboarding_complete", comment: ""),
                parameters: ["final_step": currentStep.rawValue]
            )
            await audit.record(
                NSLocalizedString("User completed onboarding at step \(currentStep)", comment: ""),
                metadata: nil
            )
            await OnboardingFlowAuditManager.shared.add(
                OnboardingFlowAuditEntry(
                    event: NSLocalizedString("onboarding_complete step \(currentStep.rawValue)", comment: "")
                )
            )
        }
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
        Task {
            await analytics.log(
                event: NSLocalizedString("reset_onboarding", comment: ""),
                parameters: ["step": OnboardingStep.welcome.rawValue]
            )
            await audit.record(
                NSLocalizedString("User reset onboarding", comment: ""),
                metadata: nil
            )
            await OnboardingFlowAuditManager.shared.add(
                OnboardingFlowAuditEntry(
                    event: NSLocalizedString("reset_onboarding", comment: "")
                )
            )
        }
    }
}

public extension OnboardingFlowManager {
    /// Fetch recent onboarding audit entries.
    func recentAuditEntries(limit: Int = 20) async -> [OnboardingFlowAuditEntry] {
        await OnboardingFlowAuditManager.shared.recent(limit: limit)
    }
    /// Export onboarding audit log as JSON.
    func exportAuditLogJSON() async -> String {
        await OnboardingFlowAuditManager.shared.exportJSON()
    }
}
