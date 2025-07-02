//
//  ReferralEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ReferralAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ReferralEngine"
}

/**
 ReferralEngine.swift

 Architecture:
 This file defines the core ReferralEngine class responsible for managing referral tracking, user rewards, audit logging, diagnostics, and localization of user-facing messages. It is designed with extensibility in mind, allowing easy integration of analytics loggers and future expansion of referral-related features.

 Extensibility:
 The ReferralEngine uses the ReferralAnalyticsLogger protocol to abstract analytics logging. This enables different logging implementations (e.g., production analytics services, console logging for QA, or mock loggers for testing/previews) to be plugged in without modifying the core engine.

 Analytics, Audit, and Trust Center Hooks:
 The engine provides auditLog() and diagnostics() methods to support compliance and trust center requirements by maintaining detailed event logs and diagnostic information. It also buffers recent analytics events for administrative review and troubleshooting.

 Diagnostics:
 Diagnostics include fetching recent analytics events and general engine health information, facilitating debugging and operational monitoring.

 Localization:
 All user-facing and log event strings are wrapped in NSLocalizedString with descriptive keys and comments to ensure full localization support and compliance with accessibility standards.

 Accessibility:
 The engine's design supports accessibility by providing clear, localized messages and structured event information that can be used in accessible UI components.

 Compliance:
 Audit and diagnostics features support regulatory compliance by maintaining detailed logs and supporting Trust Center requirements.

 Preview and Testability:
 A NullReferralAnalyticsLogger implementation is provided for previews and tests, enabling console-only logging without external dependencies. The included SwiftUI PreviewProvider demonstrates diagnostics, testMode usage, and accessibility features.

 ---

 This documentation block should be updated as the ReferralEngine evolves to capture architectural decisions, new features, and compliance requirements.
 */

