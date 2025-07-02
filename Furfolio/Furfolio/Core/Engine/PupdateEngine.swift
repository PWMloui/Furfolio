//
//  PupdateEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 PupdateEngine.swift

 Architecture:
 This file defines the core PupdateEngine class responsible for managing "pupdates" — updates related to pets in the Furfolio app.
 The engine supports asynchronous operations using Swift's async/await pattern for smooth integration with modern Swift concurrency.
 
 Extensibility:
 The design includes a protocol (PupdateAnalyticsLogger) for analytics logging, allowing easy swapping of analytics backends.
 The engine is structured to support additional features like audit logging, diagnostics, and localization without modifying core logic.
 
 Analytics / Audit / Trust Center Hooks:
 The PupdateAnalyticsLogger protocol defines async logging methods and a testMode flag for QA/test environments.
 Audit logs and diagnostics methods are stubbed for future integration with Trust Center or compliance frameworks.
 
 Diagnostics:
 The engine provides a diagnostics() method returning diagnostic info, useful for debugging and support.
 A capped buffer of the last 20 analytics events is maintained for admin review or diagnostics.
 
 Localization:
 All user-facing and log event strings are wrapped with NSLocalizedString for full localization support.
 Keys, default values, and descriptive comments are provided for translators and compliance purposes.
 
 Accessibility:
 Accessibility considerations are supported via localized strings and design for future accessibility feature integration.
 
 Compliance:
 The design anticipates compliance requirements by including auditLog() stubs and detailed logging.
 
 Preview / Testability:
 A NullPupdateAnalyticsLogger is provided for previews and tests to avoid side effects.
 A SwiftUI PreviewProvider demonstrates diagnostics output, testMode usage, and accessibility features.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct PupdateAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "PupdateEngine"
}

