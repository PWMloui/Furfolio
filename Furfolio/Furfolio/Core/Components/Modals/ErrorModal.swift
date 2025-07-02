//
//  ErrorModal.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ErrorModalAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ErrorModal"
}

/**
 `ErrorModal.swift` defines a reusable, extensible SwiftUI component for displaying error modals within the Furfolio app.

 ## Architecture
 The `ErrorModal` view is designed to be modular and easily integrated into existing SwiftUI workflows. It accepts customizable titles, messages, and button labels/actions, supporting asynchronous analytics logging via a protocol-based logger.

 ## Extensibility
 - Analytics logging is abstracted via the `ErrorModalAnalyticsLogger` protocol, allowing custom implementations.
 - Localization is supported through `NSLocalizedString` keys for all user-facing strings.
 - Accessibility is prioritized by exposing configurable accessibility labels and hints.

 ## Analytics, Audit & Trust Center Hooks
 - The `ErrorModalAnalyticsLogger` protocol supports async/await logging for modern concurrency.
 - A capped in-memory event buffer stores the last 20 analytics events for diagnostics and auditing.
 - The `NullErrorModalAnalyticsLogger` provides a no-op logger for previews and tests, with an optional `testMode` flag for console-only logging.

 ## Diagnostics & Localization
 - All strings used in UI and analytics events are localized with descriptive keys and comments.
 - The event buffer enables retrieval of recent analytics events for diagnostics or Trust Center review.

 ## Accessibility
 - Accessibility labels and hints are customizable to support VoiceOver and other assistive technologies.
 - The modal’s buttons and text fields are configured with accessibility traits for clarity.

 ## Compliance
 - The component supports audit trails through event logging.
 - Localization and accessibility considerations help meet compliance standards.

 ## Preview & Testability
 - A comprehensive `PreviewProvider` demonstrates usage with accessibility, test mode logging, and diagnostic event retrieval.
 - The analytics logger protocol and null logger facilitate unit testing and UI preview scenarios.

---

*/

/// Protocol defining async analytics logging for `ErrorModal`.
/// - Supports `testMode` for console-only logging during QA, tests, and previews.
public protocol ErrorModalAnalyticsLogger {
    /// Indicates if the logger is operating in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an analytics event related to the error modal.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - role: The role of the user/session.
    ///   - staffID: The staff ID of the user/session.
    ///   - context: Context string for the event.
    ///   - escalate: Whether the event should be escalated.
    func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// No-op analytics logger for previews and tests.
/// Logs to console only if `testMode` is true.
public struct NullErrorModalAnalyticsLogger: ErrorModalAnalyticsLogger {
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
            print("[NullErrorModalAnalyticsLogger] Event: \(event)")
            print("  Role: \(role ?? "nil")")
            print("  StaffID: \(staffID ?? "nil")")
            print("  Context: \(context ?? "nil")")
            print("  Escalate: \(escalate)")
        }
        // No-op for production or non-test mode.
    }
}

/// SwiftUI view representing an error modal with analytics and accessibility support.
public struct ErrorModal: View {
    // MARK: - Parameters

    /// Title text of the error modal (localized).
    public let title: String

    /// Detailed message text of the error modal (localized).
    public let message: String

    /// Label for the primary action button (localized).
    public let primaryButtonLabel: String

    /// Label for the secondary action button (localized).
    public let secondaryButtonLabel: String?

    /// Closure executed when the primary button is tapped.
    public let primaryAction: () -> Void

    /// Closure executed when the secondary button is tapped.
    public let secondaryAction: (() -> Void)?

    /// Analytics logger injected to capture modal-related events.
    public var analyticsLogger: ErrorModalAnalyticsLogger

    /// Accessibility label for the modal container.
    public let accessibilityLabel: String?

    /// Accessibility hint for the modal container.
    public let accessibilityHint: String?

    // MARK: - Internal State

