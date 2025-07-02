//
//  TransitionReceptionist.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//

/**
 TransitionReceptionist is designed as a robust and extensible component responsible for managing transition assignments and revocations within the Furfolio application. This architecture supports seamless integration with analytics, audit trails, and Trust Center compliance mechanisms, ensuring comprehensive tracking and accountability.

 Key Features:
 - Extensibility: Protocol-based design allows for easy integration of custom analytics loggers.
 - Analytics & Audit: Captures transition events with a capped buffer for diagnostics and audit purposes.
 - Diagnostics: Provides diagnostics APIs to fetch recent analytics events for administrative review.
 - Localization: All user-facing and log strings are localized using NSLocalizedString for internationalization support.
 - Accessibility & Compliance: Ensures that all operations are auditable and compliant with internal Trust Center standards.
 - Preview & Testability: Includes a NullTransitionReceptionistAnalyticsLogger for use in previews and test environments.
 
 Future maintainers should find this module straightforward to extend with additional logging, error handling, or integration points.
 */

import Foundation

// MARK: - Audit Context (set at login/session)
public struct TransitionReceptionistAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TransitionReceptionist"
}

public struct TransitionReceptionistAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let transitionID: String?
    public let receptionistID: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol defining an async/await-ready analytics logger for TransitionReceptionist with full audit context.
/// Includes a testMode property for console-only logging during QA, testing, or previews.
public protocol TransitionReceptionistAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get set }
    
    /// Logs an analytics event asynchronously with full audit context.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - transitionID: Optional transition identifier.
    ///   - receptionistID: Optional receptionist identifier.
    ///   - role: Optional role from audit context.
    ///   - staffID: Optional staff ID from audit context.
    ///   - context: Optional context string.
    ///   - escalate: Whether the event should be escalated for compliance.
    func logEvent(
        _ event: String,
        transitionID: String?,
        receptionistID: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    
    /// Fetches recent audit events asynchronously.
    /// - Parameter count: Number of recent events to fetch.
    /// - Returns: Array of recent audit events.
    func fetchRecentEvents(count: Int) async -> [TransitionReceptionistAuditEvent]
    
    /// Escalates a given event asynchronously.
    /// - Parameters:
    ///   - event: The event string to escalate.
    ///   - transitionID: Optional transition identifier.
    ///   - receptionistID: Optional receptionist identifier.
    ///   - role: Optional role from audit context.
    ///   - staffID: Optional staff ID from audit context.
    ///   - context: Optional context string.
    func escalate(
        _ event: String,
        transitionID: String?,
        receptionistID: String?,
        role: String?,
        staffID: String?,
        context: String?
    ) async
}

/// A no-op analytics logger for use in previews, tests, and environments where logging is not desired.
/// Prints to console only if testMode is enabled.
public struct NullTransitionReceptionistAnalyticsLogger: TransitionReceptionistAnalyticsLogger {
    public var testMode: Bool = false
    
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    public func logEvent(
        _ event: String,
        transitionID: String?,
        receptionistID: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[TestMode] Analytics Event: \(event) | transitionID: \(transitionID ?? "nil") | receptionistID: \(receptionistID ?? "nil") | role: \(role ?? "nil") | staffID: \(staffID ?? "nil") | context: \(context ?? "nil") | escalate: \(escalate)")
        }
        // No-op for production or preview environments.
    }
    
    public func fetchRecentEvents(count: Int) async -> [TransitionReceptionistAuditEvent] {
        return []
    }
    
    public func escalate(
        _ event: String,
        transitionID: String?,
        receptionistID: String?,
        role: String?,
        staffID: String?,
        context: String?
    ) async {
        if testMode {
            print("[TestMode] Escalate Event: \(event) | transitionID: \(transitionID ?? "nil") | receptionistID: \(receptionistID ?? "nil") | role: \(role ?? "nil") | staffID: \(staffID ?? "nil") | context: \(context ?? "nil")")
        }
        // No-op for production or preview environments.
    }
}

/// Manages assignment and revocation of transitions with comprehensive analytics, audit logging, and Trust Center compliance.
public class TransitionReceptionist {
    
    /// Maximum number of analytics events to keep in the buffer.
    private static let maxEventBufferSize = 20
    
    /// Buffer holding recent analytics audit events for diagnostics, audit, and compliance.
    private var analyticsEventBuffer: [TransitionReceptionistAuditEvent] = []
    
    /// The analytics logger used to record events.
    private let analyticsLogger: TransitionReceptionistAnalyticsLogger
    
    /**
     Initializes a new TransitionReceptionist instance.
     
     - Parameter analyticsLogger: The analytics logger to use for event logging.
     */
    public init(analyticsLogger: TransitionReceptionistAnalyticsLogger = NullTransitionReceptionistAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }
    
