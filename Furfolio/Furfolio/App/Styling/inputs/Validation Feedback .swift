//
//  Validation Feedback .swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 Validation Feedback.swift

 This file implements the validation feedback architecture for Furfolio, designed with extensibility, analytics integration, diagnostics, localization, accessibility, and compliance in mind.

 Architecture:
 - Provides a modular ValidationFeedbackView SwiftUI component that displays validation state and messages.
 - Supports injection of an analytics logger conforming to ValidationFeedbackAnalyticsLogger protocol for audit and Trust Center hooks.

 Extensibility:
 - Analytics logger protocol supports async/await for modern concurrency.
 - Allows easy replacement or extension of analytics logger implementations.

 Analytics/Audit/Trust Center Hooks:
 - Logs validation feedback events asynchronously with detailed audit context.
 - Maintains a capped buffer of the last 20 events for diagnostics and admin review.

 Diagnostics:
 - Public API to fetch recent analytics events.
 - Null logger implementation for testing and previews.

 Localization:
 - All user-facing and log strings are localized using NSLocalizedString with explicit keys and comments.

 Accessibility:
 - Supports accessibilityLabel and accessibilityHint parameters for VoiceOver and other assistive technologies.

 Compliance:
 - Designed to meet audit and compliance requirements by providing detailed, localized, and accessible validation feedback with audit logging.

 Preview/Testability:
 - Includes a PreviewProvider demonstrating accessibility features, testMode analytics logging, and diagnostics.

 Future maintainers should extend or modify components with attention to concurrency safety, localization keys, accessibility compliance, and audit context propagation.
 */

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ValidationFeedbackAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ValidationFeedback"
}

/// Protocol defining an async/await-ready analytics logger for validation feedback events with audit context.
/// Conforming types should implement event logging and expose a testMode property for QA/test/preview console-only logging.
public protocol ValidationFeedbackAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Logs a validation feedback event asynchronously with detailed audit context.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - state: The validation state.
    ///   - message: The validation message.
    ///   - role: The user role from audit context.
    ///   - staffID: The staff ID from audit context.
    ///   - context: The audit context string.
    ///   - escalate: Flag indicating if the event should be escalated.
    func logEvent(
        _ event: String,
        state: ValidationState,
        message: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /// Returns recent logged analytics events for diagnostics or admin use.
    /// - Returns: Array of ValidationFeedbackAnalyticsEvent.
    func recentEvents() -> [ValidationFeedbackAnalyticsEvent]
}

/// Represents a detailed validation feedback analytics event with audit and escalation info.
public struct ValidationFeedbackAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let state: ValidationState
    public let message: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A null analytics logger implementation that performs no logging, intended for previews and tests.
public struct NullValidationFeedbackAnalyticsLogger: ValidationFeedbackAnalyticsLogger {
    public let testMode = true

    public init() {}

