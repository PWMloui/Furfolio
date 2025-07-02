//
//  SchedulingSuggestionEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//
//  MARK: - SchedulingSuggestionEngine Architecture & Developer Notes
//
//  SchedulingSuggestionEngine is a modular, extensible engine for generating context-aware scheduling suggestions.
//
//  ## Architecture
//  - The engine is designed as a class, supporting dependency injection for analytics, audit logging, diagnostics, and localization.
//  - All user-facing and log event strings are wrapped with NSLocalizedString for full localization and compliance.
//  - Analytics and audit hooks are provided via the `SchedulingSuggestionAnalyticsLogger` protocol, supporting async/await and a `testMode` for previews/tests.
//  - A capped buffer of recent analytics events (last 20) is maintained for diagnostics and admin review.
//  - Diagnostic methods expose engine state for troubleshooting and Trust Center compliance.
//
//  ## Extensibility
//  - Add new suggestion algorithms by extending `generateSuggestions`.
//  - Swap in custom analytics loggers conforming to `SchedulingSuggestionAnalyticsLogger`.
//  - Extend audit/diagnostics hooks as needed for compliance or Trust Center requirements.
//
//  ## Analytics, Audit, & Trust Center Hooks
//  - All analytics and audit events are routed through the injected logger.
//  - The engine supports a `testMode` for privacy-safe, console-only logging in previews, QA, and tests.
//  - The diagnostics API exposes recent events for admin and compliance review.
//
//  ## Diagnostics
//  - The engine provides a diagnostics API exposing recent analytics events and internal state.
//  - Use in SwiftUI Previews or admin screens to review engine activity.
//
//  ## Localization & Accessibility
//  - All user-facing and log strings are fully localized using NSLocalizedString with explicit keys and comments.
//  - PreviewProvider demonstrates accessibility and diagnostic features.
//
//  ## Compliance
//  - Engine is designed for Trust Center and auditability requirements.
//  - No sensitive data leaves the engine unless routed through compliant analytics loggers.
//
//  ## Preview & Testability
//  - Null logger and testMode allow for safe, privacy-preserving previews and tests.
//  - SwiftUI PreviewProvider demonstrates diagnostics and accessibility.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SchedulingSuggestionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SchedulingSuggestionEngine"
}

