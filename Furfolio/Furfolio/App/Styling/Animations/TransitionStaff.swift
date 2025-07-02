//
//  TransitionStaff.swift
//  Furfolio
// aka groomers
//  Created by mac on 6/27/25.
//

/**
 # TransitionStaff Architecture Overview
 
 `TransitionStaff` is designed as a modular, extensible component for managing transition assignments and staff workflows in Furfolio. It supports analytics, auditing, diagnostics, localization, accessibility, compliance, and robust preview/testability for future maintainers.
 
 ## Architecture
 - **Core Class:** `TransitionStaff` is the central controller, exposing APIs for assigning and revoking transitions, auditing, diagnostics, and localized messaging.
 - **Analytics:** Analytics events are sent via the `TransitionStaffAnalyticsLogger` protocol, supporting async/await and a test/preview mode (`testMode`) for console-only logging.
 - **Audit & Trust Center Integration:** All critical actions are logged to an internal buffer (last 20 events) accessible for admin/diagnostics, supporting future Trust Center and compliance audits.
 - **Diagnostics:** Diagnostics APIs expose recent analytics events and system status for troubleshooting.
 - **Localization & Accessibility:** All user-facing messages and log event strings are localized using `NSLocalizedString`, supporting internationalization and accessibility.
 - **Compliance:** Designed to facilitate audit trails and event tracking for regulatory compliance.
 - **Preview/Testability:** Provides a `NullTransitionStaffAnalyticsLogger` for previews/tests, and supports `testMode` for QA/dev environments.
 
 ## Extensibility
 - Add new analytics backends by conforming to `TransitionStaffAnalyticsLogger`.
 - Extend error/status messages via localization files.
 - Integrate with external Trust Center, audit, or compliance systems via the audit log buffer.
 
 ## For Future Maintainers
 - All APIs are documented.
 - Use dependency injection for analytics loggers.
 - All loggable/user-facing strings must use `NSLocalizedString` with keys and comments.
 - Diagnostics and audit APIs must not expose sensitive information.
 */
import Foundation

// MARK: - Audit Context (set at login/session)
public struct TransitionStaffAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TransitionStaff"
}

/// Audit event structure capturing detailed event info for logging and compliance.
public struct TransitionStaffAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let transition: String?
    public let staff: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol for async/await-ready analytics event logging for TransitionStaff.
/// Conformers can send events to analytics backends, or log to console in test/preview mode.
/// Supports detailed audit fields and escalation flags.
@MainActor
public protocol TransitionStaffAnalyticsLogger {
    /// If true, only log to console for QA/testing/previews.
    var testMode: Bool { get }
    
    /// Log an analytics event asynchronously with detailed context.
    /// - Parameters:
    ///   - event: The event string (should be localized).
    ///   - transition: Optional transition identifier.
    ///   - staff: Optional staff identifier.
    ///   - role: Optional user role from audit context.
    ///   - staffID: Optional staff ID from audit context.
    ///   - context: Optional context string from audit context.
    ///   - escalate: Whether the event should be escalated for compliance.
    func log(
        event: String,
        transition: String?,
        staff: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    
    /// Fetch recent audit events asynchronously.
    /// - Parameter count: Number of recent events to fetch.
    /// - Returns: Array of recent audit events.
    func fetchRecentEvents(count: Int) async -> [TransitionStaffAuditEvent]
    
    /// Escalate a critical analytics event asynchronously.
    /// - Parameters:
    ///   - event: The event string (should be localized).
    ///   - transition: Optional transition identifier.
    ///   - staff: Optional staff identifier.
    ///   - role: Optional user role from audit context.
    ///   - staffID: Optional staff ID from audit context.
    ///   - context: Optional context string from audit context.
    func escalate(
        event: String,
        transition: String?,
        staff: String?,
        role: String?,
        staffID: String?,
        context: String?
    ) async
}

/// Null implementation for previews/tests; logs to console if testMode is true.
/// Implements full audit logging protocol with detailed fields.
public struct NullTransitionStaffAnalyticsLogger: TransitionStaffAnalyticsLogger {
    public let testMode: Bool
    public init(testMode: Bool = true) {
        self.testMode = testMode
    }
    
