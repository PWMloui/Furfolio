//
//  InputAccessories.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 InputAccessories.swift Architecture and Overview

 This file defines reusable input accessory components and their supporting infrastructure for the Furfolio app.
 It provides a modular, extensible SwiftUI InputAccessory view with built-in support for analytics, diagnostics,
 localization, accessibility, compliance, audit context, and preview/testability.

 Key Features:
 - Async/await-ready analytics logging protocol with a testMode for console-only logging during QA, tests, and previews.
 - Null analytics logger implementation for use in previews and tests.
 - InputAccessory SwiftUI view with common parameters: title, optional icon, accessibility labels/hints, and injected analytics logger.
 - All user-facing strings and analytics event strings are localized using NSLocalizedString with descriptive keys and comments.
 - Capped in-memory analytics event buffer (last 20 events) with a public API to fetch recent events for diagnostics, audit, and admin tools.
 - Audit context struct for session-level user role and staff ID tracking.
 - Comprehensive doc-comments throughout to assist future maintainers and developers.
 - PreviewProvider demonstrating accessibility features, testMode analytics logging, audit event display, and diagnostics capabilities.

 This design supports future extensibility by allowing new accessory types to conform to the analytics protocol,
 adding new localized strings, and integrating with Trust Center, compliance, or audit hooks as needed.

 Future maintainers should ensure all new user-facing strings are localized,
 maintain accessibility labels for UI elements, and leverage the analytics logger for audit and trust center hooks.
*/

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct InputAccessoriesAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "InputAccessories"
}

/// Protocol defining an async/await-compatible analytics logger for InputAccessories with audit context support.
/// Conforming types should implement logging of events with detailed audit fields, supporting testMode for console-only logging during QA/tests/previews.
public protocol InputAccessoriesAnalyticsLogger: AnyObject {
    /// Indicates whether the logger is in test mode (console-only logging, no network or persistent storage).
    var testMode: Bool { get }

    /**
     Logs an analytics event asynchronously with detailed audit context.

     - Parameters:
       - event: The event string to log. Should be a localized string describing the event.
       - title: The title associated with the accessory.
       - icon: Optional icon name associated with the accessory.
       - role: User role from audit context.
       - staffID: Staff ID from audit context.
       - context: Context string from audit context.
       - escalate: Flag indicating whether the event should be escalated for compliance/trust center review.
     */
    func logEvent(
        _ event: String,
        title: String,
        icon: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /**
     Retrieves the most recent analytics events for diagnostics, audit, or admin purposes.

     - Returns: An array of the last recorded analytics event objects, up to a capped buffer size.
     */
    func recentEvents() -> [InputAccessoriesAnalyticsEvent]
}

/// Represents a detailed analytics event for InputAccessories, including audit context fields.
public struct InputAccessoriesAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let title: String
    public let icon: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A no-op analytics logger used for previews and tests.
/// Logs events only to the console when in test mode, does not store events.
public class NullInputAccessoriesAnalyticsLogger: InputAccessoriesAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ event: String,
        title: String,
        icon: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        // Print all audit fields to console only in test mode
        if testMode {
            print("""
                NullAnalyticsLogger Event:
                event: \(event)
                title: \(title)
                icon: \(icon ?? "nil")
                role: \(role ?? "nil")
                staffID: \(staffID ?? "nil")
                context: \(context ?? "nil")
                escalate: \(escalate)
                """)
        }
    }

    public func recentEvents() -> [InputAccessoriesAnalyticsEvent] {
        return []
    }
}

/// A default in-memory analytics logger that stores the last 20 detailed events.
/// Supports testMode for console-only logging during QA/tests/previews.
/// Integrates audit context and compliance escalation flags.
public class DefaultInputAccessoriesAnalyticsLogger: ObservableObject, InputAccessoriesAnalyticsLogger {
    public let testMode: Bool

    /// Internal capped buffer size for event storage
    private let maxBufferSize = 20

