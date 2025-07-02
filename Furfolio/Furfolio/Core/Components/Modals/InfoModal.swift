//
//  InfoModal.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 InfoModal.swift

 Architecture:
 - This file defines the InfoModal SwiftUI component designed for displaying informational modals with customizable titles, messages, buttons, and actions.
 - It employs dependency injection for analytics logging, supporting async/await for modern concurrency.
 - The InfoModalAnalyticsLogger protocol abstracts analytics logging, allowing for different implementations (e.g., production, testing).
 - The modal supports localization, accessibility, and compliance with best practices.

 Extensibility:
 - New analytics loggers can be added by conforming to InfoModalAnalyticsLogger.
 - Additional UI customization can be added via parameters or extensions.
 - Localization keys are centralized to facilitate translation.

 Analytics/Audit/Trust Center Hooks:
 - The component logs user interactions asynchronously via the injected analytics logger.
 - An internal capped buffer stores the last 20 analytics events for diagnostics and audit purposes.
 - Public API allows fetching recent events for administrative or diagnostic tools.

 Diagnostics:
 - The capped event buffer provides quick access to recent analytics events.
 - Test mode enables console-only logging for QA, tests, and previews.

 Localization:
 - All user-facing strings and analytics event strings are wrapped with NSLocalizedString, supporting localization workflows.

 Accessibility:
 - Accessibility labels and hints are customizable and exposed as parameters.
 - The modal supports VoiceOver and other assistive technologies.

 Compliance:
 - The component facilitates audit trails via analytics logging.
 - Supports compliance with data governance by allowing testMode to avoid sending data to production analytics.

 Preview/Testability:
 - Includes a NullInfoModalAnalyticsLogger for previews and tests.
 - A PreviewProvider demonstrates accessibility, testMode, and diagnostics features.
 */


import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct InfoModalAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "InfoModal"
}

/// Protocol defining async analytics logging for InfoModal interactions.
/// Conforms to async/await to support modern concurrency.
/// Provides a `testMode` property to enable console-only logging for QA/tests/previews.
public protocol InfoModalAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Logs an event asynchronously.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - role: Optional user role.
    ///   - staffID: Optional staff ID.
    ///   - context: Optional context string.
    ///   - escalate: Indicates if the event should be escalated (danger/critical/delete).
    func logEvent(
        _ event: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A Null analytics logger used for previews and tests that performs no network calls.
/// Logs to console if testMode is true.
public struct NullInfoModalAnalyticsLogger: InfoModalAnalyticsLogger {
    public let testMode: Bool

    public init(testMode: Bool = true) {
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
            print(
                """
                [NullInfoModalAnalyticsLogger] Event: \(event)
                  role: \(role ?? "nil")
                  staffID: \(staffID ?? "nil")
                  context: \(context ?? "nil")
                  escalate: \(escalate)
                """
            )
        }
        // No-op for production network calls.
    }
}

/// A SwiftUI view representing an informational modal with customizable content and actions.
/// Supports localization, accessibility, and analytics logging.
/// - Parameters:
///   - title: The modal's title string.
///   - message: The modal's message string.
///   - primaryButtonLabel: Label for the primary action button.
///   - primaryButtonAction: Async closure executed when primary button is tapped.
///   - secondaryButtonLabel: Label for the secondary action button (optional).
///   - secondaryButtonAction: Async closure executed when secondary button is tapped (optional).
///   - analyticsLogger: Injected analytics logger conforming to InfoModalAnalyticsLogger.
///   - accessibilityLabel: Accessibility label for the modal container.
///   - accessibilityHint: Accessibility hint for the modal container.
public struct InfoModal: View {
    // MARK: - Parameters
    public let title: String
    public let message: String
    public let primaryButtonLabel: String
    public let primaryButtonAction: () async -> Void
    public let secondaryButtonLabel: String?
    public let secondaryButtonAction: (() async -> Void)?
    public let analyticsLogger: InfoModalAnalyticsLogger
    public let accessibilityLabel: String?
    public let accessibilityHint: String?

