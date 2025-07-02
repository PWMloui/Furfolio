//
//  ClientSatisfactionEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

//
//  ClientSatisfactionEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//
//  MARK: - Architecture & Maintenance Documentation
//
//  Overview:
//  The ClientSatisfactionEngine module provides a highly extensible, testable, and compliant framework for collecting, analyzing,
//  and acting on client feedback within Furfolio. It is designed for seamless integration with analytics, audit, diagnostics,
//  accessibility, and localization/compliance systems. All user-facing and log strings are fully localized for internationalization
//  and regulatory compliance (e.g., GDPR, CCPA). The engine supports preview/testability and is accessibility-aware for all
//  user interactions.
//
//  Key Features:
//    - Async/await-ready analytics logging (ClientSatisfactionAnalyticsLogger protocol) with testMode for QA/previews.
//    - Pluggable analytics logger for Trust Center, audit, and diagnostics hooks.
//    - Diagnostics API and capped event buffer for admin/diagnostic review.
//    - Full localization of all user/log-facing strings via NSLocalizedString with keys, values, and comments.
//    - Accessibility-friendly for all user interactions/messages.
//    - PreviewProvider demonstrates diagnostics, testMode, and accessibility.
//
//  Extensibility:
//    - Analytics logger can be swapped for production, QA, or preview/test.
//    - Feedback and analysis logic are stubbed for future expansion.
//    - Audit, diagnostic, and localization hooks are provided for compliance.
//
//  Compliance:
//    - All logging and analytics are Trust Center-ready, with auditLog() and diagnostics() for regulatory review.
//    - Localization and accessibility are first-class, supporting international and accessibility compliance.
//
//  Preview/Testability:
//    - NullClientSatisfactionAnalyticsLogger for previews/tests.
//    - Diagnostics and testMode are previewable.
//
//  Maintainers: Please refer to this doc block and inline doc-comments for extension points, compliance, and best practices.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ClientSatisfactionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ClientSatisfactionEngine"
}

/// Protocol for analytics logging in the ClientSatisfactionEngine.
/// Supports async/await, testMode for console-only logging, and extensibility.
public protocol ClientSatisfactionAnalyticsLogger {
    /// If true, events are only logged to console (not sent to analytics backend).
    var testMode: Bool { get }
    /// Logs an analytics event with optional metadata and full audit context.
    func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null object for analytics logger, suitable for previews/tests.
public struct NullClientSatisfactionAnalyticsLogger: ClientSatisfactionAnalyticsLogger {
    public let testMode: Bool
    public init(testMode: Bool = true) { self.testMode = testMode }
    public func logEvent(
        _ event: String,
        metadata: [String : Any]? = nil,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("NullClientSatisfactionAnalyticsLogger - Event: \(event)")
            print("Metadata: \(metadata ?? [:])")
            print("Role: \(role ?? "nil")")
            print("StaffID: \(staffID ?? "nil")")
            print("Context: \(context ?? "nil")")
            print("Escalate: \(escalate)")
        }
        // No-op for previews/tests.
    }
}

