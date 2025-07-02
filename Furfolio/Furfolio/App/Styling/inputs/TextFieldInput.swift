//
//  TextFieldInput.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TextFieldInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TextFieldInput"
}

/**
 TextFieldInput.swift

 Architecture:
 - A modular and extensible SwiftUI component for text input with icon support.
 - Designed with async/await-ready analytics logging to enable seamless integration with backend or local audit systems.
 - Implements a capped event buffer for diagnostics and admin review.
 
 Extensibility:
 - Analytics logger is injected via protocol to allow custom implementations.
 - Localization-ready strings for all user-facing and log event texts.
 - Accessibility labels and hints can be customized to support VoiceOver and other assistive technologies.

 Analytics/Audit/Trust Center Hooks:
 - TextFieldInputAnalyticsLogger protocol supports async logging of user interactions with detailed audit context.
 - Test mode flag enables console-only logging for QA, tests, and previews.
 - Null logger implementation provided for preview/test isolation.

 Diagnostics:
 - Maintains an internal capped buffer of last 20 analytics events including audit details.
 - Public API to fetch recent events for diagnostics or admin review.

 Localization:
 - All strings wrapped with NSLocalizedString with descriptive keys and comments for translators.

 Accessibility:
 - Supports accessibilityLabel and accessibilityHint parameters for enhanced usability.

 Compliance:
 - Designed to support audit trails for compliance requirements via async analytics logging with rich context.
 
 Preview/Testability:
 - Includes a PreviewProvider demonstrating accessibility, test mode logging, and diagnostics.

*/

/// Protocol defining an async/await-ready analytics logger for TextFieldInput component with audit context.
public protocol TextFieldInputAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Logs an analytics event asynchronously with detailed audit context.
    /// - Parameters:
    ///   - event: The event string to be logged.
    ///   - textSnapshot: Current text snapshot at event time.
    ///   - role: User role from audit context.
    ///   - staffID: Staff ID from audit context.
    ///   - context: Context string from audit context.
    ///   - escalate: Flag indicating if event should be escalated.
    func logEvent(
        _ event: String,
        textSnapshot: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /// Returns recent analytics events for diagnostics or admin review.
    func recentEvents() -> [TextFieldInputAnalyticsEvent]
}

/// Struct representing a detailed analytics event with audit context.
public struct TextFieldInputAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let textSnapshot: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A Null analytics logger that performs no operations, used for previews and tests.
public struct NullTextFieldInputAnalyticsLogger: TextFieldInputAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ event: String,
        textSnapshot: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[TextFieldInput Analytics] Event: \(event)")
            print("  Text Snapshot: \(textSnapshot)")
            print("  Role: \(role ?? "nil")")
            print("  Staff ID: \(staffID ?? "nil")")
            print("  Context: \(context ?? "nil")")
            print("  Escalate: \(escalate)")
        }
        // No-op for previews/tests
    }

    public func recentEvents() -> [TextFieldInputAnalyticsEvent] {
        []
    }
}

/// A SwiftUI view representing a text field input with optional icon and integrated analytics logging with audit support.
public struct TextFieldInput: View {
    // MARK: - Properties

    /// Binding to the text input value.
    @Binding public var text: String

    /// Placeholder string displayed when the text field is empty.
    public let placeholder: String

    /// Optional icon image displayed alongside the text field.
    public let icon: Image?

    /// Analytics logger injected for event tracking with audit context.
    public let analyticsLogger: TextFieldInputAnalyticsLogger

    /// Accessibility label for the text field.
    public let accessibilityLabel: String

    /// Accessibility hint for the text field.
    public let accessibilityHint: String

    /// Internal buffer to store recent analytics events (capped at 20) with audit details.
    @State private var analyticsEventBuffer: [TextFieldInputAnalyticsEvent] = []

    // MARK: - Initializer

    /// Initializes a new TextFieldInput view.
    /// - Parameters:
    ///   - text: Binding to the input text.
    ///   - placeholder: Placeholder text.
    ///   - icon: Optional icon image.
    ///   - analyticsLogger: Analytics logger instance.
    ///   - accessibilityLabel: Accessibility label string.
    ///   - accessibilityHint: Accessibility hint string.
    public init(
        text: Binding<String>,
        placeholder: String = NSLocalizedString("TextFieldInput.Placeholder", value: "Enter text", comment: "Placeholder text for text field input"),
        icon: Image? = nil,
        analyticsLogger: TextFieldInputAnalyticsLogger = NullTextFieldInputAnalyticsLogger(),
        accessibilityLabel: String = NSLocalizedString("TextFieldInput.Accessibility.Label", value: "Text input field", comment: "Accessibility label for text field input"),
        accessibilityHint: String = NSLocalizedString("TextFieldInput.Accessibility.Hint", value: "Input text here", comment: "Accessibility hint for text field input")
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    // MARK: - Body

    public var body: some View {
        HStack {
            if let icon = icon {
                icon
                    .accessibilityHidden(true)
            }
            TextField(placeholder, text: $text, onEditingChanged: { began in
                Task {
                    await logEditingChanged(began: began)
                }
            })
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityHint(Text(accessibilityHint))
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary, lineWidth: 1)
        )
    }