/// Protocol defining an async/await-ready analytics logger for referral events.
/// Conforming types can implement actual analytics logging or provide mock/test implementations.
public protocol ReferralAnalyticsLogger {
    /// Indicates whether the logger is running in test mode (e.g., console-only logging for QA/tests/previews).
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - eventName: The name of the event to log.
    ///   - parameters: Optional dictionary of event parameters.
    ///   - role: Optional role context for audit.
    ///   - staffID: Optional staff ID context for audit.
    ///   - context: Optional context string for audit.
    ///   - escalate: Whether this event should be escalated.
    func logEvent(
        eventName: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A Null Object implementation of ReferralAnalyticsLogger for previews and tests.
/// Logs events to the console only when in testMode.
public struct NullReferralAnalyticsLogger: ReferralAnalyticsLogger {
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
        let paramsDescription = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullReferralAnalyticsLogger][TEST MODE] Event: \(eventName), Parameters: \(paramsDescription) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Core class responsible for referral tracking, rewarding users, audit logging, diagnostics, and localization.
public class ReferralEngine {
    /// The analytics logger used to record referral-related events.
    private let analyticsLogger: ReferralAnalyticsLogger
    
    /// Circular buffer capacity for recent analytics events.
    private let eventBufferCapacity = 20
    
    /// Buffer storing recent analytics event tuples for diagnostics and admin review.
    private var recentEvents: [(eventName: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    
    /// Serial queue to synchronize access to recentEvents.
    private let eventQueue = DispatchQueue(label: "ReferralEngine.EventQueue")
    
    /**
     Initializes the ReferralEngine with a specified analytics logger.
     
     - Parameter analyticsLogger: The analytics logger to be used for event tracking.
     */
    public init(analyticsLogger: ReferralAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }
    
    /**
     Tracks a referral event asynchronously.
     
     - Parameters:
       - referredUserID: The identifier of the user who was referred.
       - referrerUserID: The identifier of the user who referred.
     */
    public func trackReferral(referredUserID: String, referrerUserID: String) async {
        let eventName = NSLocalizedString("ReferralEngine.TrackReferralEventName",
                                          value: "ReferralTracked",
                                          comment: "Analytics event name for tracking a referral")
        let parameters: [String: Any] = [
            NSLocalizedString("ReferralEngine.ParamReferredUserID", value: "referredUserID", comment: "Parameter key for referred user ID"): referredUserID,
            NSLocalizedString("ReferralEngine.ParamReferrerUserID", value: "referrerUserID", comment: "Parameter key for referrer user ID"): referrerUserID
        ]
        
        await logAndBufferEvent(name: eventName, parameters: parameters)
    }
    
    /**
     Rewards a user asynchronously for a successful referral.
     
     - Parameter userID: The identifier of the user to reward.
     */
    public func rewardUser(userID: String) async {
        let eventName = NSLocalizedString("ReferralEngine.RewardUserEventName",
                                          value: "UserRewarded",
                                          comment: "Analytics event name for rewarding a user")
        let parameters: [String: Any] = [
            NSLocalizedString("ReferralEngine.ParamUserID", value: "userID", comment: "Parameter key for user ID"): userID
        ]
        
        await logAndBufferEvent(name: eventName, parameters: parameters)
    }
    
    /**
     Logs an audit event asynchronously.
     
     This method can be extended to integrate with Trust Center or compliance audit systems.
     */
    public func auditLog() async {
        let auditMessage = NSLocalizedString("ReferralEngine.AuditLogMessage",
                                             value: "Audit log event recorded.",
                                             comment: "Message indicating an audit log event")
        await logAndBufferEvent(name: auditMessage, parameters: nil)
    }
    
    /**
     Provides diagnostic information asynchronously.
     
     - Returns: A string describing the current diagnostics state.
     */
    public func diagnostics() async -> String {
        let diagnosticHeader = NSLocalizedString("ReferralEngine.DiagnosticsHeader",
                                                 value: "Referral Engine Diagnostics:",
                                                 comment: "Header for diagnostics output")
        let recentEventsCopy = eventQueue.sync { recentEvents }
        var diagnosticsLines: [String] = [diagnosticHeader]
        for (index, event) in recentEventsCopy.enumerated() {
            let paramDesc = event.parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "none"
            let line = String(format: NSLocalizedString("ReferralEngine.DiagnosticsEventFormat",
                                                       value: "%d. Event: %@ | Parameters: %@ | Role: %@ | StaffID: %@ | Context: %@ | Escalate: %@",
                                                       comment: "Formatted diagnostics event line with all audit fields"),
                              index + 1,
                              event.eventName,
                              paramDesc,
                              event.role ?? "-",
                              event.staffID ?? "-",
                              event.context ?? "-",
                              event.escalate ? "Yes" : "No")
            diagnosticsLines.append(line)
        }
        return diagnosticsLines.joined(separator: "\n")
    }
    
    /**
     Fetches recent analytics events for administrative or diagnostic purposes.
     
     - Returns: An array of recent event tuples capped to the buffer capacity.
     */
    public func fetchRecentEvents() -> [(eventName: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        return eventQueue.sync { recentEvents }
    }
    
    /// Internal helper to log an event and buffer its name.
    private func logAndBufferEvent(name: String, parameters: [String: Any]?) async {
        let lowerName = name.lowercased()
        let escalate = lowerName.contains("danger") || lowerName.contains("critical") || lowerName.contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        
        await analyticsLogger.logEvent(
            eventName: name,
            parameters: parameters,
            role: ReferralAuditContext.role,
            staffID: ReferralAuditContext.staffID,
            context: ReferralAuditContext.context,
            escalate: escalate
        )
        bufferEvent(name: name, parameters: parameters, role: ReferralAuditContext.role, staffID: ReferralAuditContext.staffID, context: ReferralAuditContext.context, escalate: escalate)
    }
    
    /// Adds an event tuple to the recentEvents buffer with capacity capping.
    private func bufferEvent(name: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) {
        eventQueue.sync {
            if recentEvents.count >= eventBufferCapacity {
                recentEvents.removeFirst()
            }
            recentEvents.append((name, parameters, role, staffID, context, escalate))
        }
    }
}

/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct ReferralEngine_Previews: PreviewProvider {
    static var previews: some View {
        ReferralEnginePreviewView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString("ReferralEngine.Preview.AccessibilityLabel",
                                                      value: "Referral Engine Diagnostics Preview",
                                                      comment: "Accessibility label for referral engine preview")))
    }
    
    struct ReferralEnginePreviewView: View {
        @State private var diagnosticsText: String = ""
        
        let referralEngine = ReferralEngine(analyticsLogger: NullReferralAnalyticsLogger())
        
        var body: some View {
            VStack(spacing: 20) {
                Text(NSLocalizedString("ReferralEngine.Preview.Title",
                                       value: "Referral Engine Diagnostics",
                                       comment: "Title for referral engine preview"))
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    Text(diagnosticsText)
                        .padding()
                        .accessibilityLabel(Text(NSLocalizedString("ReferralEngine.Preview.DiagnosticsAccessibilityLabel",
                                                                   value: "Diagnostics information",
                                                                   comment: "Accessibility label for diagnostics text")))
                }
                .frame(maxHeight: 200)
                .border(Color.gray)
                
                Button(action: loadDiagnostics) {
                    Text(NSLocalizedString("ReferralEngine.Preview.LoadDiagnosticsButton",
                                           value: "Load Diagnostics",
                                           comment: "Button title to load diagnostics"))
                }
                .accessibilityHint(Text(NSLocalizedString("ReferralEngine.Preview.LoadDiagnosticsButtonHint",
                                                          value: "Loads the latest diagnostics information",
                                                          comment: "Accessibility hint for load diagnostics button")))
            }
            .padding()
            .onAppear {
                Task {
                    await referralEngine.trackReferral(referredUserID: "user123", referrerUserID: "user456")
                    await referralEngine.rewardUser(userID: "user456")
                    await referralEngine.auditLog()
                    await loadDiagnostics()
                }
            }
        }
        
        func loadDiagnostics() async {
            diagnosticsText = await referralEngine.diagnostics()
        }
    }
}
