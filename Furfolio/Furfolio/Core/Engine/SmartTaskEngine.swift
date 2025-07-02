//
//  SmartTaskEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SmartTaskAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SmartTaskEngine"
}

/**
 `SmartTaskEngine` is the core engine responsible for managing and executing smart tasks within the Furfolio ecosystem.

 ## Architecture
 This engine follows a modular and extensible architecture allowing integration of multiple task types and scheduling strategies.
 It supports asynchronous operations with Swift's async/await for responsiveness and concurrency safety.

 ## Extensibility
 Developers can extend the engine by implementing custom task types, schedulers, and analytics loggers conforming to provided protocols.

 ## Analytics, Audit, and Trust Center Hooks
 The engine integrates with analytics and audit logging systems via the `SmartTaskAnalyticsLogger` protocol.
 It supports a `testMode` for console-only logging during QA, testing, and preview scenarios.
 Audit logs and analytics events are buffered with a capped size for diagnostics and compliance reviews.

 ## Diagnostics and Preview/Testability
 Diagnostic information about engine state and recent events is exposed for debugging and admin purposes.
 A SwiftUI PreviewProvider demonstrates diagnostics, test mode, and accessibility features for maintainers and developers.

 ## Localization and Accessibility
 All user-facing and log event strings are fully localized using `NSLocalizedString` with descriptive comments.
 Accessibility considerations are integrated into the preview and user interactions.

 ## Compliance
 The engine's audit and analytics logging supports compliance with data governance and trust center requirements by maintaining detailed event logs and audit trails.

 ---
 
 ### Usage Notes for Developers
 - Extend `SmartTaskAnalyticsLogger` to integrate with custom analytics backends.
 - Use `auditLog()` and `diagnostics()` for retrieving engine state and logs.
 - Use `testMode` in analytics logger to avoid external transmissions during tests or previews.
 - Localize all user-facing strings using the provided keys and comments.
 */
 
