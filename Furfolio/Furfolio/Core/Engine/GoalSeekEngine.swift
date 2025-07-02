//
//  GoalSeekEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

//
//  GoalSeekEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//
//  MARK: - GoalSeekEngine Architecture Overview
//
//  This file implements the GoalSeekEngine, a modular and extensible engine for performing "goal seek" calculations (e.g., finding the input value required to achieve a target output).
//
//  ## Architecture
//  - **GoalSeekEngine**: Central class for performing calculations, logging analytics, diagnostics, and audit trails.
//  - **GoalSeekAnalyticsLogger**: Protocol for analytics logging, supports async/await, extensible for Trust Center, privacy, and compliance hooks.
//  - **NullGoalSeekAnalyticsLogger**: No-op logger for previews, tests, and QA (testMode).
//  - **Localization**: All user-facing and log strings wrapped in `NSLocalizedString` with keys, values, and comments for full localization and compliance.
//  - **Diagnostics & Audit**: Diagnostics and audit logs are available for admin, analytics, and Trust Center review.
//  - **Accessibility**: All logs and diagnostics are accessible, and preview demonstrates accessibility features.
//  - **Preview/Testability**: PreviewProvider demonstrates diagnostics, testMode, and accessibility for maintainers.
//
//  ## Extensibility
//  - Swap in custom analytics loggers (e.g., for GDPR, CCPA, or internal audit).
//  - Add new calculation strategies by extending GoalSeekEngine.
//  - Localize all user-facing/log strings easily.
//
//  ## Analytics, Audit, Trust Center Hooks
//  - Analytics logger is pluggable and async/await-ready.
//  - Audit logs can be routed to secure storage or Trust Center.
//  - Diagnostics API exposes recent events for admin, compliance, and debugging.
//
//  ## Diagnostics & Compliance
//  - Capped event buffer (last 20) for efficient diagnostics.
//  - All logs and events are localized and compliant with privacy requirements.
//
//  ## Accessibility
//  - Diagnostics and preview are accessible for assistive technologies.
//
//  ## Preview & Testability
//  - NullGoalSeekAnalyticsLogger and testMode support for QA, previews, and unit tests.
//  - PreviewProvider demonstrates diagnostics and accessibility features.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct GoalSeekAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "GoalSeekEngine"
}

// MARK: - Analytics Logger Protocol