    /// Static buffer to hold last 20 analytics events for diagnostics.
    private static var analyticsEventBuffer: [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

    /// Serial queue to synchronize access to analyticsEventBuffer.
    private static let bufferQueue = DispatchQueue(label: "ErrorModal.analyticsEventBufferQueue")

    // MARK: - Initialization

    /// Initializes a new `ErrorModal` instance.
    /// - Parameters:
    ///   - title: Localized title string.
    ///   - message: Localized message string.
    ///   - primaryButtonLabel: Localized label for primary button.
    ///   - secondaryButtonLabel: Optional localized label for secondary button.
    ///   - primaryAction: Closure for primary button tap.
    ///   - secondaryAction: Optional closure for secondary button tap.
    ///   - analyticsLogger: Analytics logger instance.
    ///   - accessibilityLabel: Optional accessibility label.
    ///   - accessibilityHint: Optional accessibility hint.
    public init(
        title: String,
        message: String,
        primaryButtonLabel: String,
        secondaryButtonLabel: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil,
        analyticsLogger: ErrorModalAnalyticsLogger = NullErrorModalAnalyticsLogger(),
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonLabel = primaryButtonLabel
        self.secondaryButtonLabel = secondaryButtonLabel
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let secondaryLabel = secondaryButtonLabel,
                   let secondaryAction = secondaryAction {
                    Button {
                        Task {
                            let event = NSLocalizedString("ErrorModal.secondaryButtonTapped", value: "Secondary button tapped", comment: "Analytics event when secondary button is tapped")
                            let eventLower = event.lowercased()
                            let escalate = eventLower.contains("danger") || eventLower.contains("critical") || eventLower.contains("delete")
                            await logAnalyticsEvent(
                                event,
                                role: ErrorModalAuditContext.role,
                                staffID: ErrorModalAuditContext.staffID,
                                context: ErrorModalAuditContext.context,
                                escalate: escalate
                            )
                        }
                        secondaryAction()
                    } label: {
                        Text(secondaryLabel)
                    }
                    .accessibilityLabel(secondaryLabel)
                    .accessibilityHint(NSLocalizedString("ErrorModal.secondaryButtonHint", value: "Activates secondary action", comment: "Accessibility hint for secondary button"))
                }

                Button {
                    Task {
                        let event = NSLocalizedString("ErrorModal.primaryButtonTapped", value: "Primary button tapped", comment: "Analytics event when primary button is tapped")
                        let eventLower = event.lowercased()
                        let escalate = eventLower.contains("danger") || eventLower.contains("critical") || eventLower.contains("delete")
                        await logAnalyticsEvent(
                            event,
                            role: ErrorModalAuditContext.role,
                            staffID: ErrorModalAuditContext.staffID,
                            context: ErrorModalAuditContext.context,
                            escalate: escalate
                        )
                    }
                    primaryAction()
                } label: {
                    Text(primaryButtonLabel)
                        .bold()
                }
                .accessibilityLabel(primaryButtonLabel)
                .accessibilityHint(NSLocalizedString("ErrorModal.primaryButtonHint", value: "Activates primary action", comment: "Accessibility hint for primary button"))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint)
        .onAppear {
            Task {
                let event = NSLocalizedString("ErrorModal.appeared", value: "Error modal appeared", comment: "Analytics event when error modal appears")
                let eventLower = event.lowercased()
                let escalate = eventLower.contains("danger") || eventLower.contains("critical") || eventLower.contains("delete")
                await logAnalyticsEvent(
                    event,
                    role: ErrorModalAuditContext.role,
                    staffID: ErrorModalAuditContext.staffID,
                    context: ErrorModalAuditContext.context,
                    escalate: escalate
                )
            }
        }
    }

    // MARK: - Analytics Event Buffer Management

    /// Logs an analytics event asynchronously and appends it to the capped buffer.
    /// - Parameters:
    ///   - event: Event string to log.
    ///   - role: Role string for audit.
    ///   - staffID: Staff ID string for audit.
    ///   - context: Context string for audit.
    ///   - escalate: Whether to escalate this event.
    private func logAnalyticsEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        await analyticsLogger.logEvent(event, role: role, staffID: staffID, context: context, escalate: escalate)
        Self.bufferQueue.sync {
            Self.analyticsEventBuffer.append((event: event, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date()))
            if Self.analyticsEventBuffer.count > 20 {
                Self.analyticsEventBuffer.removeFirst(Self.analyticsEventBuffer.count - 20)
            }
        }
    }

    /// Provides access to the most recent analytics events for diagnostics.
    /// - Returns: Array of last 20 analytics event tuples.
    public static func recentAnalyticsEvents() -> [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] {
        bufferQueue.sync {
            return analyticsEventBuffer
        }
    }
}

// MARK: - Preview

struct ErrorModal_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            Text("ErrorModal Preview")
                .font(.title)
                .padding()

            ErrorModal(
                title: NSLocalizedString("ErrorModal.previewTitle", value: "Network Error", comment: "Preview error modal title"),
                message: NSLocalizedString("ErrorModal.previewMessage", value: "Unable to connect to the server. Please try again later.", comment: "Preview error modal message"),
                primaryButtonLabel: NSLocalizedString("ErrorModal.retryButton", value: "Retry", comment: "Preview primary button label"),
                secondaryButtonLabel: NSLocalizedString("ErrorModal.cancelButton", value: "Cancel", comment: "Preview secondary button label"),
                primaryAction: { print("Primary action triggered") },
                secondaryAction: { print("Secondary action triggered") },
                analyticsLogger: NullErrorModalAnalyticsLogger(testMode: true),
                accessibilityLabel: NSLocalizedString("ErrorModal.accessibilityLabel", value: "Error dialog", comment: "Accessibility label for error modal"),
                accessibilityHint: NSLocalizedString("ErrorModal.accessibilityHint", value: "Informs user of an error and allows retry or cancel actions", comment: "Accessibility hint for error modal")
            )

            Button("Show Recent Analytics Events") {
                let events = ErrorModal.recentAnalyticsEvents()
                print("Recent Analytics Events:")
                for event in events {
                    print("Event: \(event.event)")
                    print("  Role: \(event.role ?? "nil")")
                    print("  StaffID: \(event.staffID ?? "nil")")
                    print("  Context: \(event.context ?? "nil")")
                    print("  Escalate: \(event.escalate)")
                    print("  Timestamp: \(event.timestamp)")
                }
            }
            .padding()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