    public func log(
        event: String,
        transition: String?,
        staff: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[TransitionStaff][TEST] Event: \(event)")
            print("  Transition: \(transition ?? "nil")")
            print("  Staff: \(staff ?? "nil")")
            print("  Role: \(role ?? "nil")")
            print("  StaffID: \(staffID ?? "nil")")
            print("  Context: \(context ?? "nil")")
            print("  Escalate: \(escalate)")
        }
    }
    
    public func fetchRecentEvents(count: Int) async -> [TransitionStaffAuditEvent] {
        return []
    }
    
    public func escalate(
        event: String,
        transition: String?,
        staff: String?,
        role: String?,
        staffID: String?,
        context: String?
    ) async {
        if testMode {
            print("[TransitionStaff][TEST][ESCALATE] Event: \(event)")
            print("  Transition: \(transition ?? "nil")")
            print("  Staff: \(staff ?? "nil")")
            print("  Role: \(role ?? "nil")")
            print("  StaffID: \(staffID ?? "nil")")
            print("  Context: \(context ?? "nil")")
        }
    }
}

/// Main controller for transition assignments and staff management.
/// Provides analytics, audit, diagnostics, localization, and compliance hooks.
public final class TransitionStaff {
    /// Analytics logger for event tracking.
    private let analyticsLogger: TransitionStaffAnalyticsLogger
    
    /// Ring buffer for last 20 analytics/audit events.
    private var eventBuffer: [TransitionStaffAuditEvent] = []
    private static let eventBufferLimit = 20
    
    /// Initialize with dependency-injected analytics logger.
    /// - Parameter analyticsLogger: Conformer to `TransitionStaffAnalyticsLogger`.
    public init(analyticsLogger: TransitionStaffAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }
    
    // MARK: - Transition Assignment APIs
    
    /// Assign a transition to a staff member.
    /// - Parameters:
    ///   - transition: The transition identifier.
    ///   - staff: The staff member identifier.
    /// - Throws: Localized error if assignment fails.
    public func assignTransition(to transition: String, staff: String) async throws {
        // TODO: Implement assignment logic.
        let message = NSLocalizedString(
            "transition_assigned",
            value: "Transition %{transition} assigned to %{staff}.",
            comment: "Log: transition assigned to staff"
        )
        let logEvent = message
            .replacingOccurrences(of: "%{transition}", with: transition)
            .replacingOccurrences(of: "%{staff}", with: staff)
        
        let escalate = containsCriticalOrRisk(transition: transition, staff: staff)
        
        await logEventAndBuffer(
            event: logEvent,
            transition: transition,
            staff: staff,
            escalate: escalate
        )
    }
    
    /// Revoke a transition from a staff member.
    /// - Parameters:
    ///   - transition: The transition identifier.
    ///   - staff: The staff member identifier.
    /// - Throws: Localized error if revocation fails.
    public func revokeTransition(from transition: String, staff: String) async throws {
        // TODO: Implement revocation logic.
        let message = NSLocalizedString(
            "transition_revoked",
            value: "Transition %{transition} revoked from %{staff}.",
            comment: "Log: transition revoked from staff"
        )
        let logEvent = message
            .replacingOccurrences(of: "%{transition}", with: transition)
            .replacingOccurrences(of: "%{staff}", with: staff)
        
        let escalate = containsCriticalOrRisk(transition: transition, staff: staff)
        
        await logEventAndBuffer(
            event: logEvent,
            transition: transition,
            staff: staff,
            escalate: escalate
        )
    }
    
    // MARK: - Audit & Diagnostics
    
    /// Returns the last 20 analytics/audit events for admin/diagnostics.
    /// - Returns: Array of recent audit event structs.
    public func recentEvents() -> [TransitionStaffAuditEvent] {
        return eventBuffer
    }
    