    /**
     Assigns a transition to a receptionist with audit and compliance tracking.
     
     - Parameters:
       - transitionID: The identifier of the transition to assign.
       - receptionistID: The identifier of the receptionist.
     
     This method logs the event and determines escalation based on critical keywords.
     */
    public func assignTransition(to transitionID: String, receptionist receptionistID: String) async {
        let event = NSLocalizedString("AssignTransitionEvent",
                                      value: "Assigned transition \(transitionID) to receptionist \(receptionistID)",
                                      comment: "Analytics event when a transition is assigned to a receptionist")
        let lowerTransitionID = transitionID.lowercased()
        let lowerReceptionistID = receptionistID.lowercased()
        let escalate = lowerTransitionID.contains("critical") || lowerReceptionistID.contains("critical")
        
        await logEvent(
            event,
            transitionID: transitionID,
            receptionistID: receptionistID,
            escalate: escalate
        )
        // Future implementation goes here.
    }
    
    /**
     Revokes a transition from a receptionist with audit and compliance tracking.
     
     - Parameters:
       - transitionID: The identifier of the transition to revoke.
       - receptionistID: The identifier of the receptionist.
     
     This method logs the event and determines escalation based on critical or risk keywords.
     */
    public func revokeTransition(from transitionID: String, receptionist receptionistID: String) async {
        let event = NSLocalizedString("RevokeTransitionEvent",
                                      value: "Revoked transition \(transitionID) from receptionist \(receptionistID)",
                                      comment: "Analytics event when a transition is revoked from a receptionist")
        let lowerTransitionID = transitionID.lowercased()
        let lowerReceptionistID = receptionistID.lowercased()
        let escalate = lowerTransitionID.contains("critical") || lowerReceptionistID.contains("critical") || lowerTransitionID.contains("risk") || lowerReceptionistID.contains("risk")
        
        await logEvent(
            event,
            transitionID: transitionID,
            receptionistID: receptionistID,
            escalate: escalate
        )
        // Future implementation goes here.
    }
    
    /**
     Records an audit log entry with escalation for Trust Center compliance.
     
     This method logs the event with escalate=true to ensure compliance.
     */
    public func auditLog() async {
        let event = NSLocalizedString("AuditLogEvent",
                                      value: "Audit log entry created",
                                      comment: "Event logged when an audit log entry is created")
        await logEvent(
            event,
            transitionID: nil,
            receptionistID: nil,
            escalate: true
        )
        // Future implementation goes here.
    }
    
    /**
     Provides diagnostic information summarizing recent audit events, including counts of escalated vs non-escalated events,
     last event role/context, and buffer size.
     
     - Returns: A string describing diagnostic info.
     */
    public func diagnostics() -> String {
        let totalEvents = analyticsEventBuffer.count
        let escalatedCount = analyticsEventBuffer.filter { $0.escalate }.count
        let nonEscalatedCount = totalEvents - escalatedCount
        let lastEvent = analyticsEventBuffer.last
        let lastRole = lastEvent?.role ?? NSLocalizedString("NoRole", value: "No Role", comment: "No role available")
        let lastContext = lastEvent?.context ?? NSLocalizedString("NoContext", value: "No Context", comment: "No context available")
        
        let diagnosticsString = NSLocalizedString("DiagnosticsInfo",
                                                  value: "Diagnostics: Total events: \(totalEvents), Escalated: \(escalatedCount), Non-Escalated: \(nonEscalatedCount), Last Event Role: \(lastRole), Last Event Context: \(lastContext)",
                                                  comment: "Summary of diagnostics information including event counts and last event details")
        return diagnosticsString
    }
    
    /**
     Retrieves recent analytics audit events for admin or diagnostic purposes.
     
     - Returns: An array of recent analytics audit events, capped at the last 20 entries.
     */
    public func recentAnalyticsEvents() -> [TransitionReceptionistAuditEvent] {
        return analyticsEventBuffer
    }
    
    /// Logs an event to the analytics logger and stores it in the buffer with full audit context.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - transitionID: Optional transition identifier.
    ///   - receptionistID: Optional receptionist identifier.
    ///   - escalate: Whether the event should be escalated for compliance.
    private func logEvent(
        _ event: String,
        transitionID: String?,
        receptionistID: String?,
        escalate: Bool
    ) async {
        let role = TransitionReceptionistAuditContext.role
        let staffID = TransitionReceptionistAuditContext.staffID
        let context = TransitionReceptionistAuditContext.context
        
        await analyticsLogger.logEvent(
            event,
            transitionID: transitionID,
            receptionistID: receptionistID,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        
        let auditEvent = TransitionReceptionistAuditEvent(
            timestamp: Date(),
            event: event,
            transitionID: transitionID,
            receptionistID: receptionistID,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.analyticsEventBuffer.append(auditEvent)
            if self.analyticsEventBuffer.count > TransitionReceptionist.maxEventBufferSize {
                self.analyticsEventBuffer.removeFirst(self.analyticsEventBuffer.count - TransitionReceptionist.maxEventBufferSize)
            }
        }
    }
}
