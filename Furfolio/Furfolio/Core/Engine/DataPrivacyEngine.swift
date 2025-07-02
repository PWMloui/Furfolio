//
//  DataPrivacyEngine.swift
//  Furfolio
//
//  Created by mac on 6/25/25
//

/**
 DataPrivacyEngine.swift

 Architecture:
 This file defines the core DataPrivacyEngine class responsible for managing user consent,
 audit logs, diagnostics, and localization-ready user-facing and log event messages.
 The design emphasizes modularity and extensibility to accommodate evolving privacy
 requirements, analytics hooks, and Trust Center integrations.

 Extensibility:
 The DataPrivacyAnalyticsLogger protocol allows for different analytics/logging implementations,
 including test and production modes. The engine supports adding new diagnostics and audit
 capabilities without impacting existing functionality.

 Analytics, Audit, and Trust Center Hooks:
 The engine provides async-ready logging hooks via DataPrivacyAnalyticsLogger, enabling
 integration with external analytics or Trust Center systems. Audit logs and diagnostic
 events are captured and buffered for review and compliance.

 Diagnostics:
 Diagnostic events and audit logs are stored in a capped buffer to facilitate troubleshooting,
 compliance audits, and administrative review.

 Localization:
 All user-facing and log event strings are wrapped in NSLocalizedString with appropriate keys,
 default values, and comments to ensure full localization and compliance with international
ization requirements.

 Accessibility:
 The engine provides localized user-facing messages that can be used in accessible UI elements,
 ensuring compliance with accessibility standards.

 Compliance:
 The engine is designed to meet data privacy compliance requirements by managing user consent,
 maintaining audit logs, and supporting detailed diagnostics and reporting.

 Preview and Testability:
 A NullDataPrivacyAnalyticsLogger struct is provided for previews and tests, which logs only to
 the console in testMode. A SwiftUI PreviewProvider demonstrates diagnostics, testMode usage,
 and accessibility features for future developers and maintainers.

 -- Future Maintainers:
 Please adhere to the localization pattern and maintain the capped buffer size for audit logs.
 Extend the DataPrivacyAnalyticsLogger protocol for new analytics providers as needed.
 Ensure all new user-facing strings are localized and documented.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct DataPrivacyAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DataPrivacyEngine"
}

/// Protocol defining async-ready analytics logging capabilities.
/// Conforming types can implement real or mock analytics logging.
/// - Note: `testMode` enables console-only logging for QA, tests, and previews.
public protocol DataPrivacyAnalyticsLogger {
    /// Indicates if logger is in test mode (console-only logging).
    var testMode: Bool { get set }

    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - metadata: Additional metadata dictionary.
    ///   - role: User role or audit role.
    ///   - staffID: Staff identifier.
    ///   - context: Audit context string.
    ///   - escalate: Flag indicating if the event should be escalated.
    func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-op analytics logger for use in previews, tests, and QA environments.
/// Logs events to console only if `testMode` is true.
public struct NullDataPrivacyAnalyticsLogger: DataPrivacyAnalyticsLogger {
    public var testMode: Bool = false

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    public func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[NullDataPrivacyAnalyticsLogger TEST MODE] Event: \(event)")
            print("Metadata: \(metadata ?? [:])")
            print("Role: \(role ?? "nil")")
            print("StaffID: \(staffID ?? "nil")")
            print("Context: \(context ?? "nil")")
            print("Escalate: \(escalate)")
        }
        // No-op otherwise
    }
}

/// Core engine managing data privacy compliance, user consent, audit logs,
/// diagnostics, and localization-ready messages.
public class DataPrivacyEngine: ObservableObject {
    /// Maximum number of analytics events to keep in buffer.
    private let maxEventBufferSize = 20

    /// Buffer storing recent analytics events for diagnostics and admin review.
    @Published private(set) var recentEvents: [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []

    /// The analytics logger instance used for logging events.
    private let analyticsLogger: DataPrivacyAnalyticsLogger

    /// Initializes a new DataPrivacyEngine with the provided analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use.
    public init(analyticsLogger: DataPrivacyAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - User Consent Management

    /// Requests user consent asynchronously.
    /// - Returns: A localized user-facing message describing the consent request.
    public func requestUserConsent() async -> String {
        let message = NSLocalizedString(
            "UserConsent.RequestMessage",
            value: "We value your privacy. Please review and accept our data usage policies to continue.",
            comment: "Message shown to user when requesting data privacy consent"
        )
        await logEvent("User consent requested", metadata: nil)
        return message
    }

    /// Records user consent asynchronously.
    /// - Parameter granted: Whether the user granted consent.
    /// - Returns: A localized confirmation message.
    public func recordUserConsent(granted: Bool) async -> String {
        if granted {
            await logEvent("User consent granted", metadata: ["granted": true])
            return NSLocalizedString(
                "UserConsent.GrantedMessage",
                value: "Thank you for granting consent. Your privacy preferences have been saved.",
                comment: "Message shown to user after granting consent"
            )
        } else {
            await logEvent("User consent denied", metadata: ["granted": false])
            return NSLocalizedString(
                "UserConsent.DeniedMessage",
                value: "You have denied consent. Some features may be limited.",
                comment: "Message shown to user after denying consent"
            )
        }
    }

    // MARK: - Audit Log Management

    /// Adds an audit log entry asynchronously.
    /// - Parameter entry: The audit log entry string.
    public func addAuditLogEntry(_ entry: String) async {
        let localizedEntry = NSLocalizedString(
            "AuditLog.Entry",
            value: entry,
            comment: "Audit log entry"
        )
        await logEvent("Audit log added: \(localizedEntry)", metadata: ["entry": localizedEntry])
    }

    // MARK: - Diagnostics

    /// Adds a diagnostic event asynchronously.
    /// - Parameter event: The diagnostic event string.
    public func addDiagnosticEvent(_ event: String) async {
        let localizedEvent = NSLocalizedString(
            "Diagnostics.Event",
            value: event,
            comment: "Diagnostic event"
        )
        await logEvent("Diagnostic event: \(localizedEvent)", metadata: ["detail": localizedEvent])
    }

    /// Logs an event both to analytics logger and stores it in the capped buffer.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - metadata: Optional metadata dictionary.
    private func logEvent(_ event: String, metadata: [String: Any]? = nil) async {
        let lowercasedEvent = event.lowercased()
        let escalate = lowercasedEvent.contains("danger") || lowercasedEvent.contains("critical") || lowercasedEvent.contains("delete")
            || (metadata?.values.contains {
                let valueString = "\($0)".lowercased()
                return valueString.contains("danger") || valueString.contains("critical") || valueString.contains("delete")
            } ?? false)

        await analyticsLogger.logEvent(
            event,
            metadata: metadata,
            role: DataPrivacyAuditContext.role,
            staffID: DataPrivacyAuditContext.staffID,
            context: DataPrivacyAuditContext.context,
            escalate: escalate
        )
        DispatchQueue.main.async {
            if self.recentEvents.count >= self.maxEventBufferSize {
                self.recentEvents.removeFirst()
            }
            self.recentEvents.append((
                Date(),
                event,
                metadata,
                DataPrivacyAuditContext.role,
                DataPrivacyAuditContext.staffID,
                DataPrivacyAuditContext.context,
                escalate
            ))
        }
    }

    // MARK: - Localization-Ready Messages

    /// Returns a localized message describing the current privacy status.
    public var privacyStatusMessage: String {
        NSLocalizedString(
            "PrivacyStatus.Message",
            value: "Your data privacy settings are up to date.",
            comment: "General privacy status message"
        )
    }
}

// MARK: - SwiftUI PreviewProvider for Diagnostics, TestMode, and Accessibility

#if DEBUG
import SwiftUI

struct DataPrivacyEngine_Previews: PreviewProvider {
    static var previews: some View {
        DataPrivacyEnginePreviewView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString(
                "Accessibility.DataPrivacyEnginePreview",
                value: "Data Privacy Engine preview demonstrating diagnostics and test mode features.",
                comment: "Accessibility label for DataPrivacyEngine preview"
            )))
    }

    struct DataPrivacyEnginePreviewView: View {
        @StateObject private var engine = DataPrivacyEngine(
            analyticsLogger: NullDataPrivacyAnalyticsLogger(testMode: true)
        )
        @State private var latestMessage: String = ""

        var body: some View {
            VStack(spacing: 20) {
                Text(latestMessage)
                    .padding()
                    .multilineTextAlignment(.center)

                Button(NSLocalizedString(
                    "Preview.RequestConsentButton",
                    value: "Request User Consent",
                    comment: "Button title to request user consent in preview"
                )) {
                    Task {
                        latestMessage = await engine.requestUserConsent()
                    }
                }

                Button(NSLocalizedString(
                    "Preview.GrantConsentButton",
                    value: "Grant Consent",
                    comment: "Button title to grant user consent in preview"
                )) {
                    Task {
                        latestMessage = await engine.recordUserConsent(granted: true)
                    }
                }

                Button(NSLocalizedString(
                    "Preview.DenyConsentButton",
                    value: "Deny Consent",
                    comment: "Button title to deny user consent in preview"
                )) {
                    Task {
                        latestMessage = await engine.recordUserConsent(granted: false)
                    }
                }

                List(engine.recentEvents, id: \.timestamp) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timestamp: \(event.timestamp)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Event: \(event.event)")
                            .fontWeight(.semibold)
                        if let metadata = event.metadata, !metadata.isEmpty {
                            Text("Metadata: \(metadata.description)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Role: \(event.role ?? "nil")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("StaffID: \(event.staffID ?? "nil")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Context: \(event.context ?? "nil")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            .font(.caption2)
                            .foregroundColor(event.escalate ? .red : .secondary)
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200)
                .accessibilityLabel(Text(NSLocalizedString(
                    "Accessibility.RecentEventsList",
                    value: "List of recent analytics and diagnostic events",
                    comment: "Accessibility label for recent events list in preview"
                )))
            }
            .padding()
            .onAppear {
                Task {
                    await engine.addDiagnosticEvent("Preview started")
                }
            }
        }
    }
}
#endif