    /// Returns audit log for compliance/Trust Center integration.
    /// - Returns: Array of audit event structs.
    public func auditLog() -> [TransitionStaffAuditEvent] {
        // TODO: Integrate with persistent audit storage.
        return eventBuffer
    }
    
    /// Returns diagnostics/status summary for system health checks.
    /// Summarizes recent event count, last event, escalated event count, last role/context.
    /// - Returns: Localized diagnostics status message.
    public func diagnostics() -> String {
        let count = eventBuffer.count
        let lastEvent = eventBuffer.last?.event ?? NSLocalizedString(
            "diagnostics_no_events",
            value: "No events recorded.",
            comment: "Diagnostics: no events"
        )
        let escalatedCount = eventBuffer.filter { $0.escalate }.count
        let lastRole = eventBuffer.last?.role ?? NSLocalizedString(
            "diagnostics_no_role",
            value: "No role info",
            comment: "Diagnostics: no role info"
        )
        let lastContext = eventBuffer.last?.context ?? NSLocalizedString(
            "diagnostics_no_context",
            value: "No context info",
            comment: "Diagnostics: no context info"
        )
        
        let diagnosticsMessageFormat = NSLocalizedString(
            "diagnostics_status_summary",
            value: "Diagnostics: %d events recorded. Last event: \"%@\". Escalated events: %d. Last role: %@. Last context: %@.",
            comment: "Status: diagnostics summary"
        )
        
        return String(format: diagnosticsMessageFormat, count, lastEvent, escalatedCount, lastRole, lastContext)
    }
    
    // MARK: - Localization-Ready Error/Status Messages
    
    /// Returns a localized error message.
    /// - Parameter key: Localization key.
    /// - Returns: Localized error string.
    public func localizedErrorMessage(for key: String) -> String {
        return NSLocalizedString(
            key,
            value: "An error occurred.",
            comment: "Generic error message"
        )
    }
    
    // MARK: - Private Helpers
    
    /// Log an event to analytics and buffer with detailed audit info.
    /// - Parameters:
    ///   - event: Localized event string.
    ///   - transition: Optional transition identifier.
    ///   - staff: Optional staff identifier.
    ///   - escalate: Whether this event should be escalated.
    private func logEventAndBuffer(
        event: String,
        transition: String?,
        staff: String?,
        escalate: Bool
    ) async {
        let auditEvent = TransitionStaffAuditEvent(
            timestamp: Date(),
            event: event,
            transition: transition,
            staff: staff,
            role: TransitionStaffAuditContext.role,
            staffID: TransitionStaffAuditContext.staffID,
            context: TransitionStaffAuditContext.context,
            escalate: escalate
        )
        
        // Append to capped buffer.
        if eventBuffer.count >= TransitionStaff.eventBufferLimit {
            eventBuffer.removeFirst()
        }
        eventBuffer.append(auditEvent)
        
        await analyticsLogger.log(
            event: event,
            transition: transition,
            staff: staff,
            role: TransitionStaffAuditContext.role,
            staffID: TransitionStaffAuditContext.staffID,
            context: TransitionStaffAuditContext.context,
            escalate: escalate
        )
        
        if escalate {
            await analyticsLogger.escalate(
                event: event,
                transition: transition,
                staff: staff,
                role: TransitionStaffAuditContext.role,
                staffID: TransitionStaffAuditContext.staffID,
                context: TransitionStaffAuditContext.context
            )
        }
    }
    
    /// Helper to determine if event should be escalated based on keywords.
    /// - Parameters:
    ///   - transition: Transition identifier.
    ///   - staff: Staff identifier.
    /// - Returns: True if either contains "critical" or "risk" case-insensitive.
    private func containsCriticalOrRisk(transition: String, staff: String) -> Bool {
        let keywords = ["critical", "risk"]
        let lowerTransition = transition.lowercased()
        let lowerStaff = staff.lowercased()
        for keyword in keywords {
            if lowerTransition.contains(keyword) || lowerStaff.contains(keyword) {
                return true
            }
        }
        return false
    }
}
