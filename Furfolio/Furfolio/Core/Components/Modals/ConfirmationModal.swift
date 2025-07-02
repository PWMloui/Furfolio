//
//  ConfirmationModal.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 ConfirmationModal.swift

 This file defines the `ConfirmationModal` SwiftUI view, designed to provide a reusable, accessible, and localizable confirmation dialog component across the Furfolio app. It includes a comprehensive architecture that supports extensibility, analytics logging, diagnostics, and compliance considerations.

 Architecture & Extensibility:
 - The core `ConfirmationModal` view accepts customizable parameters for titles, messages, button labels, and actions, enabling flexible reuse.
 - Analytics logging is abstracted via the `ConfirmationModalAnalyticsLogger` protocol, supporting async/await for modern concurrency.
 - A null analytics logger implementation is provided for testing, previews, and QA environments.
 - The event logging buffer stores the most recent 20 analytics events for diagnostics and audit purposes.

 Analytics / Audit / Trust Center Hooks:
 - All user interactions (confirm/cancel) are logged asynchronously via the injected analytics logger.
 - Events include localized strings to ensure consistent audit trails.
 - A public API exposes recent analytics events for admin or diagnostic inspection.

 Diagnostics:
 - Includes an internal capped buffer to hold recent analytics events.
 - Events can be fetched programmatically to assist with troubleshooting and monitoring.

 Localization:
 - All user-facing strings and analytics event messages utilize `NSLocalizedString` with explicit keys and comments for translators.
 - Supports accessibility labels and hints for VoiceOver and other assistive technologies.

 Accessibility:
 - Accessibility modifiers are applied to buttons and modal elements.
 - Accessibility labels and hints are customizable via parameters.

 Compliance:
 - Designed with privacy and compliance in mind, analytics logging can be disabled or replaced with no-op implementations.
 - Localized and accessible UI ensures compliance with internationalization and accessibility standards.

 Preview / Testability:
 - Includes a SwiftUI `PreviewProvider` demonstrating usage with accessibility labels, testMode analytics logger, and diagnostics.
 - The `NullConfirmationModalAnalyticsLogger` facilitates testing without external dependencies.

 Future maintainers should ensure that any changes maintain the async/await concurrency model for analytics logging, preserve localization keys, and update the diagnostics buffer accordingly.

*/

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ConfirmationModalAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ConfirmationModal"
}

/// Protocol defining the analytics logger interface for ConfirmationModal.
/// Supports async logging and a `testMode` flag for console-only logging during QA, tests, and previews.
public protocol ConfirmationModalAnalyticsLogger {
    /// Indicates if the logger is operating in test mode (console-only logging).
    var testMode: Bool { get }

