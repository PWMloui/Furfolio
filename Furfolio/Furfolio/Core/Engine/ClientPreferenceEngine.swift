/**
 # ClientPreferenceEngine.swift
 ## Furfolio
 ---
 ### Architecture & Extensibility
 - **ClientPreferenceEngine** is the central class for fetching, updating, and analyzing client preference data.
 - Designed for extensibility: swap analytics loggers, add new audit/diagnostic hooks, and localize all user-facing messages.
 - Analytics and diagnostics are decoupled via protocol-oriented design; plug in new loggers for production, QA, or preview/test environments.
 - Supports compliance and auditability: all critical actions can be logged for Trust Center and regulatory requirements.
 - Accessibility and localization are first-class: all user-facing and log event messages are wrapped with `NSLocalizedString` for easy translation.
 - Diagnostics and admin tooling: exposes recent analytics events and diagnostics for troubleshooting and compliance review.
 - Preview/testability: includes a `NullClientPreferenceAnalyticsLogger` and SwiftUI `PreviewProvider` demonstrating diagnostics, testMode, and accessibility features.
 ---
 ## Key Components
 - `ClientPreferenceAnalyticsLogger`: Async/await-ready protocol for analytics logging. Supports testMode for console-only logging.
 - `NullClientPreferenceAnalyticsLogger`: No-op logger for tests/previews; can be replaced with mocks.
 - `ClientPreferenceEngine`: Main engine with methods for fetching, updating, analyzing preferences. Hooks into analytics, audit, diagnostics.
 - Event buffer: Capped at last 20 analytics events, retrievable via public API for admin/diagnostics.
 - All messages are localization-ready and accessible.
 ---
 ## For Future Maintainers
 - Add new analytics loggers by conforming to `ClientPreferenceAnalyticsLogger`.
 - Extend audit/diagnostics hooks as needed for regulatory, compliance, or Trust Center requirements.
 - Ensure all new user-facing strings are wrapped with `NSLocalizedString`.
 - Use PreviewProvider for testing diagnostics, accessibility, and testMode features.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ClientPreferenceAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ClientPreferenceEngine"
}

/// Protocol for analytics logging in the ClientPreferenceEngine.
/// Supports async/await and a testMode for console-only logging in QA/tests/previews.
protocol ClientPreferenceAnalyticsLogger {
    /// If true, logs are only sent to the console (no remote analytics).
    var testMode: Bool { get }
    /// Log an analytics event with a message and optional metadata, audit context, and escalate flag.
    func log(event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

/// Null logger for use in previews, tests, or when analytics should be disabled.
struct NullClientPreferenceAnalyticsLogger: ClientPreferenceAnalyticsLogger {
    let testMode: Bool = true
    func log(event: String, metadata: [String : Any]? = nil, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("NullClientPreferenceAnalyticsLogger (testMode):")
            print("Event:", event)
            print("Metadata:", metadata ?? [:])
            print("Role:", role ?? "nil")
            print("StaffID:", staffID ?? "nil")
            print("Context:", context ?? "nil")
            print("Escalate:", escalate)
        }
        // No-op for tests/previews
    }
}

/// Main engine for managing client preferences, analytics, audit, diagnostics, and localization.
final class ClientPreferenceEngine: ObservableObject {
    /// The analytics logger (can be swapped for production/test/preview).
    private let analyticsLogger: ClientPreferenceAnalyticsLogger
    /// Capped buffer of the last 20 analytics events for diagnostics/audit.
    private var analyticsEventBuffer: [(date: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let analyticsBufferLimit = 20
    /// Dispatch queue for thread-safe buffer management.
    private let bufferQueue = DispatchQueue(label: "ClientPreferenceEngine.analyticsBufferQueue")
    
    /// Initializes the engine with a logger. Defaults to Null logger.
    /// - Parameter analyticsLogger: The analytics logger to use.
    init(analyticsLogger: ClientPreferenceAnalyticsLogger = NullClientPreferenceAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }
    
    // MARK: - Preference Management APIs (Stubs)
    
    /// Fetches client preferences asynchronously.
    /// - Returns: Preferences dictionary (stubbed).
    func fetchPreferences(for clientId: String) async throws -> [String: Any] {
        let message = NSLocalizedString("Fetching preferences for client %@", comment: "Log: fetching client preferences")
        let event = String(format: message, clientId)
        let metadata: [String: Any] = ["clientId": clientId]
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete") || (metadata.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") })
        await logAnalytics(event: event, metadata: metadata, escalate: escalate)
        // TODO: Implement actual fetching logic
        return [:]
    }
    
    /// Updates client preferences asynchronously.
    /// - Parameters:
    ///   - clientId: The client identifier.
    ///   - preferences: New preferences.
    func updatePreferences(for clientId: String, preferences: [String: Any]) async throws {
        let message = NSLocalizedString("Updating preferences for client %@", comment: "Log: updating client preferences")
        let event = String(format: message, clientId)
        let metadata: [String: Any] = ["clientId": clientId, "preferences": preferences]
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete") || (metadata.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") })
        await logAnalytics(event: event, metadata: metadata, escalate: escalate)
        // TODO: Implement actual update logic
        try await auditLog(action: "update", clientId: clientId, details: preferences)
    }
    
    /// Analyzes client preferences for insights (stub).
    /// - Returns: Analysis result (stubbed).
    func analyzePreferences(for clientId: String) async -> String {
        let message = NSLocalizedString("Analyzing preferences for client %@", comment: "Log: analyzing client preferences")
        let event = String(format: message, clientId)
        let metadata: [String: Any] = ["clientId": clientId]
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete") || (metadata.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") })
        await logAnalytics(event: event, metadata: metadata, escalate: escalate)
        // TODO: Implement analysis logic
        return NSLocalizedString("Analysis complete.", comment: "User-facing: analysis done")
    }
    
    // MARK: - Analytics & Audit
    
    /// Logs an analytics event and adds it to the capped event buffer.
    /// - Parameters:
    ///   - event: The event message.
    ///   - metadata: Optional metadata.
    ///   - escalate: Whether the event should be escalated.
    @discardableResult
    func logAnalytics(event: String, metadata: [String: Any]? = nil, escalate: Bool) async {
        await analyticsLogger.log(event: event, metadata: metadata, role: ClientPreferenceAuditContext.role, staffID: ClientPreferenceAuditContext.staffID, context: ClientPreferenceAuditContext.context, escalate: escalate)
        let eventRecord = (date: Date(), event: event, metadata: metadata, role: ClientPreferenceAuditContext.role, staffID: ClientPreferenceAuditContext.staffID, context: ClientPreferenceAuditContext.context, escalate: escalate)
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            self.analyticsEventBuffer.append(eventRecord)
            if self.analyticsEventBuffer.count > self.analyticsBufferLimit {
                self.analyticsEventBuffer.removeFirst(self.analyticsEventBuffer.count - self.analyticsBufferLimit)
            }
        }
    }
    
    /// Logs an auditable action for compliance/Trust Center.
    /// - Parameters:
    ///   - action: The action performed.
    ///   - clientId: The client identifier.
    ///   - details: Additional details.
    func auditLog(action: String, clientId: String, details: [String: Any]) async throws {
        let auditMessage = NSLocalizedString("Audit: %@ action for client %@", comment: "Log: audit action")
        let fullMessage = String(format: auditMessage, action, clientId)
        let metadata = ["action": action, "clientId": clientId, "details": details]
        let escalate = fullMessage.lowercased().contains("danger") || fullMessage.lowercased().contains("critical") || fullMessage.lowercased().contains("delete") || (metadata.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") })
        await logAnalytics(event: fullMessage, metadata: metadata, escalate: escalate)
        // TODO: Hook for Trust Center or regulatory log store
    }
    
    // MARK: - Diagnostics & Admin
    
    /// Returns the most recent analytics events (up to 20) for diagnostics/admin.
    /// - Returns: Array of event records.
    func recentAnalyticsEvents() -> [(date: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        var events: [(date: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
        bufferQueue.sync {
            events = self.analyticsEventBuffer
        }
        return events
    }
    
    /// Returns a localized diagnostics summary.
    /// - Returns: Localized summary string.
    func diagnostics() -> String {
        let eventCount = recentAnalyticsEvents().count
        let diagnosticMessage = NSLocalizedString("Engine diagnostics: %d recent analytics events.", comment: "Diagnostics summary")
        return String(format: diagnosticMessage, eventCount)
    }
}

#if DEBUG
/// SwiftUI Preview demonstrating diagnostics, testMode, and accessibility.
struct ClientPreferenceEngine_Previews: PreviewProvider {
    static var previews: some View {
        let engine = ClientPreferenceEngine(analyticsLogger: PreviewAnalyticsLogger())
        return DiagnosticsView(engine: engine)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString("Client Preference Engine Diagnostics Preview", comment: "Preview accessibility label")))
    }
    
    /// Simple diagnostics SwiftUI view for preview/testing.
    struct DiagnosticsView: View {
        @ObservedObject var engine: ClientPreferenceEngine
        @State private var diagnosticText: String = ""
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("Diagnostics", comment: "Diagnostics section header"))
                    .font(.headline)
                Button(NSLocalizedString("Run Diagnostics", comment: "Diagnostics button")) {
                    diagnosticText = engine.diagnostics()
                }
                .accessibilityIdentifier("runDiagnosticsButton")
                Text(diagnosticText)
                    .accessibilityIdentifier("diagnosticSummary")
                    .foregroundColor(.secondary)
                Divider()
                Text(NSLocalizedString("Recent Analytics Events", comment: "Recent events header"))
                    .font(.subheadline)
                ScrollView {
                    ForEach(engine.recentAnalyticsEvents().reversed(), id: \.date) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.event)
                                .font(.caption)
                            if let metadata = event.metadata {
                                Text(String(describing: metadata))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Text("Role: \(event.role ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("StaffID: \(event.staffID ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Context: \(event.context ?? "nil")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Escalate: \(event.escalate ? "Yes" : "No")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(event.date, style: .time)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(event.event))
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding()
        }
    }
    
    /// Analytics logger for previews/tests, logs to console and engine buffer.
    struct PreviewAnalyticsLogger: ClientPreferenceAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, metadata: [String : Any]? = nil, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("PreviewAnalyticsLogger (testMode):")
            print("Event:", event)
            print("Metadata:", metadata ?? [:])
            print("Role:", role ?? "nil")
            print("StaffID:", staffID ?? "nil")
            print("Context:", context ?? "nil")
            print("Escalate:", escalate)
        }
    }
}
#endif