/// Protocol for analytics logging, supporting async/await and testMode for console-only logging in previews/tests.
public protocol SchedulingSuggestionAnalyticsLogger: AnyObject {
    /// If true, logger only prints to console, never sends analytics. Used for previews/tests.
    var testMode: Bool { get set }

    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - event: The event name (should be localized if user-facing).
    ///   - parameters: Additional event metadata.
    ///   - role: Role from audit context.
    ///   - staffID: Staff ID from audit context.
    ///   - context: Context from audit context.
    ///   - escalate: Whether this event should trigger escalation.
    func log(
        event: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null implementation for safe use in previews, tests, and QA environments.
public final class NullSchedulingSuggestionAnalyticsLogger: SchedulingSuggestionAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            let paramsDesc = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            print("[SchedulingSuggestionEngine][TEST MODE] \(event) \(paramsDesc) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Default in-memory analytics logger. In production, inject a logger that sends events to analytics backend.
public final class InMemorySchedulingSuggestionAnalyticsLogger: SchedulingSuggestionAnalyticsLogger {
    public var testMode: Bool = false
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func log(
        event: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let paramsDesc = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
        let prefix = testMode ? "[TEST MODE]" : "[PROD]"
        print("[SchedulingSuggestionEngine]\(prefix) \(event) \(paramsDesc) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Main engine for generating scheduling suggestions with analytics, audit, diagnostics, and localization.
public final class SchedulingSuggestionEngine {
    /// The analytics logger, injected for extensibility and testability.
    private let analyticsLogger: SchedulingSuggestionAnalyticsLogger

    /// Capped buffer of last N analytics/audit events for diagnostics.
    private let eventBufferCapacity: Int = 20
    private var recentEvents: [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let bufferQueue = DispatchQueue(label: "SchedulingSuggestionEngine.EventBuffer", attributes: .concurrent)

    /// Initializes the engine.
    /// - Parameter analyticsLogger: The analytics logger to use. Defaults to Null logger (safe for previews/tests).
    public init(analyticsLogger: SchedulingSuggestionAnalyticsLogger = NullSchedulingSuggestionAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    /// Generates scheduling suggestions.
    /// - Parameters:
    ///   - context: Context for the suggestion (placeholder for extensibility).
    /// - Returns: Array of suggestions (stubbed).
    /// - Throws: May throw in future for error handling.
    public func generateSuggestions(context: [String: Any]? = nil) async throws -> [String] {
        let suggestionKey = "suggestion.sample"
        let suggestion = NSLocalizedString(
            suggestionKey,
            value: "Try scheduling in the afternoon for better availability.",
            comment: "Default scheduling suggestion shown to user"
        )
        await logAnalyticsEvent(
            eventKey: "event.suggestion.generated",
            eventValue: "Scheduling suggestion generated",
            parameters: ["context": context ?? [:]]
        )
        return [suggestion]
    }

    /// Logs an audit event (stub for Trust Center/audit compliance).
    /// - Parameters:
    ///   - messageKey: Localization key for audit message.
    ///   - messageValue: Default message value.
    ///   - parameters: Metadata for the event.
    public func auditLog(messageKey: String, messageValue: String, parameters: [String: Any]? = nil) async {
        let localized = NSLocalizedString(
            messageKey,
            value: messageValue,
            comment: "Audit log event for scheduling suggestion engine"
        )
        await logAnalyticsEvent(
            eventKey: "event.audit.log",
            eventValue: localized,
            parameters: parameters
        )
    }

    /// Provides diagnostics including recent analytics/audit events.
    /// - Returns: Diagnostics dictionary for admin/Trust Center.
    public func diagnostics() -> [String: Any] {
        var bufferCopy: [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
        bufferQueue.sync {
            bufferCopy = self.recentEvents
        }
        let diagnosticsKey = "diagnostics.engine.status"
        let diagnosticsMessage = NSLocalizedString(
            diagnosticsKey,
            value: "Engine diagnostics and recent events.",
            comment: "Diagnostics status message for scheduling suggestion engine"
        )
        return [
            "status": diagnosticsMessage,
            "recentEvents": bufferCopy.map { event in
                [
                    "date": event.date,
                    "event": event.event,
                    "parameters": event.parameters ?? [:],
                    "role": event.role as Any,
                    "staffID": event.staffID as Any,
                    "context": event.context as Any,
                    "escalate": event.escalate
                ] as [String : Any]
            }
        ]
    }

    /// Returns the last N analytics/audit events for admin/diagnostics.
    /// - Returns: Array of event dictionaries.
    public func recentAnalyticsEvents() -> [[String: Any]] {
        var bufferCopy: [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
        bufferQueue.sync {
            bufferCopy = self.recentEvents
        }
        return bufferCopy.map { event in
            [
                "date": event.date,
                "event": event.event,
                "parameters": event.parameters ?? [:],
                "role": event.role as Any,
                "staffID": event.staffID as Any,
                "context": event.context as Any,
                "escalate": event.escalate
            ]
        }
    }

    /// Internal helper to log analytics/audit events, localize, and update event buffer.
    private func logAnalyticsEvent(eventKey: String, eventValue: String, parameters: [String: Any]?) async {
        let localizedEvent = NSLocalizedString(
            eventKey,
            value: eventValue,
            comment: "Analytics or audit log event for scheduling suggestion engine"
        )
        let escalate = eventKey.lowercased().contains("danger") || eventKey.lowercased().contains("critical") || eventKey.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.log(
            event: localizedEvent,
            parameters: parameters,
            role: SchedulingSuggestionAuditContext.role,
            staffID: SchedulingSuggestionAuditContext.staffID,
            context: SchedulingSuggestionAuditContext.context,
            escalate: escalate
        )
        bufferQueue.async(flags: .barrier) {
            if self.recentEvents.count >= self.eventBufferCapacity {
                self.recentEvents.removeFirst(self.recentEvents.count - self.eventBufferCapacity + 1)
            }
            self.recentEvents.append((date: Date(), event: localizedEvent, parameters: parameters, role: SchedulingSuggestionAuditContext.role, staffID: SchedulingSuggestionAuditContext.staffID, context: SchedulingSuggestionAuditContext.context, escalate: escalate))
        }
    }
}

#if DEBUG
/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct SchedulingSuggestionEngine_Previews: PreviewProvider {
    static var previews: some View {
        SchedulingSuggestionEnginePreviewView()
            .previewDisplayName("SchedulingSuggestionEngine Diagnostics Preview")
            .environment(\.locale, Locale(identifier: "en"))
            .accessibilityElement(children: .contain)
    }

    struct SchedulingSuggestionEnginePreviewView: View {
        @StateObject private var viewModel = ViewModel()

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString(
                    "preview.title",
                    value: "Scheduling Suggestion Engine Diagnostics",
                    comment: "Title for preview diagnostics UI"
                ))
                    .font(.headline)
                    .accessibility(addTraits: .isHeader)
                Button(action: {
                    Task { await viewModel.generateTestSuggestion() }
                }) {
                    Text(NSLocalizedString(
                        "preview.generate.suggestion",
                        value: "Generate Test Suggestion",
                        comment: "Button to trigger test suggestion generation"
                    ))
                }
                .accessibilityLabel(NSLocalizedString(
                    "preview.generate.suggestion.accessibility",
                    value: "Generate a test scheduling suggestion",
                    comment: "Accessibility label for test suggestion button"
                ))
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.recentEvents, id: \.self) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event["event"] as? String ?? "")
                                    .font(.subheadline)
                                Text("\(event["date"] ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if let params = event["parameters"] as? [String: Any], !params.isEmpty {
                                    Text("Params: \(params.description)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("Role: \(event["role"] as? String ?? "-")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Staff ID: \(event["staffID"] as? String ?? "-")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Context: \(event["context"] as? String ?? "-")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Escalate: \((event["escalate"] as? Bool) == true ? "Yes" : "No")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .accessibilityLabel(NSLocalizedString(
                    "preview.recent.events.accessibility",
                    value: "Recent analytics and audit events",
                    comment: "Accessibility label for recent events section"
                ))
            }
            .padding()
        }

        class ViewModel: ObservableObject {
            @Published var recentEvents: [[String: Any]] = []
            private let engine: SchedulingSuggestionEngine
            init() {
                // Use in-memory logger with testMode ON for safe previewing
                let logger = InMemorySchedulingSuggestionAnalyticsLogger(testMode: true)
                self.engine = SchedulingSuggestionEngine(analyticsLogger: logger)
                self.refreshEvents()
            }
            func generateTestSuggestion() async {
                _ = try? await engine.generateSuggestions(context: ["preview": true])
                await engine.auditLog(
                    messageKey: "audit.preview.action",
                    messageValue: "Preview action for audit log",
                    parameters: ["preview": true]
                )
                self.refreshEvents()
            }
            func refreshEvents() {
                self.recentEvents = engine.recentAnalyticsEvents()
            }
        }
    }
}
#endif