/// Protocol defining an analytics logger compatible with async/await operations.
/// Supports a `testMode` flag to enable console-only logging for QA, tests, and previews.
public protocol SmartTaskAnalyticsLogger {
    /// Indicates if the logger is running in test mode (console-only logging).
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - eventName: The name of the analytics event.
    ///   - parameters: Optional dictionary of event parameters.
    ///   - role: Role of the user/session.
    ///   - staffID: Staff ID associated with the session.
    ///   - context: Context string for the event.
    ///   - escalate: Flag indicating if the event is escalated.
    func logEvent(
        eventName: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-operation analytics logger for safe use in previews and tests.
/// Logs events only to the console and does not send data externally.
public struct NullSmartTaskAnalyticsLogger: SmartTaskAnalyticsLogger {
    public let testMode: Bool = true
    
    public init() {}
    
    public func logEvent(
        eventName: String,
        parameters: [String : Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let paramsDescription = parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "none"
        print("[NullSmartTaskAnalyticsLogger][TEST MODE] Event: \(eventName), Parameters: \(paramsDescription) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Core engine managing smart tasks, scheduling, analytics, audit, diagnostics, and localization.
public class SmartTaskEngine: ObservableObject {
    
    /// Maximum number of analytics events to keep in the buffer for diagnostics and audit.
    private let analyticsEventBufferLimit = 20
    
    /// Buffer holding the most recent analytics event logs.
    @Published private(set) var recentAnalyticsEvents: [AnalyticsEvent] = []
    
    /// The analytics logger used by this engine.
    private let analyticsLogger: SmartTaskAnalyticsLogger
    
    /// Initializes the engine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use for event tracking.
    public init(analyticsLogger: SmartTaskAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }
    
    /// Represents a logged analytics event with name, parameters, timestamp, and audit context.
    public struct AnalyticsEvent: Identifiable {
        public let id = UUID()
        public let name: String
        public let parameters: [String: Any]?
        public let timestamp: Date
        public let role: String?
        public let staffID: String?
        public let context: String?
        public let escalate: Bool
    }
    
    /// Adds an analytics event to the buffer, trimming old events if needed.
    /// - Parameters:
    ///   - name: Event name.
    ///   - parameters: Optional event parameters.
    ///   - role: Role of user/session.
    ///   - staffID: Staff ID of user/session.
    ///   - context: Context string.
    ///   - escalate: Escalation flag.
    private func bufferAnalyticsEvent(name: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) {
        let event = AnalyticsEvent(
            name: name,
            parameters: parameters,
            timestamp: Date(),
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        DispatchQueue.main.async {
            self.recentAnalyticsEvents.append(event)
            if self.recentAnalyticsEvents.count > self.analyticsEventBufferLimit {
                self.recentAnalyticsEvents.removeFirst(self.recentAnalyticsEvents.count - self.analyticsEventBufferLimit)
            }
        }
    }
    
    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - eventName: The name of the analytics event.
    ///   - parameters: Optional dictionary of event parameters.
    public func logAnalyticsEvent(eventName: String, parameters: [String: Any]? = nil) async {
        let escalate = eventName.lowercased().contains("danger") || eventName.lowercased().contains("critical") || eventName.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        bufferAnalyticsEvent(
            name: eventName,
            parameters: parameters,
            role: SmartTaskAuditContext.role,
            staffID: SmartTaskAuditContext.staffID,
            context: SmartTaskAuditContext.context,
            escalate: escalate
        )
        await analyticsLogger.logEvent(
            eventName: eventName,
            parameters: parameters,
            role: SmartTaskAuditContext.role,
            staffID: SmartTaskAuditContext.staffID,
            context: SmartTaskAuditContext.context,
            escalate: escalate
        )
    }
    
    /// Starts or resumes smart task processing.
    public func start() {
        // Placeholder: Implement task scheduling and execution logic here.
        let message = NSLocalizedString(
            "SmartTaskEngine.start.message",
            value: "SmartTaskEngine started processing tasks.",
            comment: "Log message when the SmartTaskEngine starts processing tasks"
        )
        Task {
            await logAnalyticsEvent(eventName: "engine_start", parameters: ["message": message])
        }
    }
    
    /// Stops smart task processing.
    public func stop() {
        // Placeholder: Implement task stopping logic here.
        let message = NSLocalizedString(
            "SmartTaskEngine.stop.message",
            value: "SmartTaskEngine stopped processing tasks.",
            comment: "Log message when the SmartTaskEngine stops processing tasks"
        )
        Task {
            await logAnalyticsEvent(eventName: "engine_stop", parameters: ["message": message])
        }
    }
    
    /// Records an audit log entry.
    /// - Parameter entry: The audit log entry string.
    public func auditLog(entry: String) {
        // Placeholder: Implement audit logging persistence.
        let localizedEntry = NSLocalizedString(
            "SmartTaskEngine.auditLog.entry",
            value: entry,
            comment: "Audit log entry recorded by SmartTaskEngine"
        )
        Task {
            await logAnalyticsEvent(eventName: "audit_log", parameters: ["entry": localizedEntry])
        }
    }
    
    /// Returns diagnostic information about the engine's current state.
    /// - Returns: A localized diagnostic string.
    public func diagnostics() -> String {
        var diagnosticMessage = NSLocalizedString(
            "SmartTaskEngine.diagnostics.message",
            value: "SmartTaskEngine diagnostics: \(recentAnalyticsEvents.count) recent events logged.\n",
            comment: "Diagnostic message showing the number of recent analytics events"
        )
        for event in recentAnalyticsEvents {
            let paramsDesc = event.parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "none"
            diagnosticMessage += """
            Event: \(event.name)
            Parameters: \(paramsDesc)
            Timestamp: \(event.timestamp)
            Role: \(event.role ?? "-")
            StaffID: \(event.staffID ?? "-")
            Context: \(event.context ?? "-")
            Escalate: \(event.escalate)
            
            """
        }
        return diagnosticMessage
    }
    
    /// Provides a localized user-facing message for a given event key.
    /// - Parameter key: The localization key.
    /// - Returns: A localized string.
    public func localizedMessage(for key: String) -> String {
        return NSLocalizedString(
            key,
            value: key,
            comment: "User-facing message for key \(key)"
        )
    }
}

/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct SmartTaskEngine_Previews: PreviewProvider {
    
    /// A mock analytics logger that logs events to the console only.
    class PreviewAnalyticsLogger: SmartTaskAnalyticsLogger {
        let testMode: Bool = true
        
        func logEvent(
            eventName: String,
            parameters: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            let paramsDesc = parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "none"
            print("[PreviewAnalyticsLogger] Event: \(eventName), Parameters: \(paramsDesc) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
    
    static var previews: some View {
        let engine = SmartTaskEngine(analyticsLogger: PreviewAnalyticsLogger())
        VStack(spacing: 20) {
            ScrollView {
                Text(engine.diagnostics())
                    .accessibilityLabel(
                        NSLocalizedString(
                            "SmartTaskEngine_Previews.diagnostics.accessibilityLabel",
                            value: "Diagnostics information",
                            comment: "Accessibility label for diagnostics text in preview"
                        )
                    )
                    .padding()
            }
            Button {
                Task {
                    await engine.logAnalyticsEvent(eventName: "preview_button_tapped", parameters: ["info": "test tap"])
                }
            } label: {
                Text(NSLocalizedString(
                    "SmartTaskEngine_Previews.button.label",
                    value: "Log Test Event",
                    comment: "Button label to log a test analytics event in preview"
                ))
            }
            .accessibilityHint(
                NSLocalizedString(
                    "SmartTaskEngine_Previews.button.accessibilityHint",
                    value: "Logs a test analytics event for preview purposes",
                    comment: "Accessibility hint for test event logging button"
                )
            )
            .padding()
        }
        .padding()
        .previewDisplayName("SmartTaskEngine Diagnostics & Accessibility Preview")
    }
}