/// Protocol defining async analytics logging capabilities.
/// Conforming types can implement custom analytics backends.
/// The `testMode` property indicates whether only console logging should be performed (e.g., in QA, tests, or previews).
public protocol PupdateAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - eventName: The name of the event.
    ///   - parameters: Optional dictionary of event parameters.
    ///   - role: Optional role of the user/session.
    ///   - staffID: Optional staff identifier.
    ///   - context: Optional context string.
    ///   - escalate: Flag indicating if the event should be escalated.
    func logEvent(
        eventName: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-op analytics logger for use in previews and tests.
/// Implements console-only logging and disables external analytics calls.
public struct NullPupdateAnalyticsLogger: PupdateAnalyticsLogger {
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
        print("[NullPupdateAnalyticsLogger][TEST MODE] Event: \(eventName), Parameters: \(paramsDescription) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Core engine class managing pupdates and related features.
public class PupdateEngine {
    
    /// Maximum number of analytics events to keep in buffer for diagnostics.
    private let maxAnalyticsBufferSize = 20
    
    /// Buffer holding recent analytics events for diagnostics and admin review.
    private var analyticsEventBuffer: [(eventName: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    
    /// Analytics logger instance used for logging events.
    public var analyticsLogger: PupdateAnalyticsLogger
    
    /// Initializes the engine with a given analytics logger.
    /// - Parameter analyticsLogger: An object conforming to PupdateAnalyticsLogger.
    public init(analyticsLogger: PupdateAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }
    
    // MARK: - Pupdate Management
    
    /// Creates a new pupdate asynchronously.
    /// - Parameter content: The content of the pupdate.
    /// - Returns: A unique identifier for the created pupdate.
    public func createPupdate(content: String) async -> String {
        let eventName = NSLocalizedString("PupdateEngine_CreatePupdate_Event",
                                          value: "CreatePupdate",
                                          comment: "Analytics event name for creating a pupdate")
        await logAnalyticsEvent(eventName: eventName, parameters: ["content": content])
        
        // Placeholder stub: Generate a UUID for the new pupdate.
        let newPupdateID = UUID().uuidString
        
        // User-facing log message example:
        let logMessage = NSLocalizedString("PupdateEngine_CreatePupdate_Success",
                                           value: "Successfully created a new pupdate.",
                                           comment: "Log message after creating a pupdate")
        print(logMessage)
        
        return newPupdateID
    }
    
    /// Edits an existing pupdate asynchronously.
    /// - Parameters:
    ///   - pupdateID: The identifier of the pupdate to edit.
    ///   - newContent: The new content for the pupdate.
    public func editPupdate(pupdateID: String, newContent: String) async {
        let eventName = NSLocalizedString("PupdateEngine_EditPupdate_Event",
                                          value: "EditPupdate",
                                          comment: "Analytics event name for editing a pupdate")
        await logAnalyticsEvent(eventName: eventName, parameters: ["pupdateID": pupdateID, "newContent": newContent])
        
        // Placeholder stub: Simulate editing pupdate.
        let logMessage = NSLocalizedString("PupdateEngine_EditPupdate_Success",
                                           value: "Successfully edited pupdate with ID: \(pupdateID).",
                                           comment: "Log message after editing a pupdate")
        print(logMessage)
    }
    
    /// Fetches pupdates asynchronously.
    /// - Returns: An array of pupdate strings.
    public func fetchPupdates() async -> [String] {
        let eventName = NSLocalizedString("PupdateEngine_FetchPupdates_Event",
                                          value: "FetchPupdates",
                                          comment: "Analytics event name for fetching pupdates")
        await logAnalyticsEvent(eventName: eventName, parameters: nil)
        
        // Placeholder stub: Return dummy pupdates.
        let pupdates = [
            NSLocalizedString("PupdateEngine_FetchPupdates_Dummy1",
                              value: "Buddy is feeling great today!",
                              comment: "Dummy pupdate 1"),
            NSLocalizedString("PupdateEngine_FetchPupdates_Dummy2",
                              value: "Luna took a long nap in the sun.",
                              comment: "Dummy pupdate 2")
        ]
        
        return pupdates
    }
    
    // MARK: - Audit Logging
    
    /// Stub method for audit logging, to be integrated with Trust Center or compliance frameworks.
    public func auditLog() {
        let auditMessage = NSLocalizedString("PupdateEngine_AuditLog_Message",
                                             value: "Audit log entry created.",
                                             comment: "Audit log message stub")
        print(auditMessage)
        // Future implementation goes here.
    }
    
    // MARK: - Diagnostics
    
    /// Returns diagnostic information about the engine and recent events.
    /// - Returns: A dictionary of diagnostic info.
    public func diagnostics() -> [String: Any] {
        let diagnosticsMessage = NSLocalizedString("PupdateEngine_Diagnostics_Message",
                                                   value: "Gathering diagnostics information.",
                                                   comment: "Diagnostics info message")
        print(diagnosticsMessage)
        
        return [
            "analyticsEventBuffer": analyticsEventBuffer,
            "analyticsLoggerTestMode": analyticsLogger.testMode
        ]
    }
    
    // MARK: - Analytics Event Buffer Management
    
    /// Logs an analytics event and stores it in the capped buffer.
    /// - Parameters:
    ///   - eventName: The name of the event.
    ///   - parameters: Optional parameters for the event.
    private func logAnalyticsEvent(eventName: String, parameters: [String: Any]?) async {
        let escalate = eventName.lowercased().contains("danger") || eventName.lowercased().contains("critical") || eventName.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.analyticsEventBuffer.append((eventName: eventName, parameters: parameters, role: PupdateAuditContext.role, staffID: PupdateAuditContext.staffID, context: PupdateAuditContext.context, escalate: escalate))
            if self.analyticsEventBuffer.count > self.maxAnalyticsBufferSize {
                self.analyticsEventBuffer.removeFirst()
            }
        }
        
        await analyticsLogger.logEvent(
            eventName: eventName,
            parameters: parameters,
            role: PupdateAuditContext.role,
            staffID: PupdateAuditContext.staffID,
            context: PupdateAuditContext.context,
            escalate: escalate
        )
    }
    
    /// Public API to fetch recent analytics events for admin or diagnostics.
    /// - Returns: An array of tuples containing event names, parameters, and audit fields.
    public func fetchRecentAnalyticsEvents() -> [(eventName: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        return analyticsEventBuffer
    }
}

// MARK: - SwiftUI PreviewProvider for diagnostics and testMode demonstration

#if DEBUG
import SwiftUI

struct PupdateEngine_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .accessibilityLabel(Text(NSLocalizedString("PupdateEngine_Previews_AccessibilityLabel",
                                                      value: "Pupdate Engine Diagnostics Preview",
                                                      comment: "Accessibility label for PupdateEngine preview diagnostics view")))
            .padding()
    }
    
    struct DiagnosticsView: View {
        @StateObject private static var engine = PupdateEngine(analyticsLogger: NullPupdateAnalyticsLogger())
        @State private var diagnosticsInfo: [String: Any] = [:]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("PupdateEngine_Previews_Title",
                                       value: "Pupdate Engine Diagnostics",
                                       comment: "Title for diagnostics preview"))
                    .font(.headline)
                
                Button(NSLocalizedString("PupdateEngine_Previews_RunDiagnosticsButton",
                                        value: "Run Diagnostics",
                                        comment: "Button title to run diagnostics")) {
                    diagnosticsInfo = Self.engine.diagnostics()
                }
                .buttonStyle(.borderedProminent)
                
                if let buffer = diagnosticsInfo["analyticsEventBuffer"] as? [(eventName: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)], !buffer.isEmpty {
                    Text(NSLocalizedString("PupdateEngine_Previews_DiagnosticsOutput",
                                           value: "Diagnostics Output:",
                                           comment: "Label for diagnostics output"))
                        .font(.subheadline)
                        .bold()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(buffer.enumerated()), id: \.offset) { index, event in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Event \(index + 1): \(event.eventName)")
                                        .font(.footnote)
                                        .bold()
                                    Text("Parameters: \(event.parameters?.description ?? "none")")
                                        .font(.footnote)
                                    Text("Role: \(event.role ?? "-")")
                                        .font(.footnote)
                                    Text("StaffID: \(event.staffID ?? "-")")
                                        .font(.footnote)
                                    Text("Context: \(event.context ?? "-")")
                                        .font(.footnote)
                                    Text("Escalate: \(event.escalate ? "Yes" : "No")")
                                        .font(.footnote)
                                }
                                .padding(6)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(6)
                            }
                        }
                        .padding()
                        .accessibilityLabel(Text(NSLocalizedString("PupdateEngine_Previews_DiagnosticsOutput_AccessibilityLabel",
                                                                  value: "Diagnostics output details",
                                                                  comment: "Accessibility label for diagnostics output text")))
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}
#endif
