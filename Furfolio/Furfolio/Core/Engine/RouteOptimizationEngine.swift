//
//  RouteOptimizationEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct RouteOptimizationAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "RouteOptimizationEngine"
}

/**
 RouteOptimizationEngine.swift

 This file contains the core RouteOptimizationEngine class and supporting types for route optimization within the Furfolio app.

 Architecture:
 - The engine provides asynchronous route optimization leveraging Swift's async/await for concurrency.
 - Analytics and audit logging are integrated via a protocol-based logger to allow flexible implementations.
 - Diagnostics and accessibility features are exposed for maintainers and QA.
 - Localization is fully supported through NSLocalizedString keys for all user-facing and log messages.
 - Compliance considerations include audit trails, data privacy, and accessibility.
 - Designed for extensibility to support additional optimization algorithms and analytics backends.

 Extensibility:
 - RouteOptimizationAnalyticsLogger protocol allows custom analytics loggers.
 - RouteOptimizationEngine methods are stubbed for future algorithm implementations.
 - Localization keys can be expanded to support additional languages.

 Analytics / Audit / Trust Center Hooks:
 - Audit logs and analytics events are captured and capped to last 20 events.
 - Public API exposes recent events for admin or diagnostics review.
 - Test mode enables console-only logging for QA and previews.

 Diagnostics:
 - Diagnostic data includes engine status and recent analytics events.
 - PreviewProvider demonstrates diagnostics and accessibility features.

 Localization:
 - All user-facing strings and log messages are wrapped with NSLocalizedString for full localization support.

 Accessibility:
 - Accessibility features and diagnostics are demonstrated in the preview.
 - Future enhancements may include accessibility-focused route optimizations.

 Compliance:
 - Audit logging supports compliance with data governance policies.
 - Localization and accessibility support legal and regulatory requirements.

 Preview / Testability:
 - NullRouteOptimizationAnalyticsLogger provides a safe no-op logger for previews and tests.
 - PreviewProvider demonstrates usage scenarios including diagnostics and test mode.

*/

/// Protocol defining an async/await-capable analytics logger for route optimization events.
/// Implementations should handle concurrency and support testMode for console-only logging in QA/tests/previews.
public protocol RouteOptimizationAnalyticsLogger {
    /// Indicates if the logger is in test mode (e.g., console-only logging).
    var testMode: Bool { get }
    func logEvent(
        event: String,
        details: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-operation analytics logger suitable for previews and tests.
/// It safely ignores all logging calls.
public struct NullRouteOptimizationAnalyticsLogger: RouteOptimizationAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        event: String,
        details: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let detailsString = details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullRouteOptimizationAnalyticsLogger][TEST MODE] Event: \(event), Details: \(detailsString) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

/// Core engine responsible for calculating optimal routes, auditing, diagnostics, and localization-ready messaging.
public class RouteOptimizationEngine: ObservableObject {
    /// The analytics logger used for audit and event logging.
    private let analyticsLogger: RouteOptimizationAnalyticsLogger

