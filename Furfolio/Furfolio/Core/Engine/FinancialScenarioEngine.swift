//
//  FinancialScenarioEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct FinancialScenarioAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "FinancialScenarioEngine"
}

/**
 FinancialScenarioEngine.swift

 Architecture:
 This file defines the core FinancialScenarioEngine class responsible for modeling and simulating various financial scenarios.
 It is designed with extensibility in mind, allowing easy integration of new financial models, analytics hooks, and localization support.

 Extensibility:
 - FinancialScenarioAnalyticsLogger protocol enables plugging in different analytics implementations asynchronously.
 - The engine provides stub methods for audit logs, diagnostics, and localization-ready messaging to facilitate future expansion.

 Analytics / Audit / Trust Center Hooks:
 - Analytics events are logged asynchronously via FinancialScenarioAnalyticsLogger.
 - A capped buffer stores the last 20 analytics events for diagnostics and audit purposes.
 - Audit logging and diagnostics methods provide hooks for Trust Center compliance and monitoring.

 Diagnostics:
 - diagnostics() method returns current engine state and recent analytics events for troubleshooting.
 - PreviewProvider demonstrates diagnostics output and accessibility features.

 Localization:
 - All user-facing and log event strings are wrapped in NSLocalizedString with descriptive keys and comments.
 - This ensures full localization and compliance with internationalization standards.

 Accessibility:
 - PreviewProvider includes accessibility features demonstration to ensure compliance with accessibility guidelines.

 Compliance:
 - Audit and diagnostics hooks support compliance with financial regulations and internal policies.
 - Localization and accessibility considerations support global and inclusive use.

 Preview / Testability:
 - NullFinancialScenarioAnalyticsLogger provides a no-op analytics logger for testing and previews.
 - PreviewProvider shows usage of diagnostics, testMode, and accessibility features for maintainers and developers.

*/

