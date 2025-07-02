//
//  DataHealthEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

//
//  DataHealthEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//
//  MARK: - DataHealthEngine Architecture Overview
//
//  DataHealthEngine is a modular, extensible Swift class designed to monitor, audit, and ensure the health, integrity, and compliance of app data. It provides hooks for analytics, audit logging, diagnostics, accessibility, localization, and compliance (including Trust Center requirements).
//
//  Key architectural features:
//  - **Extensibility:** Analytics logging, diagnostics, and audit hooks are protocol-based, allowing for custom integrations (e.g., Trust Center, third-party analytics, or internal dashboards).
//  - **Analytics/Auditability:** Events are logged via the `DataHealthAnalyticsLogger` protocol, supporting async logging, test/preview modes, and a capped in-memory event buffer for diagnostics and admin review.
//  - **Diagnostics:** Exposes APIs to fetch recent analytics events and health status for troubleshooting and compliance audits.
//  - **Localization:** All user-facing and log strings are wrapped in `NSLocalizedString` with keys, values, and developer comments, ensuring full translation and compliance readiness.
//  - **Accessibility:** Diagnostics and error/status messages are designed to be accessible and compatible with VoiceOver and assistive technologies.
//  - **Compliance:** Audit logs and diagnostics can be surfaced to Trust Center or compliance review tools; all events are localized and auditable.
//  - **Preview/Testability:** Null logger and testMode support are provided for safe UI previews, QA, and unit tests without external dependencies.
//
//  Maintainers: Please refer to the protocol and class doc-comments for extension points. Update localization keys and comments when adding new user-facing strings.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct DataHealthAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DataHealthEngine"
}

// MARK: - Analytics Logger Protocol

/// Protocol for logging analytics and audit events from DataHealthEngine.
/// Conforming types must support async logging and optionally test/preview-only console logging.
public protocol DataHealthAnalyticsLogger: AnyObject {
    /// If true, events are only logged to console (not sent to external analytics backends).
    var testMode: Bool { get set }
    /// Log an analytics or audit event. Should be async/await ready.
    func log(
        event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

extension DataHealthAnalyticsLogger {
    /// Default implementation: testMode is false unless overridden.
    public var testMode: Bool { get { false } set {} }
}

/// Null logger for previews, tests, and QA environments.
public final class NullDataHealthAnalyticsLogger: DataHealthAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        metadata: [String : Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        // No-op, but print to console for local diagnostics in testMode.
        #if DEBUG
        if testMode {
            print("[NullDataHealthAnalyticsLogger] event: \(event)")
            print("metadata: \(metadata ?? [:])")
            print("role: \(role ?? "nil")")
            print("staffID: \(staffID ?? "nil")")
            print("context: \(context ?? "nil")")
            print("escalate: \(escalate)")
        }
        #endif
    }
}

// MARK: - DataHealthEngine

/// Engine for monitoring, auditing, and reporting data health issues.
/// Integrates with analytics, diagnostics, accessibility, and compliance systems.
public final class DataHealthEngine {
    /// The analytics logger instance (can be replaced for Trust Center, etc).
    public var analyticsLogger: DataHealthAnalyticsLogger

