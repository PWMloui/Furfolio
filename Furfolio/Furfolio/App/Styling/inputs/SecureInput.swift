//
//  SecureInput.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 SecureInput.swift

 Architecture:
 - Implements a reusable, extensible SwiftUI SecureInput component for secure text entry.
 - Designed for easy integration with analytics, accessibility, localization, and compliance needs.
 - Uses dependency injection for analytics logging to support different environments (production, testing, previews).

 Extensibility:
 - Analytics logging is abstracted via the SecureInputAnalyticsLogger protocol allowing custom implementations.
 - Supports optional icon display alongside the secure text field.
 - Accessibility labels and hints are customizable for improved screen reader support.
 - Localization-ready strings for all user-facing content and analytics events.

 Analytics/Audit/Trust Center Hooks:
 - Logs user interactions asynchronously using the async/await-ready SecureInputAnalyticsLogger protocol.
 - Supports test mode for console-only logging during QA, tests, and SwiftUI previews.
 - Maintains a capped buffer of the last 20 analytics events for diagnostics and administrative review.
 - Includes audit context fields (role, staffID, context) set at login/session for trust center compliance.

 Diagnostics:
 - Provides a public API to fetch recent logged analytics events.
 - Includes detailed doc-comments for maintainers to understand and extend diagnostics and logging.

 Localization:
 - All user-facing strings and analytics event descriptions are wrapped with NSLocalizedString for localization support.

 Accessibility:
 - Exposes accessibilityLabel and accessibilityHint parameters to improve VoiceOver experience.
 - Designed with accessibility best practices for secure input fields.

 Compliance:
 - Ensures secure input handling without exposing sensitive text in logs.
 - Analytics events do not contain raw input but describe user actions, augmented with audit context.
 - Escalates events containing critical keywords for audit review.

 Preview/Testability:
 - Includes a NullSecureInputAnalyticsLogger for use in previews and tests to suppress real logging.
 - PreviewProvider demonstrates accessibility, test mode, and diagnostics in action.

 Future Maintainers:
 - Refer to the SecureInputAnalyticsLogger protocol to implement custom analytics handlers.
 - Use the recentEvents API for diagnostics integration.
 - Extend localization keys and accessibility parameters as needed.

*/

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SecureInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SecureInput"
}

/// Protocol defining an async/await-ready analytics logger for SecureInput component with audit context.
/// Implementations can log events asynchronously and indicate if they are running in test mode.
public protocol SecureInputAnalyticsLogger {
    /// Indicates if logger is running in test mode (e.g., previews, QA).
    /// Defaults to false.
    var testMode: Bool { get }

    /// Logs an analytics event asynchronously with audit context and escalation flag.
    /// - Parameters:
    ///   - event: The event description to log.
    ///   - role: The role of the user/session.
    ///   - staffID: The staff ID associated with the session.
    ///   - context: Context string for the event.
    ///   - escalate: Boolean flag indicating if the event should be escalated for audit.
    func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /// Returns recent logged analytics events for diagnostics or audit review.
    func recentEvents() -> [SecureInputAnalyticsEvent]
}