    // MARK: - Analytics Logging

    /// Logs editing began/ended events asynchronously with audit context.
    /// - Parameter began: Boolean indicating if editing began (true) or ended (false).
    private func logEditingChanged(began: Bool) async {
        let eventKey = began ? "TextFieldInput.Event.EditingBegan" : "TextFieldInput.Event.EditingEnded"
        let eventValue = NSLocalizedString(eventKey, value: began ? "Editing began" : "Editing ended", comment: "User editing state change event")
        let lowercasedEvent = eventValue.lowercased()
        let escalate = lowercasedEvent.contains("danger") || lowercasedEvent.contains("delete") || lowercasedEvent.contains("critical")
        await logEvent(eventValue, textSnapshot: text, escalate: escalate)
    }

    /// Logs a generic event asynchronously with audit context, updating the buffer and forwarding to the analytics logger.
    /// - Parameters:
    ///   - event: Event description string.
    ///   - textSnapshot: Current text snapshot.
    ///   - escalate: Flag indicating if event should be escalated.
    private func logEvent(_ event: String, textSnapshot: String, escalate: Bool) async {
        let auditEvent = TextFieldInputAnalyticsEvent(
            timestamp: Date(),
            event: event,
            textSnapshot: textSnapshot,
            role: TextFieldInputAuditContext.role,
            staffID: TextFieldInputAuditContext.staffID,
            context: TextFieldInputAuditContext.context,
            escalate: escalate
        )
        DispatchQueue.main.async {
            // Append event to buffer, capping at 20 events
            analyticsEventBuffer.append(auditEvent)
            if analyticsEventBuffer.count > 20 {
                analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - 20)
            }
        }
        if analyticsLogger.testMode {
            print("[TextFieldInput Analytics] Event: \(auditEvent.event)")
            print("  Timestamp: \(auditEvent.timestamp)")
            print("  Text Snapshot: \(auditEvent.textSnapshot)")
            print("  Role: \(auditEvent.role ?? "nil")")
            print("  Staff ID: \(auditEvent.staffID ?? "nil")")
            print("  Context: \(auditEvent.context ?? "nil")")
            print("  Escalate: \(auditEvent.escalate)")
        }
        await analyticsLogger.logEvent(
            auditEvent.event,
            textSnapshot: auditEvent.textSnapshot,
            role: auditEvent.role,
            staffID: auditEvent.staffID,
            context: auditEvent.context,
            escalate: auditEvent.escalate
        )
    }

    // MARK: - Public API

    /// Returns the most recent analytics events (up to 20) with full audit context.
    /// - Returns: Array of detailed analytics events.
    public func recentAnalyticsEvents() -> [TextFieldInputAnalyticsEvent] {
        analyticsEventBuffer
    }
}

// MARK: - Preview

struct TextFieldInput_Previews: PreviewProvider {
    struct TestLogger: TextFieldInputAnalyticsLogger {
        let testMode: Bool = true
        private var events: [TextFieldInputAnalyticsEvent] = []

        func logEvent(
            _ event: String,
            textSnapshot: String,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            // Simulate async logging with delay
            try? await Task.sleep(nanoseconds: 100_000_000)
            print("[TestLogger] Logged event: \(event)")
            print("  Text Snapshot: \(textSnapshot)")
            print("  Role: \(role ?? "nil")")
            print("  Staff ID: \(staffID ?? "nil")")
            print("  Context: \(context ?? "nil")")
            print("  Escalate: \(escalate)")
        }

        func recentEvents() -> [TextFieldInputAnalyticsEvent] {
            []
        }
    }

    static var previews: some View {
        VStack(spacing: 20) {
            TextFieldInput(
                text: .constant(""),
                placeholder: NSLocalizedString("TextFieldInput.Placeholder", value: "Enter your name", comment: "Placeholder for name input"),
                icon: Image(systemName: "person.fill"),
                analyticsLogger: TestLogger(),
                accessibilityLabel: NSLocalizedString("TextFieldInput.Accessibility.Label.Name", value: "Name input field", comment: "Accessibility label for name input"),
                accessibilityHint: NSLocalizedString("TextFieldInput.Accessibility.Hint.Name", value: "Enter your full name here", comment: "Accessibility hint for name input")
            )
            .padding()

            Text("Recent Analytics Events:")
                .font(.headline)
            List {
                ForEach(TextFieldInput(text: .constant("")).recentAnalyticsEvents()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event: \(event.event)")
                            .fontWeight(.bold)
                        Text("Timestamp: \(event.timestamp.description)")
                        Text("Text Snapshot: \(event.textSnapshot)")
                        Text("Role: \(event.role ?? "nil")")
                        Text("Staff ID: \(event.staffID ?? "nil")")
                        Text("Context: \(event.context ?? "nil")")
                        Text("Escalate: \(event.escalate ? "Yes" : "No")")
                    }
                    .padding(4)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .previewDisplayName("TextFieldInput Preview with Accessibility & Diagnostics")
    }
}
