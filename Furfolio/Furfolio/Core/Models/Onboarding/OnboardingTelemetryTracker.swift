//
//  OnboardingTelemetryTracker.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// A utility to centralize onboarding analytics and audit tracking
final class OnboardingTelemetryTracker {
    private let analytics: AnalyticsServiceProtocol
    private let audit: AuditLoggerProtocol
    private let userId: String?

    init(
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        userId: String? = nil
    ) {
        self.analytics = analytics
        self.audit = audit
        self.userId = userId
    }

    /// Logs when a user views a step in onboarding
    func logStepView(_ step: OnboardingStep) {
        let title = String(describing: step)
        analytics.screenView("Onboarding.\(title)")
        analytics.log(event: "onboarding_step_viewed", parameters: ["step": title])
        audit.record("Viewed onboarding step: \(title)", metadata: ["userId": userId ?? "anonymous"])
    }

    /// Logs a user action (e.g. continue, skip, reset)
    func logAction(_ action: String, step: OnboardingStep? = nil, metadata: [String: Any]? = nil) {
        var params = metadata ?? [:]
        if let step = step {
            params["step"] = step.rawValue
        }
        if let userId = userId {
            params["userId"] = userId
        }

        analytics.log(event: "onboarding_\(action)", parameters: params)
        audit.record("Onboarding action: \(action)", metadata: params.mapValues { "\($0)" })
    }

    /// Logs onboarding completion
    func logCompletion(finalStep: OnboardingStep) {
        analytics.log(event: "onboarding_complete", parameters: ["final_step": finalStep.rawValue])
        audit.record("Onboarding completed at step \(finalStep)", metadata: ["userId": userId ?? "anonymous"])
    }

    /// Logs onboarding reset
    func logReset() {
        analytics.log(event: "onboarding_reset", parameters: ["userId": userId ?? "unknown"])
        audit.record("Onboarding reset", metadata: ["userId": userId ?? "unknown"])
    }

    /// Logs any onboarding-related error
    func logError(_ error: Error, context: String? = nil) {
        analytics.log(event: "onboarding_error", parameters: [
            "error": error.localizedDescription,
            "context": context ?? "unspecified",
            "userId": userId ?? "unknown"
        ])
        audit.record("Onboarding error: \(error.localizedDescription)", metadata: [
            "context": context ?? "unspecified",
            "userId": userId ?? "unknown"
        ])
    }
}