/// Struct representing a single analytics event with audit context and escalation flag.
public struct SecureInputAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A no-op analytics logger for use in previews, tests, or when analytics should be disabled.
/// Logs events to console only if testMode is true, printing all audit fields.
public struct NullSecureInputAnalyticsLogger: SecureInputAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
                NullSecureInputAnalyticsLogger event:
                event: \(event)
                role: \(role ?? "nil")
                staffID: \(staffID ?? "nil")
                context: \(context ?? "nil")
                escalate: \(escalate)
                """)
        }
    }

    public func recentEvents() -> [SecureInputAnalyticsEvent] {
        []
    }
}

/// A SwiftUI view representing a secure text input with optional icon, localization, accessibility, and analytics.
///
/// - Parameters:
///   - text: Binding to the secure text input string.
///   - placeholder: Placeholder text shown when input is empty.
///   - icon: Optional image to display alongside the input field.
///   - analyticsLogger: Analytics logger injected for event tracking.
///   - accessibilityLabel: Accessibility label for the secure input field.
///   - accessibilityHint: Accessibility hint describing the input field.
public struct SecureInput: View {
    @Binding private var text: String
    private let placeholder: String
    private let icon: Image?
    private let analyticsLogger: SecureInputAnalyticsLogger
    private let accessibilityLabel: String
    private let accessibilityHint: String

    /// Internal buffer to store recent analytics events with audit context, capped at 20 entries.
    @State private var recentEvents: [SecureInputAnalyticsEvent] = []

    /// Initializes a SecureInput view.
    /// - Parameters:
    ///   - text: Binding to the secure text input string.
    ///   - placeholder: Localized placeholder string.
    ///   - icon: Optional icon image.
    ///   - analyticsLogger: Analytics logger instance.
    ///   - accessibilityLabel: Localized accessibility label.
    ///   - accessibilityHint: Localized accessibility hint.
    public init(
        text: Binding<String>,
        placeholder: String = NSLocalizedString("SecureInput.Placeholder", value: "Enter secure text", comment: "Placeholder for secure input field"),
        icon: Image? = nil,
        analyticsLogger: SecureInputAnalyticsLogger = NullSecureInputAnalyticsLogger(),
        accessibilityLabel: String = NSLocalizedString("SecureInput.AccessibilityLabel", value: "Secure input field", comment: "Accessibility label for secure input"),
        accessibilityHint: String = NSLocalizedString("SecureInput.AccessibilityHint", value: "Double tap to enter secure text", comment: "Accessibility hint for secure input")
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        HStack {
            if let icon = icon {
                icon
                    .accessibilityHidden(true)
            }
            SecureField(placeholder, text: $text)
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityHint(Text(accessibilityHint))
                .onChange(of: text) { newValue in
                    Task {
                        let event = NSLocalizedString(
                            "SecureInput.Event.TextChanged",
                            value: "User changed secure input text",
                            comment: "Analytics event when user changes secure input text"
                        )
                        await logEvent(event)
                    }
                }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary, lineWidth: 1)
        )
    }

    /// Logs an analytics event with audit context and escalation logic, updates the recent events buffer.
    /// - Parameter event: The event description to log.
    private func logEvent(_ event: String) async {
        let lowercasedEvent = event.lowercased()
        let escalate = lowercasedEvent.contains("danger") || lowercasedEvent.contains("delete") || lowercasedEvent.contains("critical")
        let auditEvent = SecureInputAnalyticsEvent(
            timestamp: Date(),
            event: event,
            role: SecureInputAuditContext.role,
            staffID: SecureInputAuditContext.staffID,
            context: SecureInputAuditContext.context,
            escalate: escalate
        )
        await analyticsLogger.logEvent(
            event,
            role: auditEvent.role,
            staffID: auditEvent.staffID,
            context: auditEvent.context,
            escalate: escalate
        )
        await MainActor.run {
            recentEvents.append(auditEvent)
            if recentEvents.count > 20 {
                recentEvents.removeFirst()
            }
        }
    }

    /// Public API to fetch recent analytics events with audit context for diagnostics or administrative review.
    /// - Returns: Array of recent SecureInputAnalyticsEvent structs.
    public func getRecentEvents() -> [SecureInputAnalyticsEvent] {
        recentEvents
    }
}

/// Preview provider demonstrating SecureInput with accessibility, test mode, and diagnostics.
struct SecureInput_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var inputText: String = ""
        @State private var showEvents: Bool = false

        // Use NullSecureInputAnalyticsLogger to enable testMode console logging.
        private let logger = NullSecureInputAnalyticsLogger()

        var body: some View {
            VStack(spacing: 20) {
                SecureInput(
                    text: $inputText,
                    placeholder: NSLocalizedString("SecureInput.Placeholder", value: "Enter your password", comment: "Placeholder for password input"),
                    icon: Image(systemName: "lock.fill"),
                    analyticsLogger: logger,
                    accessibilityLabel: NSLocalizedString("SecureInput.AccessibilityLabel", value: "Password field", comment: "Accessibility label for password input"),
                    accessibilityHint: NSLocalizedString("SecureInput.AccessibilityHint", value: "Double tap to enter your password", comment: "Accessibility hint for password input")
                )
                .padding()

                Button {
                    showEvents.toggle()
                } label: {
                    Text(NSLocalizedString("SecureInput.Button.ShowEvents", value: "Show Recent Events", comment: "Button label to show recent analytics events"))
                }

                if showEvents {
                    if logger.testMode {
                        List(["Test mode enabled - events logged to console only"], id: \.self) { event in
                            Text(event)
                        }
                    } else {
                        List(logger.recentEvents()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Event: \(event.event)")
                                Text("Role: \(event.role ?? "nil")")
                                Text("Staff ID: \(event.staffID ?? "nil")")
                                Text("Context: \(event.context ?? "nil")")
                                Text("Escalate: \(event.escalate ? "Yes" : "No")")
                                Text("Timestamp: \(event.timestamp.description)")
                            }
                            .font(.footnote)
                            .padding(4)
                        }
                    }
                }
            }
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("SecureInput Preview with Test Mode & Accessibility")
    }
}
