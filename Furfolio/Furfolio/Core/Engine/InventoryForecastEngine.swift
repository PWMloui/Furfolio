//
//  InventoryForecastEngine.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 InventoryForecastEngine.swift
 Furfolio

 ## Overview
 InventoryForecastEngine provides a modular, extensible framework for forecasting inventory needs within the Furfolio application. This engine is designed with maintainability, analytics, auditing, diagnostics, localization, accessibility, compliance, and testability in mind.

 ## Architecture
 - **InventoryForecastEngine**: Primary class responsible for inventory forecasting, diagnostics, and audit logging. All user-facing and log messages are fully localized.
 - **Analytics Logging**: Uses the InventoryForecastAnalyticsLogger protocol for event logging, supporting async/await and testMode for QA/previews.
 - **Audit/Trust Center Hooks**: auditLog() and diagnostics() methods are included for compliance and traceability.
 - **Diagnostics**: Provides access to recent analytics events, capped at the last 20, for admin/diagnostic use.
 - **Localization**: All strings wrapped with NSLocalizedString, including descriptive keys, default values, and comments for translators.
 - **Accessibility**: Designed to support VoiceOver and other accessibility features in all user-facing diagnostics and preview UIs.
 - **Compliance**: Engine is structured to be compatible with privacy, audit, and security requirements (e.g., Trust Center, GDPR).
 - **Testability/Preview**: Includes NullInventoryForecastAnalyticsLogger for previews and tests, and a PreviewProvider demonstrating diagnostics, testMode, and accessibility features.

 ## Extensibility
 - Add new analytics loggers by conforming to InventoryForecastAnalyticsLogger.
 - Extend forecasting logic by subclassing or composing InventoryForecastEngine.
 - Plug in additional audit/diagnostics providers as needed.

 ## For Future Maintainers
 - All user-facing/log strings must use NSLocalizedString with appropriate keys and comments for full localization and compliance.
 - Analytics loggers should default to testMode = false, and switching to testMode disables persistent logging for QA/testing.
 - PreviewProvider at the bottom demonstrates diagnostics, testMode, and accessibility hooks.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct InventoryForecastAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "InventoryForecastEngine"
}