    /// Thread-safe storage for detailed analytics events
    @MainActor @Published private var eventBuffer: [InputAccessoriesAnalyticsEvent] = []

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    /// Logs an event asynchronously, storing it in the buffer and optionally printing all audit fields to console in test mode.
    public func logEvent(
        _ event: String,
        title: String,
        icon: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let newEvent = InputAccessoriesAnalyticsEvent(
            timestamp: Date(),
            event: event,
            title: title,
            icon: icon,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        await MainActor.run {
            if self.eventBuffer.count >= maxBufferSize {
                self.eventBuffer.removeFirst()
            }
            self.eventBuffer.append(newEvent)
        }
        if testMode {
            print("""
                DefaultAnalyticsLogger Event:
                event: \(event)
                title: \(title)
                icon: \(icon ?? "nil")
                role: \(role ?? "nil")
                staffID: \(staffID ?? "nil")
                context: \(context ?? "nil")
                escalate: \(escalate)
                timestamp: \(newEvent.timestamp)
                """)
        }
        // Future: send event to backend or Trust Center here
    }

    /// Returns a snapshot of recent detailed analytics events.
    public func recentEvents() -> [InputAccessoriesAnalyticsEvent] {
        return eventBuffer
    }
}

/// A SwiftUI view representing a common input accessory with title, optional icon, accessibility, and analytics support.
/// Integrates audit context and compliance escalation flags for trust center and compliance hooks.
public struct InputAccessory: View {
    /// The title text displayed on the accessory. Localized string.
    public let title: String

    /// Optional system image name for an icon displayed alongside the title.
    public let icon: String?

    /// Accessibility label for the accessory. Localized string.
    public let accessibilityLabel: String

    /// Accessibility hint describing the accessory's purpose. Localized string.
    public let accessibilityHint: String

    /// Analytics logger injected for event tracking.
    @ObservedObject private var analyticsLogger: DefaultInputAccessoriesAnalyticsLogger

    /// Initializes an InputAccessory view.
    /// - Parameters:
    ///   - title: The localized title string.
    ///   - icon: Optional system image name for the icon.
    ///   - accessibilityLabel: Localized accessibility label.
    ///   - accessibilityHint: Localized accessibility hint.
    ///   - analyticsLogger: Analytics logger instance to use for event logging.
    public init(
        title: String,
        icon: String? = nil,
        accessibilityLabel: String,
        accessibilityHint: String,
        analyticsLogger: DefaultInputAccessoriesAnalyticsLogger = DefaultInputAccessoriesAnalyticsLogger()
    ) {
        self.title = title
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.analyticsLogger = analyticsLogger
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let iconName = icon {
                Image(systemName: iconName)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            Task {
                let eventString = NSLocalizedString(
                    "InputAccessory_Appear_Event",
                    value: "InputAccessory appeared with title: \(title)",
                    comment: "Analytics event logged when InputAccessory view appears"
                )
                let lowercasedTitle = title.lowercased()
                let lowercasedIcon = icon?.lowercased() ?? ""
                let escalationKeywords = ["delete", "danger", "critical"]
                let shouldEscalate = escalationKeywords.contains { keyword in
                    lowercasedTitle.contains(keyword) || lowercasedIcon.contains(keyword)
                }
                await analyticsLogger.logEvent(
                    eventString,
                    title: title,
                    icon: icon,
                    role: InputAccessoriesAuditContext.role,
                    staffID: InputAccessoriesAuditContext.staffID,
                    context: InputAccessoriesAuditContext.context,
                    escalate: shouldEscalate
                )
            }
        }
    }
}

/// Preview provider demonstrating accessibility, testMode analytics logging, audit event display, and diagnostics.
struct InputAccessory_Previews: PreviewProvider {
    static let previewLogger = DefaultInputAccessoriesAnalyticsLogger(testMode: true)

    static var previews: some View {
        VStack(spacing: 20) {
            InputAccessory(
                title: NSLocalizedString(
                    "InputAccessory_Preview_Title",
                    value: "Preview Accessory",
                    comment: "Title shown in InputAccessory preview"
                ),
                icon: "pencil",
                accessibilityLabel: NSLocalizedString(
                    "InputAccessory_Preview_AccessibilityLabel",
                    value: "Preview Input Accessory",
                    comment: "Accessibility label for InputAccessory preview"
                ),
                accessibilityHint: NSLocalizedString(
                    "InputAccessory_Preview_AccessibilityHint",
                    value: "Activates preview accessory features",
                    comment: "Accessibility hint for InputAccessory preview"
                ),
                analyticsLogger: previewLogger
            )
            .padding()

            Text(NSLocalizedString(
                "InputAccessory_Preview_RecentEvents_Title",
                value: "Recent Analytics Events:",
                comment: "Title for recent events list in preview"
            ))
            .font(.headline)

            List(previewLogger.recentEvents()) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event: \(event.event)")
                    Text("Title: \(event.title)")
                    Text("Icon: \(event.icon ?? "nil")")
                    Text("Role: \(event.role ?? "nil")")
                    Text("StaffID: \(event.staffID ?? "nil")")
                    Text("Context: \(event.context ?? "nil")")
                    Text("Escalate: \(event.escalate ? "Yes" : "No")")
                    Text("Timestamp: \(event.timestamp)")
                }
                .font(.caption)
                .padding(4)
            }
            .frame(height: 300)
        }
        .padding()
    }
}