/// Protocol for analytics logging, supporting async/await and testMode for console-only logging.
public protocol GoalSeekAnalyticsLogger: AnyObject {
    /// Indicates whether the logger is in test/QA mode (console-only, no remote logging).
    var testMode: Bool { get set }
    /// Log an analytics event asynchronously.
    func log(
        event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null logger for previews, tests, and QA.
public final class NullGoalSeekAnalyticsLogger: GoalSeekAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        metadata: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[NullGoalSeekAnalyticsLogger][TEST MODE] \(event) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - GoalSeekEngine

/// Main engine for goal seek calculations, analytics, diagnostics, audit, and localization.
public final class GoalSeekEngine {

    /// Analytics logger (pluggable for compliance, privacy, or Trust Center).
    public var analyticsLogger: GoalSeekAnalyticsLogger

    /// Capped buffer (last 20) of analytics/audit/diagnostic events.
    private var eventBuffer: [(event: String, timestamp: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let eventBufferCapacity = 20
    private let eventBufferQueue = DispatchQueue(label: "GoalSeekEngine.eventBufferQueue")

    /// Initialize with an analytics logger (default: NullGoalSeekAnalyticsLogger).
    /// - Parameter analyticsLogger: Logger to use for analytics/audit events.
    public init(analyticsLogger: GoalSeekAnalyticsLogger = NullGoalSeekAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Goal Seek Calculation

    /// Perform a goal seek calculation to find the input that yields the target output.
    /// - Parameters:
    ///   - target: Desired output value.
    ///   - initialGuess: Initial guess for input.
    ///   - tolerance: Acceptable difference.
    ///   - maxIterations: Maximum number of iterations.
    /// - Returns: Calculated input value, or nil if not found.
    /// - Note: This is a stub implementation; override for real logic.
    public func performGoalSeek(
        target: Double,
        initialGuess: Double,
        tolerance: Double = 1e-6,
        maxIterations: Int = 100
    ) async -> Double? {
        let startMsg = NSLocalizedString(
            "GoalSeekEngine.StartCalculation",
            value: "Starting goal seek calculation for target: \(target)",
            comment: "Log: Begin goal seek calculation"
        )
        let escalate = startMsg.lowercased().contains("danger") || startMsg.lowercased().contains("critical") || startMsg.lowercased().contains("delete")
            || false
        await logEvent(startMsg, metadata: nil, escalate: escalate)
        // TODO: Implement actual goal seek calculation logic.
        let result: Double? = nil
        let endMsg = NSLocalizedString(
            "GoalSeekEngine.EndCalculation",
            value: "Goal seek calculation completed. Result: \(result.map { String($0) } ?? "nil")",
            comment: "Log: End goal seek calculation"
        )
        let escalateEnd = endMsg.lowercased().contains("danger") || endMsg.lowercased().contains("critical") || endMsg.lowercased().contains("delete")
            || false
        await logEvent(endMsg, metadata: nil, escalate: escalateEnd)
        return result
    }

    // MARK: - Audit Logging

    /// Record an audit log event (routed to analytics logger and buffer).
    /// - Parameters:
    ///   - message: Audit message (localized).
    ///   - metadata: Optional metadata for audit.
    public func auditLog(_ message: String, metadata: [String: Any]? = nil) async {
        let auditMsg = NSLocalizedString(
            "GoalSeekEngine.AuditLog",
            value: "AUDIT: \(message)",
            comment: "Audit log event"
        )
        let escalate = auditMsg.lowercased().contains("danger") || auditMsg.lowercased().contains("critical") || auditMsg.lowercased().contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await logEvent(auditMsg, metadata: metadata, escalate: escalate)
    }

    // MARK: - Diagnostics

    /// Fetch the most recent analytics/audit/diagnostic events (last 20).
    /// - Returns: Array of event data tuples.
    public func recentEvents() -> [(event: String, timestamp: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        eventBufferQueue.sync {
            return eventBuffer
        }
    }

    /// Log a diagnostics event (localized).
    /// - Parameter message: Diagnostics message.
    public func diagnostics(_ message: String) async {
        let diagMsg = NSLocalizedString(
            "GoalSeekEngine.Diagnostics",
            value: "DIAGNOSTICS: \(message)",
            comment: "Diagnostics log event"
        )
        let escalate = diagMsg.lowercased().contains("danger") || diagMsg.lowercased().contains("critical") || diagMsg.lowercased().contains("delete")
            || false
        await logEvent(diagMsg, metadata: nil, escalate: escalate)
    }

    // MARK: - Private Logging/Event Buffer

    /// Internal function to log an event, update buffer, and send to analytics logger.
    private func logEvent(_ event: String, metadata: [String: Any]? = nil, escalate: Bool) async {
        // Update event buffer (capped)
        eventBufferQueue.sync {
            if eventBuffer.count >= eventBufferCapacity {
                eventBuffer.removeFirst(eventBuffer.count - eventBufferCapacity + 1)
            }
            eventBuffer.append((event, Date(), metadata, GoalSeekAuditContext.role, GoalSeekAuditContext.staffID, GoalSeekAuditContext.context, escalate))
        }
        // Send to analytics logger
        await analyticsLogger.log(
            event: event,
            metadata: metadata,
            role: GoalSeekAuditContext.role,
            staffID: GoalSeekAuditContext.staffID,
            context: GoalSeekAuditContext.context,
            escalate: escalate
        )
    }
}

// MARK: - PreviewProvider for Diagnostics, TestMode, Accessibility

#if DEBUG
import Combine

/// SwiftUI preview for maintainers to test diagnostics, testMode, and accessibility.
struct GoalSeekEnginePreview: View {
    @State private var diagnostics: [(event: String, timestamp: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let engine: GoalSeekEngine

    init() {
        // Use testMode logger for QA/preview.
        let logger = PreviewLogger()
        logger.testMode = true
        self.engine = GoalSeekEngine(analyticsLogger: logger)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString(
                "GoalSeekEngine.PreviewTitle",
                value: "GoalSeekEngine Diagnostics Preview",
                comment: "Preview: Title for diagnostics preview"
            ))
            .accessibilityAddTraits(.isHeader)
            .font(.headline)
            Button(action: {
                Task {
                    await engine.diagnostics(NSLocalizedString(
                        "GoalSeekEngine.PreviewDiagnosticsEvent",
                        value: "Preview diagnostics event triggered",
                        comment: "Preview: Diagnostics event"
                    ))
                    diagnostics = engine.recentEvents()
                }
            }) {
                Text(NSLocalizedString(
                    "GoalSeekEngine.PreviewTriggerDiagnostics",
                    value: "Trigger Diagnostics Event",
                    comment: "Preview: Button to trigger diagnostics"
                ))
            }
            .accessibilityLabel(Text(NSLocalizedString(
                "GoalSeekEngine.PreviewTriggerDiagnostics.Accessibility",
                value: "Trigger a diagnostics event for preview",
                comment: "Accessibility: Button to trigger diagnostics"
            )))
            .padding(.vertical, 4)
            Text(NSLocalizedString(
                "GoalSeekEngine.PreviewRecentEvents",
                value: "Recent Events:",
                comment: "Preview: Label for recent events"
            ))
            .font(.subheadline)
            .accessibilityAddTraits(.isStaticText)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(diagnostics, id: \.timestamp) { eventData in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eventData.event)
                                .font(.caption)
                                .accessibilityLabel(eventData.event)
                            Text("Timestamp: \(eventData.timestamp.description)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let metadata = eventData.metadata {
                                Text("Metadata: \(metadata.description)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("Role: \(eventData.role ?? "-") StaffID: \(eventData.staffID ?? "-") Context: \(eventData.context ?? "-") Escalate: \(eventData.escalate ? "Yes" : "No")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxHeight: 150)
            Spacer()
            Text(NSLocalizedString(
                "GoalSeekEngine.PreviewAccessibilityHint",
                value: "All diagnostics are accessible and localized.",
                comment: "Preview: Accessibility hint"
            ))
            .font(.footnote)
            .foregroundColor(.secondary)
            .accessibilityHint(NSLocalizedString(
                "GoalSeekEngine.PreviewAccessibilityHint",
                value: "All diagnostics are accessible and localized.",
                comment: "Accessibility: Diagnostics accessibility hint"
            ))
        }
        .padding()
    }

    /// Simple preview logger that prints to console in testMode.
    private final class PreviewLogger: GoalSeekAnalyticsLogger {
        var testMode: Bool = true
        func log(
            event: String,
            metadata: [String : Any]? = nil,
            role: String? = nil,
            staffID: String? = nil,
            context: String? = nil,
            escalate: Bool
        ) async {
            if testMode {
                print("[PreviewLogger][TEST MODE] \(event) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
            }
        }
    }
}

struct GoalSeekEnginePreview_Previews: PreviewProvider {
    static var previews: some View {
        GoalSeekEnginePreview()
            .previewDisplayName(NSLocalizedString(
                "GoalSeekEngine.PreviewDisplayName",
                value: "GoalSeekEngine Diagnostics",
                comment: "Preview: Display name"
            ))
    }
}
#endif