    /// Capped buffer for last N analytics/audit events (for diagnostics/admin/trust-center).
    private let eventBufferSize = 20
    private var recentEvents: [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let eventBufferQueue = DispatchQueue(label: "DataHealthEngine.eventBufferQueue", attributes: .concurrent)

    /// Initializes the engine with a logger (default: NullDataHealthAnalyticsLogger).
    /// - Parameter analyticsLogger: Logger for analytics/audit events.
    public init(analyticsLogger: DataHealthAnalyticsLogger = NullDataHealthAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Data Health Monitoring

    /// Starts monitoring data health. Extend for live monitoring.
    public func startMonitoring() async {
        // Stub: implement periodic checks, triggers, etc.
        await logEvent(
            key: "data_health_monitoring_started",
            value: "Data health monitoring started.",
            comment: "Event: Data health monitoring has started.",
            metadata: nil
        )
    }

    /// Reports a data health issue (e.g., corruption, missing data, compliance risk).
    /// - Parameters:
    ///   - issueKey: Localization key for the issue.
    ///   - metadata: Optional metadata for diagnostics/audit.
    public func reportIssue(issueKey: String, metadata: [String: Any]? = nil) async {
        let message = NSLocalizedString(
            issueKey,
            value: "A data health issue was reported.",
            comment: "Generic fallback for data health issue reporting."
        )
        await logEvent(
            key: issueKey,
            value: message,
            comment: "Event: Data health issue occurred.",
            metadata: metadata
        )
    }

    // MARK: - Audit Logging

    /// Writes an audit log entry. Integrate with Trust Center as needed.
    /// - Parameters:
    ///   - actionKey: Localization key for the audit action.
    ///   - details: Optional details for the audit log.
    public func auditLog(actionKey: String, details: [String: Any]? = nil) async {
        let message = NSLocalizedString(
            actionKey,
            value: "Audit log entry.",
            comment: "Generic fallback for audit log entry."
        )
        await logEvent(
            key: actionKey,
            value: message,
            comment: "Audit log event.",
            metadata: details
        )
    }

    // MARK: - Diagnostics

    /// Returns the last N analytics/audit events for diagnostics and admin review.
    public func fetchRecentEvents() -> [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        var events: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
        eventBufferQueue.sync {
            events = recentEvents
        }
        return events
    }

    /// Returns a localized, accessible diagnostics summary.
    public func diagnosticsSummary() -> String {
        let count = fetchRecentEvents().count
        return NSLocalizedString(
            "data_health_diagnostics_summary",
            value: "Data Health Engine: \(count) recent events.",
            comment: "Summary of recent data health analytics/audit events."
        )
    }

    // MARK: - Localization/Accessibility

    /// Returns a localized, accessibility-friendly description of the engine status.
    public func accessibilityStatus() -> String {
        return NSLocalizedString(
            "data_health_engine_accessibility_status",
            value: "Data Health Engine is operational.",
            comment: "VoiceOver: Status description for DataHealthEngine."
        )
    }

    // MARK: - Internal Event Logging

    /// Logs an event with localization, audit, and buffer.
    private func logEvent(key: String, value: String, comment: String, metadata: [String: Any]?) async {
        let localized = NSLocalizedString(key, value: value, comment: comment)
        let escalate = key.lowercased().contains("danger") || key.lowercased().contains("critical") || key.lowercased().contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)

        // Add to buffer
        eventBufferQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.recentEvents.count >= self.eventBufferSize {
                self.recentEvents.removeFirst(self.recentEvents.count - self.eventBufferSize + 1)
            }
            self.recentEvents.append((
                timestamp: Date(),
                event: localized,
                metadata: metadata,
                role: DataHealthAuditContext.role,
                staffID: DataHealthAuditContext.staffID,
                context: DataHealthAuditContext.context,
                escalate: escalate
            ))
        }
        // Log via analytics logger
        await analyticsLogger.log(
            event: localized,
            metadata: metadata,
            role: DataHealthAuditContext.role,
            staffID: DataHealthAuditContext.staffID,
            context: DataHealthAuditContext.context,
            escalate: escalate
        )
    }
}

// MARK: - SwiftUI PreviewProvider for Diagnostics & Accessibility

#if DEBUG
import Combine

/// Preview demonstrating diagnostics, testMode, and accessibility features of DataHealthEngine.
struct DataHealthEngine_Previews: PreviewProvider {

    class PreviewLogger: DataHealthAnalyticsLogger {
        var testMode: Bool = true
        var events: [(String, [String: Any]?, String?, String?, String?, Bool)] = []
        func log(
            event: String,
            metadata: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            events.append((event, metadata, role, staffID, context, escalate))
            print("[PreviewLogger] event: \(event)")
            print("metadata: \(metadata ?? [:])")
            print("role: \(role ?? "nil")")
            print("staffID: \(staffID ?? "nil")")
            print("context: \(context ?? "nil")")
            print("escalate: \(escalate)")
        }
    }

    static var previews: some View {
        let logger = PreviewLogger()
        let engine = DataHealthEngine(analyticsLogger: logger)
        return VStack(alignment: .leading, spacing: 8) {
            Text(engine.diagnosticsSummary())
                .accessibilityLabel(Text(engine.accessibilityStatus()))
                .padding()
            Button("Simulate Data Issue") {
                Task { await engine.reportIssue(issueKey: "preview_data_issue_simulated", metadata: ["preview": true]) }
            }
            .accessibilityHint(Text(NSLocalizedString(
                "simulate_data_issue_button_hint",
                value: "Simulates a data health issue for testing.",
                comment: "Hint for simulate data issue button in preview."
            )))
            Button("Show Recent Events") {
                print(engine.fetchRecentEvents())
            }
            .accessibilityHint(Text(NSLocalizedString(
                "show_recent_events_button_hint",
                value: "Displays recent analytics and audit events.",
                comment: "Hint for show recent events button in preview."
            )))
            Text(NSLocalizedString(
                "data_health_preview_note",
                value: "This preview demonstrates diagnostics, testMode, and accessibility features.",
                comment: "Footer note for DataHealthEngine preview."
            ))
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
        .previewDisplayName("DataHealthEngine Diagnostics Preview")
    }
}
#endif