/// Protocol defining asynchronous analytics logging capabilities for FinancialScenarioEngine.
/// Conforming types can implement custom analytics backends.
/// The `testMode` property enables console-only logging for QA, tests, and previews.
public protocol FinancialScenarioAnalyticsLogger {
    /// Indicates whether the logger is in test mode, enabling console-only logging.
    var testMode: Bool { get }
    /// Logs an analytics event asynchronously with audit context.
    func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-operation analytics logger used for previews, tests, and scenarios where analytics are not required.
public struct NullFinancialScenarioAnalyticsLogger: FinancialScenarioAnalyticsLogger {
    public let testMode = true
    public init() {}
    public func logEvent(
        _ event: String,
        metadata: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        print("Preview/Test Analytics Event: \(event) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Main engine class responsible for modeling financial scenarios, analytics, audit logs, diagnostics, and localization.
public class FinancialScenarioEngine: ObservableObject {
    
    /// The analytics logger used by the engine to report events.
    private let analyticsLogger: FinancialScenarioAnalyticsLogger
    
    /// A capped buffer storing the last 20 analytics events for diagnostics and audit.
    private var recentAnalyticsEvents: [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let analyticsEventBufferLimit = 20
    
    /// Initializes the FinancialScenarioEngine with a specified analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use. Defaults to NullFinancialScenarioAnalyticsLogger.
    public init(analyticsLogger: FinancialScenarioAnalyticsLogger = NullFinancialScenarioAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }
    
    /// Models a financial scenario asynchronously.
    /// This is a stub method to be implemented with actual scenario modeling logic.
    /// - Parameter parameters: A dictionary of parameters for the scenario.
    public func modelScenario(parameters: [String: Any]) async {
        let startMessage = NSLocalizedString("FinancialScenarioEngine.modelScenario.start",
                                             value: "Starting financial scenario modeling.",
                                             comment: "Log message indicating the start of scenario modeling")
        await logAnalyticsEvent(startMessage, metadata: parameters)
        
        // TODO: Implement scenario modeling logic here
        
        let endMessage = NSLocalizedString("FinancialScenarioEngine.modelScenario.complete",
                                           value: "Completed financial scenario modeling.",
                                           comment: "Log message indicating the completion of scenario modeling")
        await logAnalyticsEvent(endMessage, metadata: parameters)
    }
    
    /// Records an audit log entry asynchronously.
    /// This stub method can be expanded to integrate with audit logging systems.
    /// - Parameter entry: The audit log entry string.
    public func auditLog(_ entry: String) async {
        let auditEntry = NSLocalizedString("FinancialScenarioEngine.auditLog.entry",
                                           value: "Audit Log Entry: \(entry)",
                                           comment: "Formatted audit log entry")
        await logAnalyticsEvent(auditEntry, metadata: ["entry": entry])
        // TODO: Integrate with audit logging backend
    }
    
    /// Returns diagnostic information including recent analytics events.
    /// Useful for troubleshooting and Trust Center compliance.
    /// - Returns: A dictionary with diagnostic data.
    public func diagnostics() -> [String: Any] {
        let eventsDescription = recentAnalyticsEvents.map { entry in
            return [
                NSLocalizedString("FinancialScenarioEngine.diagnostics.timestampKey",
                                  value: "timestamp",
                                  comment: "Key for event timestamp in diagnostics"): entry.timestamp.description,
                NSLocalizedString("FinancialScenarioEngine.diagnostics.eventKey",
                                  value: "event",
                                  comment: "Key for event string in diagnostics"): entry.event,
                NSLocalizedString("FinancialScenarioEngine.diagnostics.metadataKey",
                                  value: "metadata",
                                  comment: "Key for metadata in diagnostics"): entry.metadata ?? [:],
                NSLocalizedString("FinancialScenarioEngine.diagnostics.roleKey",
                                  value: "role",
                                  comment: "Key for role in diagnostics"): entry.role ?? "",
                NSLocalizedString("FinancialScenarioEngine.diagnostics.staffIDKey",
                                  value: "staffID",
                                  comment: "Key for staffID in diagnostics"): entry.staffID ?? "",
                NSLocalizedString("FinancialScenarioEngine.diagnostics.contextKey",
                                  value: "context",
                                  comment: "Key for context in diagnostics"): entry.context ?? "",
                NSLocalizedString("FinancialScenarioEngine.diagnostics.escalateKey",
                                  value: "escalate",
                                  comment: "Key for escalate flag in diagnostics"): entry.escalate
            ]
        }
        return [
            NSLocalizedString("FinancialScenarioEngine.diagnostics.recentEventsKey",
                              value: "recentAnalyticsEvents",
                              comment: "Key for recent analytics events in diagnostics"): eventsDescription,
            NSLocalizedString("FinancialScenarioEngine.diagnostics.analyticsLoggerKey",
                              value: "analyticsLoggerType",
                              comment: "Key for analytics logger type in diagnostics"): String(describing: type(of: analyticsLogger))
        ]
    }
    
    /// Provides localized user-facing messages for a given key.
    /// - Parameter key: The localization key.
    /// - Returns: The localized string.
    public func localizedMessage(forKey key: String) -> String {
        return NSLocalizedString(key,
                                 value: "Message not found",
                                 comment: "Fallback message if localization key is missing")
    }
    
    /// Public API to fetch recent analytics events for admin or diagnostics purposes.
    /// - Returns: An array of the last 20 analytics event strings.
    public func fetchRecentAnalyticsEvents() -> [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        return recentAnalyticsEvents
    }
    
    /// Internal helper to log analytics events asynchronously and maintain the capped buffer.
    /// - Parameter event: The event string to log.
    /// - Parameter metadata: Optional metadata dictionary.
    private func logAnalyticsEvent(_ event: String, metadata: [String: Any]? = nil) async {
        let lowercasedEvent = event.lowercased()
        let escalate = lowercasedEvent.contains("danger") || lowercasedEvent.contains("critical") || lowercasedEvent.contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        
        await analyticsLogger.logEvent(
            event,
            metadata: metadata,
            role: FinancialScenarioAuditContext.role,
            staffID: FinancialScenarioAuditContext.staffID,
            context: FinancialScenarioAuditContext.context,
            escalate: escalate
        )
        
        recentAnalyticsEvents.append((Date(), event, metadata, FinancialScenarioAuditContext.role, FinancialScenarioAuditContext.staffID, FinancialScenarioAuditContext.context, escalate))
        if recentAnalyticsEvents.count > analyticsEventBufferLimit {
            recentAnalyticsEvents.removeFirst(recentAnalyticsEvents.count - analyticsEventBufferLimit)
        }
        
        if analyticsLogger.testMode {
            print("Analytics Event (Test Mode): \(event) \(metadata ?? [:]) | role:\(FinancialScenarioAuditContext.role ?? "-") staffID:\(FinancialScenarioAuditContext.staffID ?? "-") context:\(FinancialScenarioAuditContext.context ?? "-") escalate:\(escalate)")
        }
    }
}

#if DEBUG
import XCTest

/// PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct FinancialScenarioEngine_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString("FinancialScenarioEngine.preview.accessibilityLabel",
                                                      value: "Financial Scenario Engine Diagnostics Preview",
                                                      comment: "Accessibility label for diagnostics preview")))
    }
    