    // MARK: - Internal Analytics Event Buffer
    @State private var recentEvents: [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

    // Capped buffer size for analytics events
    private let maxEventsStored = 20

    // MARK: - Initialization
    public init(
        title: String,
        message: String,
        primaryButtonLabel: String,
        primaryButtonAction: @escaping () async -> Void,
        secondaryButtonLabel: String? = nil,
        secondaryButtonAction: (() async -> Void)? = nil,
        analyticsLogger: InfoModalAnalyticsLogger = NullInfoModalAnalyticsLogger(),
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonLabel = primaryButtonLabel
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonLabel = secondaryButtonLabel
        self.secondaryButtonAction = secondaryButtonAction
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    // MARK: - Body
    public var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                if let secondaryLabel = secondaryButtonLabel, let secondaryAction = secondaryButtonAction {
                    Button {
                        Task {
                            await logAndPerform(event: NSLocalizedString("InfoModal_SecondaryButtonTapped", value: "Secondary button tapped", comment: "Analytics event for secondary button tap"), action: secondaryAction)
                        }
                    } label: {
                        Text(secondaryLabel)
                    }
                    .accessibilityLabel(secondaryLabel)
                }
                Button {
                    Task {
                        await logAndPerform(event: NSLocalizedString("InfoModal_PrimaryButtonTapped", value: "Primary button tapped", comment: "Analytics event for primary button tap"), action: primaryButtonAction)
                    }
                } label: {
                    Text(primaryButtonLabel)
                        .bold()
                }
                .accessibilityLabel(primaryButtonLabel)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Private Helpers

    /// Logs the analytics event and performs the provided async action.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - action: The async action to perform after logging.
    private func logAndPerform(event: String, action: @escaping () async -> Void) async {
        let role = InfoModalAuditContext.role
        let staffID = InfoModalAuditContext.staffID
        let context = InfoModalAuditContext.context
        let lower = event.lowercased()
        let escalate = lower.contains("danger") || lower.contains("critical") || lower.contains("delete")
        await analyticsLogger.logEvent(
            event,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        await addEventToBuffer(event: event, role: role, staffID: staffID, context: context, escalate: escalate)
        await action()
    }

    /// Adds an event and audit fields to the capped recent events buffer.
    /// - Parameters:
    ///   - event: The event string to add.
    ///   - role: The user role.
    ///   - staffID: The staff ID.
    ///   - context: The context string.
    ///   - escalate: Whether the event is escalated.
    @MainActor
    private func addEventToBuffer(event: String, role: String?, staffID: String?, context: String?, escalate: Bool) {
        recentEvents.append((event: event, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date()))
        if recentEvents.count > maxEventsStored {
            recentEvents.removeFirst(recentEvents.count - maxEventsStored)
        }
    }

    // MARK: - Public API

    /// Returns a snapshot of recent logged analytics events.
    /// - Returns: Array of recent event tuples (up to 20).
    public func getRecentAnalyticsEvents() -> [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] {
        recentEvents
    }
}

/// Preview provider demonstrating accessibility, testMode, and diagnostics features.
struct InfoModal_Previews: PreviewProvider {
    struct PreviewNullLogger: InfoModalAnalyticsLogger {
        let testMode: Bool
        init(testMode: Bool = true) {
            self.testMode = testMode
        }
        func logEvent(
            _ event: String,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            if testMode {
                print(
                    """
                    [NullInfoModalAnalyticsLogger] Event: \(event)
                      role: \(role ?? "nil")
                      staffID: \(staffID ?? "nil")
                      context: \(context ?? "nil")
                      escalate: \(escalate)
                    """
                )
            }
        }
    }

    struct PreviewWrapper: View {
        @State private var showModal = true
        @State private var recentEvents: [(event: String, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

        let analyticsLogger = PreviewNullLogger(testMode: true)

        var body: some View {
            VStack(spacing: 20) {
                if showModal {
                    InfoModal(
                        title: NSLocalizedString("InfoModal_Preview_Title", value: "Welcome to Furfolio", comment: "Modal title in preview"),
                        message: NSLocalizedString("InfoModal_Preview_Message", value: "This is a preview of the InfoModal component.", comment: "Modal message in preview"),
                        primaryButtonLabel: NSLocalizedString("InfoModal_Preview_PrimaryButton", value: "Continue", comment: "Primary button label in preview"),
                        primaryButtonAction: {
                            await Task.sleep(500_000_000) // simulate async work
                            showModal = false
                        },
                        secondaryButtonLabel: NSLocalizedString("InfoModal_Preview_SecondaryButton", value: "Cancel", comment: "Secondary button label in preview"),
                        secondaryButtonAction: {
                            await Task.sleep(200_000_000) // simulate async work
                            showModal = false
                        },
                        analyticsLogger: analyticsLogger,
                        accessibilityLabel: NSLocalizedString("InfoModal_Accessibility_Label", value: "Information Modal", comment: "Accessibility label for modal"),
                        accessibilityHint: NSLocalizedString("InfoModal_Accessibility_Hint", value: "Informative modal with actions", comment: "Accessibility hint for modal")
                    )
                    .onAppear {
                        recentEvents = []
                    }
                    .onChange(of: showModal) { _ in
                        // no-op
                    }
                } else {
                    Text(NSLocalizedString("InfoModal_Preview_ClosedMessage", value: "Modal closed. Check console for analytics events.", comment: "Message after modal closes"))
                        .padding()
                }

                Button(NSLocalizedString("InfoModal_Preview_ShowModalButton", value: "Show Modal", comment: "Button label to show modal again")) {
                    showModal = true
                }

                VStack(alignment: .leading) {
                    Text(NSLocalizedString("InfoModal_Preview_RecentEventsTitle", value: "Recent Analytics Events:", comment: "Title for recent events list"))
                        .font(.headline)
                    ScrollView {
                        ForEach(Array(recentEvents.enumerated()), id: \.offset) { idx, eventTuple in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Event: \(eventTuple.event)")
                                    .font(.caption)
                                Text("  role: \(eventTuple.role ?? "nil")")
                                    .font(.caption2)
                                Text("  staffID: \(eventTuple.staffID ?? "nil")")
                                    .font(.caption2)
                                Text("  context: \(eventTuple.context ?? "nil")")
                                    .font(.caption2)
                                Text("  escalate: \(eventTuple.escalate ? "true" : "false")")
                                    .font(.caption2)
                                Text("  timestamp: \(eventTuple.timestamp.formatted(date: .numeric, time: .standard))")
                                    .font(.caption2)
                            }
                            .padding(2)
                        }
                        if analyticsLogger.testMode {
                            Text("(Events logged to console in testMode)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh recent events on app active if needed
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
