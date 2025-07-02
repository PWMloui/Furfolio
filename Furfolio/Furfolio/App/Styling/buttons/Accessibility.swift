//
//  Accessibility.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 Accessibility.swift

 This file provides the architecture and foundational components for accessibility management within the Furfolio app.

 Architecture:
 - AccessibilityManager: A singleton class responsible for handling accessibility-related features, including announcements, custom rotors, audit logging, diagnostics, and localization.
 - AccessibilityAnalyticsLogger: A protocol defining async/await-ready analytics logging capabilities with support for test mode.
 - NullAccessibilityAnalyticsLogger: A no-op implementation of AccessibilityAnalyticsLogger for use in previews, tests, and QA environments.

 Extensibility:
 - Designed to be easily extended with additional accessibility features, analytics hooks, and diagnostic tools.
 - Localization-ready with all user-facing and log event strings wrapped in NSLocalizedString for compliance and internationalization.

 Analytics / Audit / Trust Center Hooks:
 - Analytics events are buffered (up to 20 recent events) to support audit trails and diagnostics.
 - Public API to retrieve recent analytics events for administrative and diagnostic purposes.

 Diagnostics:
 - Placeholder methods for diagnostics and audit logging to be implemented as needed.
 - Supports future integration with Trust Center or compliance frameworks.

 Localization:
 - All user-facing messages and log strings use NSLocalizedString with appropriate keys and comments to facilitate localization.

 Accessibility:
 - Supports posting accessibility announcements and custom rotors.
 - Designed to improve app compliance with accessibility standards and enhance user experience for assistive technology users.

 Compliance:
 - Structured to support audit logging and diagnostics to meet compliance requirements.

 Preview / Testability:
 - NullAccessibilityAnalyticsLogger enables safe usage in previews and tests without side effects.
 - Analytics logger protocol supports test mode for console-only logging during QA and testing.

 This documentation is intended to guide future maintainers and developers in extending and maintaining accessibility features within Furfolio.
 */

import Foundation

// MARK: - Audit Context (set at login/session)
public struct AccessibilityAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AccessibilityManager"
}

/// Represents an accessibility audit event with associated metadata.
public struct AccessibilityAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol defining an async/await-compatible analytics logger for accessibility events, with audit and escalation support.
public protocol AccessibilityAnalyticsLogger {
    /// Indicates if the logger is in test mode, where logs are output only to the console.
    var testMode: Bool { get }

    /// Logs an accessibility analytics event asynchronously with audit context and escalation flag.
    /// - Parameters:
    ///   - event: The event description string.
    ///   - role: The role of the user/session.
    ///   - staffID: The staff identifier.
    ///   - context: The context string.
    ///   - escalate: Flag indicating whether to escalate the event.
    func logEvent(_ event: String, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Fetches recent audit events asynchronously.
    /// - Parameter count: The maximum number of recent events to retrieve.
    /// - Returns: An array of AccessibilityAuditEvent.
    func fetchRecentEvents(count: Int) async -> [AccessibilityAuditEvent]

    /// Escalates a given event with audit context.
    /// - Parameters:
    ///   - event: The event description string.
    ///   - role: The role of the user/session.
    ///   - staffID: The staff identifier.
    ///   - context: The context string.
    func escalate(_ event: String, role: String?, staffID: String?, context: String?) async
}

/// A no-operation accessibility analytics logger used for previews, tests, and QA environments.
public struct NullAccessibilityAnalyticsLogger: AccessibilityAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(_ event: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("Accessibility Analytics Event (Test Mode): \(event)")
            print("Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
        // No-op: Intentionally does nothing for testing and preview environments.
    }

    public func fetchRecentEvents(count: Int) async -> [AccessibilityAuditEvent] {
        // No-op: Return empty array for testing and preview environments.
        return []
    }

    public func escalate(_ event: String, role: String?, staffID: String?, context: String?) async {
        if testMode {
            print("Escalate Event (Test Mode): \(event)")
            print("Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil")")
        }
        // No-op: Intentionally does nothing for testing and preview environments.
    }
}

/// Singleton class managing accessibility features, analytics, diagnostics, and localization with audit and compliance support.
public final class AccessibilityManager {
    /// Shared singleton instance.
    public static let shared = AccessibilityManager()