    /// A simple SwiftUI view to display diagnostics information for preview and testing.
    struct DiagnosticsView: View {
        @StateObject private var engine = FinancialScenarioEngine(analyticsLogger: NullFinancialScenarioAnalyticsLogger())
        
        @State private var diagnosticsData: [String: Any] = [:]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("FinancialScenarioEngine.preview.diagnosticsTitle",
                                       value: "Diagnostics Information",
                                       comment: "Title for diagnostics information in preview"))
                    .font(.headline)
                
                Button(action: fetchDiagnostics) {
                    Text(NSLocalizedString("FinancialScenarioEngine.preview.fetchDiagnosticsButton",
                                           value: "Fetch Diagnostics",
                                           comment: "Button title to fetch diagnostics"))
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
                .accessibilityHint(Text(NSLocalizedString("FinancialScenarioEngine.preview.fetchDiagnosticsHint",
                                                          value: "Fetches diagnostics information from the engine",
                                                          comment: "Accessibility hint for fetch diagnostics button")))
                
                if let events = diagnosticsData[NSLocalizedString("FinancialScenarioEngine.diagnostics.recentEventsKey",
                                                                 value: "recentAnalyticsEvents",
                                                                 comment: "Key for recent analytics events in diagnostics")] as? [[String: Any]], !events.isEmpty {
                    ScrollView {
                        ForEach(0..<events.count, id: \.self) { index in
                            let event = events[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.timestampKey",
                                                         value: "Timestamp",
                                                         comment: "Label for timestamp")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.timestampKey",
                                                                                                               value: "timestamp",
                                                                                                               comment: "Key for event timestamp in diagnostics")] ?? "")")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.eventKey",
                                                         value: "Event",
                                                         comment: "Label for event")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.eventKey",
                                                                                                               value: "event",
                                                                                                               comment: "Key for event string in diagnostics")] ?? "")")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.metadataKey",
                                                         value: "Metadata",
                                                         comment: "Label for metadata")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.metadataKey",
                                                                                                               value: "metadata",
                                                                                                               comment: "Key for metadata in diagnostics")] ?? [:])")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.roleKey",
                                                         value: "Role",
                                                         comment: "Label for role")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.roleKey",
                                                                                                               value: "role",
                                                                                                               comment: "Key for role in diagnostics")] ?? "")")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.staffIDKey",
                                                         value: "Staff ID",
                                                         comment: "Label for staffID")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.staffIDKey",
                                                                                                               value: "staffID",
                                                                                                               comment: "Key for staffID in diagnostics")] ?? "")")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.contextKey",
                                                         value: "Context",
                                                         comment: "Label for context")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.contextKey",
                                                                                                               value: "context",
                                                                                                               comment: "Key for context in diagnostics")] ?? "")")
                                    .font(.caption)
                                Text("\(NSLocalizedString("FinancialScenarioEngine.diagnostics.escalateKey",
                                                         value: "Escalate",
                                                         comment: "Label for escalate flag")): \(event[NSLocalizedString("FinancialScenarioEngine.diagnostics.escalateKey",
                                                                                                               value: "escalate",
                                                                                                               comment: "Key for escalate flag in diagnostics")] as? Bool == true ? "Yes" : "No")")
                                    .font(.caption)
                                Divider()
                            }
                            .padding(2)
                        }
                    }
                    .frame(maxHeight: 300)
                } else {
                    Text(NSLocalizedString("FinancialScenarioEngine.preview.noDiagnosticsData",
                                           value: "No diagnostics data available.",
                                           comment: "Message shown when no diagnostics data is present"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .onAppear {
                Task {
                    // Demonstrate logging some events in test mode
                    await engine.modelScenario(parameters: [:])
                    await engine.auditLog("Test audit entry")
                }
            }
        }
        
        private func fetchDiagnostics() {
            diagnosticsData = engine.diagnostics()
        }
    }
}
#endif