    public func logEvent(
        _ event: String,
        state: ValidationState,
        message: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
            ValidationFeedbackView [TestMode] logged event:
            event: \(event)
            state: \(state)
            message: \(message)
            role: \(role ?? "nil")
            staffID: \(staffID ?? "nil")
            context: \(context ?? "nil")
            escalate: \(escalate)
            """)
        }
    }

    public func recentEvents() -> [ValidationFeedbackAnalyticsEvent] {
        []
    }
}

/// Enum representing the validation state to display in ValidationFeedbackView.
public enum ValidationState {
    case valid
    case warning
    case error
}

/// A SwiftUI view that displays validation feedback with localized messages, accessibility support, and analytics logging with audit context.
///
/// - Parameters:
///   - state: The validation state to display (valid, warning, error).
///   - message: The localized feedback message to show.
///   - analyticsLogger: The injected analytics logger to record events.
///   - accessibilityLabel: Accessibility label for the feedback message.
///   - accessibilityHint: Accessibility hint for the feedback message.
public struct ValidationFeedbackView: View {
    @State private var eventBuffer: [ValidationFeedbackAnalyticsEvent] = []

    public let state: ValidationState
    public let message: LocalizedStringKey
    public let analyticsLogger: ValidationFeedbackAnalyticsLogger
    public let accessibilityLabel: String
    public let accessibilityHint: String

    private let maxBufferSize = 20

    /// Internal method to log an analytics event with audit context and update the capped buffer.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - state: The validation state.
    ///   - message: The validation message.
    private func logEvent(_ event: String, state: ValidationState, message: String) {
        let escalate = (state == .error) || message.lowercased().contains("critical")
        Task {
            await analyticsLogger.logEvent(
                event,
                state: state,
                message: message,
                role: ValidationFeedbackAuditContext.role,
                staffID: ValidationFeedbackAuditContext.staffID,
                context: ValidationFeedbackAuditContext.context,
                escalate: escalate
            )
            DispatchQueue.main.async {
                if eventBuffer.count >= maxBufferSize {
                    eventBuffer.removeFirst()
                }
                let newEvent = ValidationFeedbackAnalyticsEvent(
                    timestamp: Date(),
                    event: event,
                    state: state,
                    message: message,
                    role: ValidationFeedbackAuditContext.role,
                    staffID: ValidationFeedbackAuditContext.staffID,
                    context: ValidationFeedbackAuditContext.context,
                    escalate: escalate
                )
                eventBuffer.append(newEvent)
            }
        }
    }

    /// Public API to fetch recent logged analytics events for diagnostics or admin use.
    /// - Returns: An array of the most recent ValidationFeedbackAnalyticsEvent.
    public func recentEvents() -> [ValidationFeedbackAnalyticsEvent] {
        eventBuffer
    }

    public var body: some View {
        let stateDescription: String
        switch state {
        case .valid:
            stateDescription = NSLocalizedString("ValidationFeedback_ValidState", value: "Valid", comment: "Validation state description for valid")
        case .warning:
            stateDescription = NSLocalizedString("ValidationFeedback_WarningState", value: "Warning", comment: "Validation state description for warning")
        case .error:
            stateDescription = NSLocalizedString("ValidationFeedback_ErrorState", value: "Error", comment: "Validation state description for error")
        }

        let messageString = NSLocalizedString(message.key ?? "", comment: "")
        let eventString = String(
            format: NSLocalizedString(
                "ValidationFeedback_AnalyticsEvent",
                value: "Validation feedback shown: %@ - %@",
                comment: "Analytics event format: validation state and message"
            ),
            stateDescription,
            messageString
        )

        // Log the event when the view appears
        // Use onAppear to trigger logging once
        return Text(message)
            .foregroundColor(color(for: state))
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityHint(Text(accessibilityHint))
            .onAppear {
                logEvent(eventString, state: state, message: messageString)
            }
    }

    /// Returns the appropriate color for the validation state.
    /// - Parameter state: The validation state.
    /// - Returns: A Color representing the state.
    private func color(for state: ValidationState) -> Color {
        switch state {
        case .valid:
            return .green
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

/// PreviewProvider demonstrating ValidationFeedbackView usage with accessibility, testMode logging, and diagnostics including audit fields.
struct ValidationFeedbackView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var recentEvents: [ValidationFeedbackAnalyticsEvent] = []

        let analyticsLogger = NullValidationFeedbackAnalyticsLogger()

        var body: some View {
            VStack(spacing: 20) {
                ValidationFeedbackView(
                    state: .error,
                    message: LocalizedStringKey("ValidationFeedback_InvalidEmail"),
                    analyticsLogger: analyticsLogger,
                    accessibilityLabel: NSLocalizedString(
                        "ValidationFeedback_AccessibilityLabel",
                        value: "Validation Feedback",
                        comment: "Accessibility label for validation feedback view"
                    ),
                    accessibilityHint: NSLocalizedString(
                        "ValidationFeedback_AccessibilityHint",
                        value: "Indicates the validation state of the input",
                        comment: "Accessibility hint for validation feedback view"
                    )
                )

                Button(NSLocalizedString(
                    "ValidationFeedback_ShowRecentEvents",
                    value: "Show Recent Events",
                    comment: "Button title to show recent analytics events"
                )) {
                    recentEvents = analyticsLogger.recentEvents()
                }

                if !recentEvents.isEmpty {
                    Text(NSLocalizedString(
                        "ValidationFeedback_RecentEventsHeader",
                        value: "Recent Analytics Events:",
                        comment: "Header for recent analytics events list"
                    ))
                    ForEach(recentEvents) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Event: \(event.event)")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("State: \(String(describing: event.state))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Message: \(event.message)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Role: \(event.role ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("StaffID: \(event.staffID ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Context: \(event.context ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Escalate: \(event.escalate ? "Yes" : "No")")
                                .font(.caption2)
                                .foregroundColor(event.escalate ? .red : .green)
                            Text("Timestamp: \(event.timestamp)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text(NSLocalizedString(
                        "ValidationFeedback_NoRecentEvents",
                        value: "No recent analytics events.",
                        comment: "Message shown when there are no recent analytics events"
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("Validation Feedback Preview")
    }
}