    /// The analytics logger used to record accessibility events.
    public var analyticsLogger: AccessibilityAnalyticsLogger = NullAccessibilityAnalyticsLogger()

    /// Internal buffer to store recent analytics audit events (capped at 20).
    private var recentEvents: [AccessibilityAuditEvent] = []

    private let recentEventsCapacity = 20
    private let recentEventsQueue = DispatchQueue(label: "AccessibilityManager.recentEventsQueue", attributes: .concurrent)

    private init() {}

    /// Posts an accessibility announcement to assistive technologies.
    /// - Parameter message: The announcement message.
    public func postAnnouncement(_ message: String) {
        let localizedMessage = NSLocalizedString(
            message,
            comment: "Accessibility announcement message"
        )
        // Placeholder: Implement actual announcement posting to accessibility framework here.

        Task {
            await logEvent(localizedMessage)
        }
    }

    /// Posts a custom rotor for assistive technologies.
    /// - Parameter rotorName: The name of the custom rotor.
    public func postCustomRotor(_ rotorName: String) {
        let localizedRotorName = NSLocalizedString(
            rotorName,
            comment: "Custom rotor name for accessibility"
        )
        // Placeholder: Implement actual custom rotor posting here.

        Task {
            await logEvent(localizedRotorName)
        }
    }

    /// Performs an audit log of accessibility-related events for compliance and trust center requirements.
    public func auditLog() {
        // Placeholder: Implement audit logging functionality.
        Task {
            await logEvent(NSLocalizedString(
                "Audit log triggered",
                comment: "Audit log event"
            ))
        }
    }

    /// Runs diagnostics on accessibility features and reports status for compliance and monitoring.
    public func diagnostics() {
        // Placeholder: Implement diagnostics functionality.
        Task {
            await logEvent(NSLocalizedString(
                "Diagnostics run",
                comment: "Diagnostics event"
            ))
        }
    }

    /// Provides localization-ready error or status messages.
    /// - Parameter key: The localization key.
    /// - Returns: The localized string.
    public func localizedMessage(forKey key: String) -> String {
        return NSLocalizedString(
            key,
            comment: "Localization for accessibility message: \(key)"
        )
    }

    /// Retrieves the most recent analytics audit events for administrative or diagnostic purposes.
    /// - Returns: An array of recent AccessibilityAuditEvent, up to the last 20.
    public func fetchRecentAnalyticsEvents() -> [AccessibilityAuditEvent] {
        var eventsCopy: [AccessibilityAuditEvent] = []
        recentEventsQueue.sync {
            eventsCopy = recentEvents
        }
        return eventsCopy
    }

    /// Logs an accessibility analytics event with audit context and stores it in the capped buffer.
    /// - Parameter event: The event description string.
    private func logEvent(_ event: String) async {
        let lowercasedEvent = event.lowercased()
        let shouldEscalate = lowercasedEvent.contains("audit") || lowercasedEvent.contains("critical")
        let auditEvent = AccessibilityAuditEvent(
            timestamp: Date(),
            event: event,
            role: AccessibilityAuditContext.role,
            staffID: AccessibilityAuditContext.staffID,
            context: AccessibilityAuditContext.context,
            escalate: shouldEscalate
        )

        if analyticsLogger.testMode {
            print("Accessibility Analytics Event (Test Mode): \(event)")
            print("Role: \(auditEvent.role ?? "nil"), StaffID: \(auditEvent.staffID ?? "nil"), Context: \(auditEvent.context ?? "nil"), Escalate: \(auditEvent.escalate)")
        } else {
            await analyticsLogger.logEvent(event, role: auditEvent.role, staffID: auditEvent.staffID, context: auditEvent.context, escalate: auditEvent.escalate)
        }

        recentEventsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.recentEvents.append(auditEvent)
            if self.recentEvents.count > self.recentEventsCapacity {
                self.recentEvents.removeFirst(self.recentEvents.count - self.recentEventsCapacity)
            }
        }
    }
}
