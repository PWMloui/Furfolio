//
//  OnboardingTelemetryTracker.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingTelemetryTracker
 ---------------------------
 Centralized utility for onboarding analytics and audit tracking in Furfolio.

 - **Architecture**: Final class with dependency-injected `AnalyticsServiceProtocol` and `AuditLoggerProtocol`. Suitable for MVVM and DI.
 - **Concurrency & Async Logging**: All tracking methods are async, using `await` on analytics and audit services to avoid blocking the UI.
 - **Diagnostics**: Supports detailed event and error logging with user context for troubleshooting.
 - **Localization**: User-facing event names and metadata can be localized at the service level.
 - **Accessibility & Compliance**: Ensures non-sensitive telemetry is separated from audit trails; supports compliance with data policies.
 - **Preview/Testability**: Easily mockable analytics and audit protocols for unit and UI tests.
 */

import Foundation

/// A utility to centralize onboarding analytics and audit tracking
public final class OnboardingTelemetryTracker {
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

    /// Logs when a user views a step in onboarding asynchronously
    public func logStepView(_ step: OnboardingStep) async {
        let title = String(describing: step)
        await analytics.screenView("Onboarding.\(title)")
        await analytics.log(event: "onboarding_step_viewed", parameters: ["step": title])
        await audit.record("Viewed onboarding step: \(title)", metadata: ["userId": userId ?? "anonymous"])
    }

    /// Logs a user action (e.g. continue, skip, reset) asynchronously
    public func logAction(_ action: String, step: OnboardingStep? = nil, metadata: [String: Any]? = nil) async {
        var params = metadata ?? [:]
        if let step = step {
            params["step"] = step.rawValue
        }
        if let userId = userId {
            params["userId"] = userId
        }

        await analytics.log(event: "onboarding_\(action)", parameters: params)
        await audit.record("Onboarding action: \(action)", metadata: params.mapValues { "\($0)" })
    }

    /// Logs onboarding completion asynchronously
    public func logCompletion(finalStep: OnboardingStep) async {
        await analytics.log(event: "onboarding_complete", parameters: ["final_step": finalStep.rawValue])
        await audit.record("Onboarding completed at step \(finalStep)", metadata: ["userId": userId ?? "anonymous"])
    }

    /// Logs onboarding reset asynchronously
    public func logReset() async {
        await analytics.log(event: "onboarding_reset", parameters: ["userId": userId ?? "unknown"])
        await audit.record("Onboarding reset", metadata: ["userId": userId ?? "unknown"])
    }

    /// Logs any onboarding-related error asynchronously
    public func logError(_ error: Error, context: String? = nil) async {
        await analytics.log(event: "onboarding_error", parameters: [
            "error": error.localizedDescription,
            "context": context ?? "unspecified",
            "userId": userId ?? "unknown"
        ])
        await audit.record("Onboarding error: \(error.localizedDescription)", metadata: [
            "context": context ?? "unspecified",
            "userId": userId ?? "unknown"
        ])
    }
}