    /// Buffer to store the last 20 analytics events to support diagnostics and audit.
    private var analyticsEventBuffer: [(timestamp: Date, event: String, details: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []

    /// Maximum number of events to retain in the analytics buffer.
    private let maxEventBufferSize = 20

    /// Queue to synchronize access to the analytics event buffer.
    private let analyticsQueue = DispatchQueue(label: "com.furfolio.routeOptimization.analyticsQueue")

    /// Initializes the engine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger instance to use.
    public init(analyticsLogger: RouteOptimizationAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    /// Asynchronously calculates the optimal route based on provided parameters.
    /// This is a stub method for future route optimization algorithm implementations.
    /// - Parameters:
    ///   - locations: Array of location identifiers or coordinates.
    /// - Returns: An ordered array representing the optimal route.
    public func calculateOptimalRoute(locations: [String]) async -> [String] {
        let startMessage = NSLocalizedString(
            "RouteOptimizationEngine.CalculationStarted",
            value: "Starting route optimization calculation...",
            comment: "Log message indicating route optimization calculation has started"
        )
        await logAnalyticsEvent(event: startMessage)

        // Stub: Replace with actual optimization logic.
        let result = locations

        let completionMessage = NSLocalizedString(
            "RouteOptimizationEngine.CalculationCompleted",
            value: "Route optimization calculation completed.",
            comment: "Log message indicating route optimization calculation has finished"
        )
        await logAnalyticsEvent(event: completionMessage)
        return result
    }

    /// Asynchronously logs an audit event message.
    /// - Parameter message: The audit message string.
    public func auditLog(_ message: String) async {
        await logAnalyticsEvent(event: message)
    }

    /// Helper function to log analytics events with audit context and escalate flag.
    private func logAnalyticsEvent(event: String, details: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (details?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event: event,
            details: details,
            role: RouteOptimizationAuditContext.role,
            staffID: RouteOptimizationAuditContext.staffID,
            context: RouteOptimizationAuditContext.context,
            escalate: escalate
        )
        analyticsQueue.sync {
            analyticsEventBuffer.append((timestamp: Date(), event: event, details: details, role: RouteOptimizationAuditContext.role, staffID: RouteOptimizationAuditContext.staffID, context: RouteOptimizationAuditContext.context, escalate: escalate))
            if analyticsEventBuffer.count > maxEventBufferSize {
                analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - maxEventBufferSize)
            }
        }
    }

    /// Provides diagnostic information about the engine.
    /// - Returns: A dictionary of diagnostic keys and localized descriptions.
    public func diagnostics() -> [String: String] {
        let diagnosticsMessage = NSLocalizedString(
            "RouteOptimizationEngine.DiagnosticsMessage",
            value: "Diagnostics data retrieved successfully.",
            comment: "Message indicating diagnostics data retrieval"
        )
        return [
            NSLocalizedString("RouteOptimizationEngine.DiagnosticsStatusKey", value: "Status", comment: "Diagnostics status key"): diagnosticsMessage,
            NSLocalizedString("RouteOptimizationEngine.DiagnosticsEventCountKey", value: "Recent Event Count", comment: "Diagnostics event count key"): "\(analyticsEventBuffer.count)"
        ]
    }

    /// Retrieves recent analytics events for diagnostics or administrative review.
    /// - Returns: An array of recent analytics event tuples with audit context.
    public func recentAnalyticsEvents() -> [(timestamp: Date, event: String, details: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        analyticsQueue.sync {
            analyticsEventBuffer
        }
    }

    /// Provides a diagnostics audit trail as formatted strings.
    public func diagnosticsAuditTrail() -> [String] {
        analyticsQueue.sync {
            analyticsEventBuffer.map { evt in
                let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
                let detailsStr = evt.details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
                let role = evt.role ?? "-"
                let staffID = evt.staffID ?? "-"
                let context = evt.context ?? "-"
                let escalate = evt.escalate ? "YES" : "NO"
                return "[\(dateStr)] \(evt.event) \(detailsStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
            }
        }
    }

    /// Localized user-facing message for route optimization status.
    /// - Returns: Status message string.
    public func localizedStatusMessage() -> String {
        NSLocalizedString(
            "RouteOptimizationEngine.StatusMessage",
            value: "Route optimization engine is operational.",
            comment: "User-facing status message indicating engine operational state"
        )
    }

    /// Localized error message for route optimization failure.
    /// - Returns: Error message string.
    public func localizedErrorMessage() -> String {
        NSLocalizedString(
            "RouteOptimizationEngine.ErrorMessage",
            value: "Failed to calculate the optimal route. Please try again.",
            comment: "User-facing error message when route optimization fails"
        )
    }
}

/// SwiftUI PreviewProvider demonstrating diagnostics, test mode, and accessibility features.
struct RouteOptimizationEngine_Previews: PreviewProvider {
    static var previews: some View {
        RouteOptimizationEnginePreviewView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString(
                "RouteOptimizationEngine.PreviewAccessibilityLabel",
                value: "Route optimization engine preview with diagnostics and test mode enabled.",
                comment: "Accessibility label for RouteOptimizationEngine preview"
            )))
    }

    /// A SwiftUI view showcasing diagnostics and analytics logger test mode.
    struct RouteOptimizationEnginePreviewView: View {
        @StateObject private var engine = RouteOptimizationEngine(
            analyticsLogger: NullRouteOptimizationAnalyticsLogger()
        )

        @State private var diagnosticsText: String = ""

        var body: some View {
            VStack(spacing: 16) {
                Text(engine.localizedStatusMessage())
                    .font(.headline)
                    .padding()

                Button(action: loadDiagnostics) {
                    Text(NSLocalizedString(
                        "RouteOptimizationEngine.LoadDiagnosticsButton",
                        value: "Load Diagnostics",
                        comment: "Button title to load diagnostics data"
                    ))
                }
                .padding()
                .accessibilityHint(Text(NSLocalizedString(
                    "RouteOptimizationEngine.LoadDiagnosticsAccessibilityHint",
                    value: "Loads diagnostic information about the route optimization engine.",
                    comment: "Accessibility hint for Load Diagnostics button"
                )))

                ScrollView {
                    Text(diagnosticsText)
                        .font(.body)
                        .padding()
                }
                .frame(maxHeight: 200)
                .border(Color.gray)

                // Show full diagnostics audit trail
                ScrollView {
                    Text(engine.diagnosticsAuditTrail().joined(separator: "\n"))
                        .font(.footnote)
                        .padding()
                }
                .frame(maxHeight: 200)
                .border(Color.blue)

                Spacer()
            }
            .padding()
            .onAppear {
                Task {
                    await engine.auditLog(NSLocalizedString(
                        "RouteOptimizationEngine.PreviewAuditLogMessage",
                        value: "Preview audit log event.",
                        comment: "Audit log message generated during preview"
                    ))
                }
            }
        }

        private func loadDiagnostics() {
            let diagnostics = engine.diagnostics()
            diagnosticsText = diagnostics.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
    }
}