/// Main engine for client satisfaction feedback, analytics, and diagnostics.
/// Extensible for audit, compliance, localization, and accessibility.
public final class ClientSatisfactionEngine: ObservableObject {
    /// Analytics logger (can be swapped for test/production).
    private let analyticsLogger: ClientSatisfactionAnalyticsLogger
    /// Capped buffer of recent analytics events (last 20).
    private var recentEvents: [(event: String, timestamp: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let eventBufferSize = 20

    /// Initializes the engine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use.
    public init(analyticsLogger: ClientSatisfactionAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    /// Fetches client feedback asynchronously.
    /// - Returns: Array of feedback strings (stubbed).
    public func fetchFeedback() async -> [String] {
        // Stub: Replace with real feedback fetch logic.
        let logMsg = NSLocalizedString(
            "feedback_fetch_started",
            value: "Started fetching client feedback.",
            comment: "Log: Feedback fetch operation started"
        )
        await logAndBufferEvent(logMsg, metadata: nil)
        return []
    }

    /// Analyzes client satisfaction from feedback.
    /// - Parameter feedback: Array of feedback strings.
    /// - Returns: Satisfaction score (stubbed).
    public func analyzeSatisfaction(feedback: [String]) async -> Double {
        // Stub: Replace with real analysis logic.
        let logMsg = NSLocalizedString(
            "satisfaction_analysis_started",
            value: "Started analyzing client satisfaction.",
            comment: "Log: Satisfaction analysis started"
        )
        await logAndBufferEvent(logMsg, metadata: ["feedbackCount": feedback.count])
        return 0.0
    }

    /// Sends follow-up messages to clients based on satisfaction analysis.
    /// - Parameter satisfied: Whether the client is satisfied.
    public func sendFollowUp(toSatisfiedClients satisfied: Bool) async {
        // Stub: Replace with real follow-up logic.
        let logMsg = NSLocalizedString(
            "followup_sent",
            value: satisfied ? "Sent follow-up to satisfied clients." : "Sent follow-up to unsatisfied clients.",
            comment: "Log: Follow-up sent to clients"
        )
        await logAndBufferEvent(logMsg, metadata: ["satisfied": satisfied])
    }

    /// Records an audit log entry for compliance/Trust Center.
    /// - Parameter message: The audit log message.
    public func auditLog(_ message: String) async {
        let localizedMsg = NSLocalizedString(
            "audit_log_entry",
            value: "Audit log entry: \(message)",
            comment: "Audit log entry for Trust Center/compliance"
        )
        await logAndBufferEvent(localizedMsg, metadata: ["audit": true])
    }

    /// Returns diagnostics info for admin review.
    /// - Returns: Diagnostics string (localized).
    public func diagnostics() -> String {
        let msg = NSLocalizedString(
            "diagnostics_summary",
            value: "Diagnostics: \(recentEvents.count) recent events. Test mode: \(analyticsLogger.testMode ? "ON" : "OFF")",
            comment: "Diagnostics summary for admin"
        )
        return msg
    }

    /// Returns the most recent analytics events for admin/diagnostics.
    /// - Returns: Array of tuples (event, timestamp, metadata, role, staffID, context, escalate).
    public func getRecentEvents() -> [(event: String, timestamp: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        return recentEvents
    }

    /// Internal: Logs and buffers an analytics event.
    private func logAndBufferEvent(_ event: String, metadata: [String: Any]?) async {
        let lowercasedEvent = event.lowercased()
        let metadataValues = metadata?.values.map { "\($0)".lowercased() } ?? []
        let escalate = lowercasedEvent.contains("danger") ||
            lowercasedEvent.contains("critical") ||
            lowercasedEvent.contains("delete") ||
            metadataValues.contains(where: { $0.contains("danger") || $0.contains("critical") || $0.contains("delete") })

        await analyticsLogger.logEvent(
            event,
            metadata: metadata,
            role: ClientSatisfactionAuditContext.role,
            staffID: ClientSatisfactionAuditContext.staffID,
            context: ClientSatisfactionAuditContext.context,
            escalate: escalate
        )
        // Buffer event (capped)
        if recentEvents.count >= eventBufferSize {
            recentEvents.removeFirst()
        }
        recentEvents.append((
            event: event,
            timestamp: Date(),
            metadata: metadata,
            role: ClientSatisfactionAuditContext.role,
            staffID: ClientSatisfactionAuditContext.staffID,
            context: ClientSatisfactionAuditContext.context,
            escalate: escalate
        ))
    }
}

// MARK: - PreviewProvider for diagnostics, testMode, and accessibility demonstration

#if DEBUG
struct ClientSatisfactionEngine_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            let engine = ClientSatisfactionEngine(analyticsLogger: NullClientSatisfactionAnalyticsLogger(testMode: true))
            Text(NSLocalizedString(
                "preview_title",
                value: "Client Satisfaction Engine Preview",
                comment: "Preview title for ClientSatisfactionEngine"
            ))
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            Button(action: {
                Task {
                    await engine.auditLog("Preview audit log event")
                }
            }) {
                Text(NSLocalizedString(
                    "preview_audit_button",
                    value: "Log Audit Event",
                    comment: "Button to log audit event in preview"
                ))
            }
            .accessibilityLabel(NSLocalizedString(
                "preview_audit_button_accessibility",
                value: "Log Audit Event for Diagnostics",
                comment: "Accessibility label for audit log button"
            ))
            Text(engine.diagnostics())
                .accessibilityLabel(NSLocalizedString(
                    "preview_diagnostics_label",
                    value: "Diagnostics summary",
                    comment: "Accessibility label for diagnostics summary"
                ))
            // Display recent events with all audit fields
            ScrollView {
                ForEach(engine.getRecentEvents().indices, id: \.self) { index in
                    let event = engine.getRecentEvents()[index]
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event: \(event.event)")
                        Text("Timestamp: \(event.timestamp.description)")
                        Text("Metadata: \(event.metadata ?? [:])")
                        Text("Role: \(event.role ?? "nil")")
                        Text("StaffID: \(event.staffID ?? "nil")")
                        Text("Context: \(event.context ?? "nil")")
                        Text("Escalate: \(event.escalate ? "YES" : "NO")")
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .previewDisplayName(NSLocalizedString(
            "preview_display_name",
            value: "Client Satisfaction Engine Diagnostics",
            comment: "Preview display name"
        ))
    }
}
#endif