    /**
     Asynchronously logs an analytics event.

     - Parameters:
       - event: The event string to log, localized.
       - role: The role of the user/session.
       - staffID: The staff ID associated with the user/session.
       - context: The context of the event.
       - escalate: Whether the event is critical and should be escalated.
     */
    func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-operation analytics logger for use in previews, tests, and QA environments.
/// Does not send events to any backend, only optionally prints to console if testMode is true.
public struct NullConfirmationModalAnalyticsLogger: ConfirmationModalAnalyticsLogger {
    public let testMode: Bool

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    public func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
                NullConfirmationModalAnalyticsLogger (testMode) event logged:
                Event: \(event)
                Role: \(role ?? "nil")
                StaffID: \(staffID ?? "nil")
                Context: \(context ?? "nil")
                Escalate: \(escalate)
                """)
        }
        // No-op for production or test environments without backend connectivity.
    }
}

/// A SwiftUI view that presents a customizable confirmation modal dialog.
/// Supports async analytics logging, localization, accessibility, and diagnostics.
public struct ConfirmationModal: View {
    // MARK: - Public Properties

    /// The title displayed at the top of the modal.
    public let title: String

    /// The message body displayed below the title.
    public let message: String

    /// The label for the confirm button.
    public let confirmButtonLabel: String

    /// The label for the cancel button.
    public let cancelButtonLabel: String

    /// Closure executed when the confirm button is tapped.
    public let onConfirm: () -> Void

    /// Closure executed when the cancel button is tapped.
    public let onCancel: () -> Void

    /// The analytics logger instance to track user actions.
    public let analyticsLogger: ConfirmationModalAnalyticsLogger

    /// Accessibility label for the modal container.
    public let accessibilityLabel: String?

    /// Accessibility hint for the modal container.
    public let accessibilityHint: String?

    // MARK: - Private State

    /// Internal buffer to keep track of recent analytics events (capped at 20).
    @State private var recentEvents: [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

    // MARK: - Initialization

    /**
     Creates a new ConfirmationModal instance.

     - Parameters:
       - title: The modal title.
       - message: The modal message.
       - confirmButtonLabel: Label for the confirm button.
       - cancelButtonLabel: Label for the cancel button.
       - onConfirm: Action executed on confirm.
       - onCancel: Action executed on cancel.
       - analyticsLogger: Analytics logger instance.
       - accessibilityLabel: Accessibility label for the modal.
       - accessibilityHint: Accessibility hint for the modal.
     */
    public init(
        title: String,
        message: String,
        confirmButtonLabel: String,
        cancelButtonLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsLogger: ConfirmationModalAnalyticsLogger = NullConfirmationModalAnalyticsLogger(),
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmButtonLabel = confirmButtonLabel
        self.cancelButtonLabel = cancelButtonLabel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)

            HStack {
                Button {
                    Task {
                        let actionName = NSLocalizedString("ConfirmationModal_CancelAction", value: "Cancel", comment: "Cancel action analytics event")
                        await logAndPerform(actionName: actionName)
                        onCancel()
                    }
                } label: {
                    Text(cancelButtonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(cancelButtonLabel)
                .accessibilityHint(NSLocalizedString("ConfirmationModal_CancelHint", value: "Cancels and closes the confirmation dialog", comment: "Accessibility hint for cancel button"))

                Button {
                    Task {
                        let actionName = NSLocalizedString("ConfirmationModal_ConfirmAction", value: "Confirm", comment: "Confirm action analytics event")
                        await logAndPerform(actionName: actionName)
                        onConfirm()
                    }
                } label: {
                    Text(confirmButtonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(confirmButtonLabel)
                .accessibilityHint(NSLocalizedString("ConfirmationModal_ConfirmHint", value: "Confirms the action", comment: "Accessibility hint for confirm button"))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Private Methods

    /// Logs the given action asynchronously and updates the internal diagnostics buffer.
    private func logAndPerform(actionName: String) async {
        let role = ConfirmationModalAuditContext.role
        let staffID = ConfirmationModalAuditContext.staffID
        let context = ConfirmationModalAuditContext.context
        let lowercasedAction = actionName.lowercased()
        let escalate = lowercasedAction.contains("danger") || lowercasedAction.contains("critical") || lowercasedAction.contains("delete")
        await analyticsLogger.logEvent(actionName, role: role, staffID: staffID, context: context, escalate: escalate)
        await MainActor.run {
            addEventToBuffer((event: actionName, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date()))
        }
    }

    /// Adds a new event to the capped diagnostics buffer.
    private func addEventToBuffer(_ eventTuple: (event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)) {
        recentEvents.append(eventTuple)
        if recentEvents.count > 20 {
            recentEvents.removeFirst()
        }
    }

    // MARK: - Public Diagnostics API

    /**
     Retrieves the most recent analytics events logged by this modal.

     - Returns: An array of the last 20 analytics event tuples.
     */
    public func getRecentAnalyticsEvents() -> [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] {
        recentEvents
    }
}

// MARK: - PreviewProvider

struct ConfirmationModal_Previews: PreviewProvider {
    /// A test analytics logger that prints events to the console.
    struct TestAnalyticsLogger: ConfirmationModalAnalyticsLogger {
        let testMode = true

        func logEvent(
            _ event: String,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            print("""
                TestAnalyticsLogger event:
                Event: \(event)
                Role: \(role ?? "nil")
                StaffID: \(staffID ?? "nil")
                Context: \(context ?? "nil")
                Escalate: \(escalate)
                """)
        }
    }

    static var previews: some View {
        ConfirmationModal(
            title: NSLocalizedString("ConfirmationModal_Preview_Title", value: "Delete Item", comment: "Preview title"),
            message: NSLocalizedString("ConfirmationModal_Preview_Message", value: "Are you sure you want to delete this item? This action cannot be undone.", comment: "Preview message"),
            confirmButtonLabel: NSLocalizedString("ConfirmationModal_Preview_ConfirmButton", value: "Delete", comment: "Preview confirm button"),
            cancelButtonLabel: NSLocalizedString("ConfirmationModal_Preview_CancelButton", value: "Cancel", comment: "Preview cancel button"),
            onConfirm: {
                print("Confirmed action in preview")
            },
            onCancel: {
                print("Cancelled action in preview")
            },
            analyticsLogger: TestAnalyticsLogger(),
            accessibilityLabel: NSLocalizedString("ConfirmationModal_Preview_AccessibilityLabel", value: "Delete confirmation dialog", comment: "Accessibility label for preview modal"),
            accessibilityHint: NSLocalizedString("ConfirmationModal_Preview_AccessibilityHint", value: "Asks to confirm deletion of an item", comment: "Accessibility hint for preview modal")
        )
        .padding()
        .previewDisplayName("ConfirmationModal Preview with Accessibility & TestMode")
    }
}
