//
//  ChurnPredictionEngine.swift
//  Furfolio
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ChurnPredictionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ChurnPredictionEngine"
}

// MARK: - Analytics/Audit Logger Protocol

public protocol ChurnPredictionAnalyticsLogger {
    /// Indicates whether the logger is operating in test mode.
    var testMode: Bool { get set }
    /// Asynchronously logs an analytics event with full audit context.
    func logEvent(
        eventName: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

// MARK: - Null Logger (prints all fields in testMode)
public struct NullChurnPredictionAnalyticsLogger: ChurnPredictionAnalyticsLogger {
    public var testMode: Bool = false
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func logEvent(
        eventName: String,
        metadata: [String : Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            let metaDescription = metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
            print("NullLogger [TestMode] Event: \(eventName), Metadata: \(metaDescription) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
        // No-op for production or non-testMode
    }
}

// MARK: - Analytics Event Struct
public struct ChurnAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let eventName: String
    public let metadata: [String: Any]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

// MARK: - Core Engine

public class ChurnPredictionEngine {

    // MARK: - Properties

    /// Analytics logger instance used to record events.
    private let analyticsLogger: ChurnPredictionAnalyticsLogger

    /// Buffer storing the last 20 analytics events for diagnostics and audit.
    private var recentEvents: [ChurnAnalyticsEvent] = []

    /// Maximum number of events to keep in the buffer.
    private let maxEventBufferSize = 20

    // MARK: - Initialization

    public init(analyticsLogger: ChurnPredictionAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Public API

    /// Predicts whether a customer is at risk of churning.
    public func predictChurn(for customerID: String) async -> Bool {
        await logEvent(
            eventName: NSLocalizedString("predictChurn_called", value: "Predict churn called", comment: "Log event when predictChurn is invoked"),
            metadata: ["customerID": customerID]
        )
        // Stub implementation - replace with real prediction logic
        return false
    }

    /// Sends an alert if the specified customer is at risk of churning.
    public func alertIfAtRisk(for customerID: String) async {
        let isAtRisk = await predictChurn(for: customerID)
        if isAtRisk {
            await logEvent(
                eventName: NSLocalizedString("alert_sent", value: "Alert sent for at-risk customer", comment: "Log event when alert is sent"),
                metadata: ["customerID": customerID]
            )
            let alertMessage = NSLocalizedString("alert_message", value: "Customer \(customerID) is at risk of churn.", comment: "Alert message for at-risk customer")
            print(alertMessage) // Replace with real alert mechanism
        } else {
            await logEvent(
                eventName: NSLocalizedString("alert_skipped", value: "Alert skipped for low-risk customer", comment: "Log event when alert is skipped"),
                metadata: ["customerID": customerID]
            )
        }
    }

    /// Records an audit log entry.
    public func auditLog() async {
        await logEvent(
            eventName: NSLocalizedString("audit_log_recorded", value: "Audit log recorded", comment: "Log event for audit recording"),
            metadata: nil
        )
    }

    /// Provides diagnostic information about the engine's current state.
    public func diagnostics() -> [String: String] {
        [
            NSLocalizedString("diagnostics_eventCount_key", value: "Recent Analytics Event Count", comment: "Diagnostic key for number of recent analytics events"): "\(recentEvents.count)",
            NSLocalizedString("diagnostics_testMode_key", value: "Analytics Logger Test Mode", comment: "Diagnostic key for analytics logger test mode status"): "\(analyticsLogger.testMode)"
        ]
    }

    /// Returns a localized status message for the engine.
    public func statusMessage() -> String {
        NSLocalizedString("status_message", value: "Churn Prediction Engine is operational.", comment: "Status message indicating engine is running")
    }

    /// Returns a localized error message for a generic failure.
    public func errorMessage() -> String {
        NSLocalizedString("error_message", value: "An error occurred during churn prediction.", comment: "Generic error message for churn prediction failure")
    }

    /// Fetches the most recent analytics events logged by the engine, including audit fields.
    public func fetchRecentAnalyticsEvents() -> [ChurnAnalyticsEvent] {
        recentEvents
    }

    // MARK: - Private Helpers

    /// Logs an analytics event and updates the internal recent events buffer with audit context.
    private func logEvent(eventName: String, metadata: [String: Any]? = nil) async {
        let escalate = eventName.lowercased().contains("danger")
            || eventName.lowercased().contains("critical")
            || eventName.lowercased().contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)

        let auditEvent = ChurnAnalyticsEvent(
            timestamp: Date(),
            eventName: eventName,
            metadata: metadata,
            role: ChurnPredictionAuditContext.role,
            staffID: ChurnPredictionAuditContext.staffID,
            context: ChurnPredictionAuditContext.context,
            escalate: escalate
        )

        // Update buffer
        if recentEvents.count >= maxEventBufferSize {
            recentEvents.removeFirst()
        }
        recentEvents.append(auditEvent)

        await analyticsLogger.logEvent(
            eventName: eventName,
            metadata: metadata,
            role: ChurnPredictionAuditContext.role,
            staffID: ChurnPredictionAuditContext.staffID,
            context: ChurnPredictionAuditContext.context,
            escalate: escalate
        )
    }
}

// MARK: - SwiftUI PreviewProvider

struct ChurnPredictionEngine_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .accessibilityLabel(NSLocalizedString("preview_accessibility_label", value: "Churn Prediction Engine Diagnostics Preview", comment: "Accessibility label for diagnostics preview"))
            .accessibilityHint(NSLocalizedString("preview_accessibility_hint", value: "Displays diagnostic information and test mode status.", comment: "Accessibility hint for diagnostics preview"))
    }

    /// A simple SwiftUI view to display diagnostics and test mode status, now with audit events.
    struct DiagnosticsView: View {
        @State private var diagnosticsInfo: [String: String] = [:]
        @State private var events: [ChurnAnalyticsEvent] = []
        private let engine: ChurnPredictionEngine

        init() {
            let logger = NullChurnPredictionAnalyticsLogger(testMode: true)
            engine = ChurnPredictionEngine(analyticsLogger: logger)
            _diagnosticsInfo = State(initialValue: engine.diagnostics())
            _events = State(initialValue: engine.fetchRecentAnalyticsEvents())
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("preview_title", value: "Churn Prediction Engine Diagnostics", comment: "Title for diagnostics preview"))
                    .font(.headline)
                ForEach(diagnosticsInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .bold()
                        Spacer()
                        Text(value)
                    }
                }
                Divider().padding(.vertical, 8)
                Text("Recent Analytics Events (with audit fields):")
                    .bold()
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• \(event.eventName)")
                            .fontWeight(.semibold)
                        if let meta = event.metadata {
                            Text("Metadata: \(meta.map { "\($0): \($1)" }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("role: \(event.role ?? "-")")
                            Text("staffID: \(event.staffID ?? "-")")
                            Text("context: \(event.context ?? "-")")
                            Text("escalate: \(event.escalate ? "YES" : "NO")")
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                        Text(event.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 6)
                }
                Text(engine.statusMessage())
                    .padding(.top)
            }
            .padding()
            .onAppear {
                diagnosticsInfo = engine.diagnostics()
                events = engine.fetchRecentAnalyticsEvents()
            }
        }
    }
}