/// Protocol for analytics logging in InventoryForecastEngine, supporting async/await and testMode for QA/previews.
public protocol InventoryForecastAnalyticsLogger: AnyObject {
    /// If true, analytics will be logged to console only (for QA/tests/previews).
    var testMode: Bool { get set }
    /// Log an analytics event asynchronously.
    func logEvent(
        _ event: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null logger for previews/tests; does not persist or send analytics, but prints to console if testMode is true.
public final class NullInventoryForecastAnalyticsLogger: InventoryForecastAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func logEvent(
        _ event: String,
        parameters: [String : Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[NullInventoryForecastAnalyticsLogger][TEST MODE] \(event) \(parameters ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Main engine for forecasting inventory needs, analytics, diagnostics, and audit logging.
public final class InventoryForecastEngine {
    /// Analytics logger (injected).
    private let analyticsLogger: InventoryForecastAnalyticsLogger
    /// Capped buffer of recent analytics events (last 20).
    private var recentEvents: [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    /// Serial queue for thread safety.
    private let bufferQueue = DispatchQueue(label: "com.furfolio.inventoryforecast.buffer")
    /// Max number of recent events to keep.
    private let maxEventBuffer = 20

    /// Initializes the engine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use.
    public init(analyticsLogger: InventoryForecastAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    /// Forecast inventory needs based on provided data.
    /// - Parameters:
    ///   - data: Arbitrary input data for forecasting.
    /// - Returns: Forecasted inventory (stubbed as an Int for demonstration).
    /// - Throws: Errors related to forecasting logic.
    public func forecastInventoryNeeds(data: [String: Any]) async throws -> Int {
        // TODO: Implement actual forecasting logic.
        let eventKey = "forecast_inventory_success"
        let eventMessage = NSLocalizedString(
            eventKey,
            value: "Inventory forecast completed successfully.",
            comment: "Log event: Forecast inventory completed successfully"
        )
        await logAnalyticsEvent(eventMessage, parameters: data)
        return 42 // stubbed value
    }

    /// Log an audit event for compliance/Trust Center.
    /// - Parameter details: Details of the audit event.
    public func auditLog(details: String) async {
        let auditKey = "audit_log_entry"
        let auditMessage = NSLocalizedString(
            auditKey,
            value: "Audit log entry: %@",
            comment: "Audit log event with details"
        )
        let formatted = String(format: auditMessage, details)
        await logAnalyticsEvent(formatted, parameters: ["type": "audit"])
    }

    /// Collect diagnostics information for admin/support.
    /// - Returns: Diagnostics summary string (localized).
    public func diagnostics() -> String {
        let diagnosticsKey = "diagnostics_summary"
        let diagnosticsMessage = NSLocalizedString(
            diagnosticsKey,
            value: "Diagnostics: %d recent events captured.",
            comment: "Diagnostics summary with number of recent analytics events"
        )
        let count = recentEvents.count
        return String(format: diagnosticsMessage, count)
    }

    /// Fetch the most recent analytics events (up to last 20).
    /// - Returns: Array of event tuples (date, event, parameters, role, staffID, context, escalate).
    public func fetchRecentEvents() -> [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        bufferQueue.sync {
            return recentEvents
        }
    }

    /// Internal helper to log analytics events and update event buffer.
    /// - Parameters:
    ///   - event: Event message (localized).
    ///   - parameters: Optional event parameters.
    private func logAnalyticsEvent(_ event: String, parameters: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event,
            parameters: parameters,
            role: InventoryForecastAuditContext.role,
            staffID: InventoryForecastAuditContext.staffID,
            context: InventoryForecastAuditContext.context,
            escalate: escalate
        )
        bufferQueue.sync {
            recentEvents.append((
                date: Date(),
                event: event,
                parameters: parameters,
                role: InventoryForecastAuditContext.role,
                staffID: InventoryForecastAuditContext.staffID,
                context: InventoryForecastAuditContext.context,
                escalate: escalate
            ))
            if recentEvents.count > maxEventBuffer {
                recentEvents.removeFirst(recentEvents.count - maxEventBuffer)
            }
        }
    }
}

#if DEBUG
/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct InventoryForecastEngine_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var diagnosticsText: String = ""
        let engine: InventoryForecastEngine
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString(
                    "preview_title",
                    value: "Inventory Forecast Engine Preview",
                    comment: "Title for inventory forecast engine preview"
                ))
                    .font(.headline)
                    .accessibilityIdentifier("previewTitle")
                Button(action: {
                    Task {
                        do {
                            _ = try await engine.forecastInventoryNeeds(data: ["preview": true])
                            diagnosticsText = engine.diagnostics()
                        } catch {
                            diagnosticsText = NSLocalizedString(
                                "forecast_error",
                                value: "Forecasting error: %@",
                                comment: "Error message for forecasting in preview"
                            )
                        }
                    }
                }) {
                    Text(NSLocalizedString(
                        "run_forecast_button",
                        value: "Run Forecast",
                        comment: "Button label to run inventory forecast in preview"
                    ))
                        .accessibilityLabel(NSLocalizedString(
                            "run_forecast_accessibility_label",
                            value: "Run inventory forecast for preview",
                            comment: "Accessibility label for run forecast button"
                        ))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("runForecastButton")
                Text(diagnosticsText)
                    .accessibilityLabel(NSLocalizedString(
                        "diagnostics_accessibility_label",
                        value: "Diagnostics summary",
                        comment: "Accessibility label for diagnostics summary text"
                    ))
                    .accessibilityIdentifier("diagnosticsText")
                List(engine.fetchRecentEvents(), id: \.date) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.event)
                            .font(.caption)
                        if let params = event.parameters {
                            Text(params.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Role: \(event.role ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Staff ID: \(event.staffID ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Context: \(event.context ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(event.date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("recentEventsList")
            }
            .padding()
            .accessibilityElement(children: .contain)
        }
    }
    static var previews: some View {
        let testLogger = NullInventoryForecastAnalyticsLogger()
        testLogger.testMode = true
        let engine = InventoryForecastEngine(analyticsLogger: testLogger)
        return PreviewView(engine: engine)
    }
}
#endif
