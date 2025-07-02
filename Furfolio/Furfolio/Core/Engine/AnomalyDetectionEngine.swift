//
//  AnomalyDetectionEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 AnomalyDetectionEngine.swift

 This file contains the core architecture and implementation of the Anomaly Detection Engine used within Furfolio.

 Architecture & Extensibility:
 -----------------------------
 The AnomalyDetectionEngine class is designed with extensibility in mind, allowing future developers to expand detection algorithms, integrate additional data sources, and customize reporting mechanisms. It provides stub methods for analyzing data, reporting anomalies, and auditing logs, serving as a foundation for more complex implementations.

 Analytics, Audit & Trust Center Hooks:
 --------------------------------------
 The engine integrates with analytics and audit logging through the AnomalyDetectionAnalyticsLogger protocol, which supports async/await for modern concurrency. It includes a testMode property to enable console-only logging during QA, tests, or previews. The engine maintains a capped buffer of the last 20 analytics events for diagnostics and administrative review.

 Diagnostics & Localization:
 ---------------------------
Diagnostics capabilities are exposed via the diagnostics() method to provide internal state and event summaries. All user-facing and log event strings are localized using NSLocalizedString with appropriate keys and comments, ensuring easy adaptation to different locales.

 Accessibility & Compliance:
 ---------------------------
 While primarily backend-focused, the engine includes accessibility considerations in its status and error messaging to support assistive technologies where applicable. Compliance with data handling policies is facilitated through audit logging and structured anomaly reports.

 Preview & Testability:
 ----------------------
A NullAnomalyDetectionAnalyticsLogger struct is provided for previews and tests to avoid external dependencies. The included PreviewProvider demonstrates diagnostics output, testMode logging, and accessibility features, supporting robust development and QA workflows.

 Maintainers and future developers should find this file a clear and extensible foundation for anomaly detection capabilities within Furfolio.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AnomalyDetectionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnomalyDetectionEngine"
}

/// Protocol defining analytics logging capabilities for the Anomaly Detection Engine.
/// Supports async/await concurrency and a testMode for console-only logging during QA/tests/previews.
public protocol AnomalyDetectionAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        _ eventName: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A no-op analytics logger for use in previews and tests.
/// Logs events to the console if testMode is true; otherwise, does nothing.
public struct NullAnomalyDetectionAnalyticsLogger: AnomalyDetectionAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ eventName: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            let paramsDescription = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
            print("[Preview/Test Analytics] Event: \(eventName), Parameters: \(paramsDescription), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
    }
}

/// Core engine responsible for detecting anomalies in data, reporting them,
/// auditing logs, and exposing diagnostics and localization-ready messaging.
public class AnomalyDetectionEngine {

    /// Maximum number of analytics events to keep in the buffer for diagnostics.
    private let maxEventBufferSize = 20

    /// Buffer of recent analytics events for diagnostics and administrative review.
    private var analyticsEventBuffer: [(name: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

    /// The analytics logger used for emitting analytics events.
    private let analyticsLogger: AnomalyDetectionAnalyticsLogger

    /// Initializes the anomaly detection engine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use for event reporting.
    public init(analyticsLogger: AnomalyDetectionAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    /// Analyzes the provided data for anomalies asynchronously.
    /// - Parameter data: The data to analyze.
    /// - Throws: An error if analysis fails.
    public func analyze(data: Data) async throws {
        // Stub implementation: simulate analysis delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Log start of analysis
        let analysisStartedName = NSLocalizedString("AnomalyDetectionEngine.AnalysisStarted", value: "AnalysisStarted", comment: "Analytics event name for starting analysis")
        let escalateStarted = checkEscalate(name: analysisStartedName, parameters: nil)
        await logAnalyticsEvent(
            name: analysisStartedName,
            parameters: nil,
            role: AnomalyDetectionAuditContext.role,
            staffID: AnomalyDetectionAuditContext.staffID,
            context: AnomalyDetectionAuditContext.context,
            escalate: escalateStarted
        )

        // TODO: Implement actual anomaly detection logic here

        // For demonstration, randomly decide if anomaly detected
        let anomalyDetected = Bool.random()

        if anomalyDetected {
            let anomalyDescription = NSLocalizedString("AnomalyDetectionEngine.AnomalyDetectedDescription", value: "Anomaly detected in data stream.", comment: "Description for detected anomaly")
            await reportAnomaly(anomalyDescription)
        }

        // Log completion of analysis
        let analysisCompletedName = NSLocalizedString("AnomalyDetectionEngine.AnalysisCompleted", value: "AnalysisCompleted", comment: "Analytics event name for completed analysis")
        let parametersCompleted = ["anomalyDetected": anomalyDetected]
        let escalateCompleted = checkEscalate(name: analysisCompletedName, parameters: parametersCompleted)
        await logAnalyticsEvent(
            name: analysisCompletedName,
            parameters: parametersCompleted,
            role: AnomalyDetectionAuditContext.role,
            staffID: AnomalyDetectionAuditContext.staffID,
            context: AnomalyDetectionAuditContext.context,
            escalate: escalateCompleted
        )
    }

    /// Reports a detected anomaly asynchronously.
    /// - Parameter anomaly: Description of the anomaly.
    public func reportAnomaly(_ anomaly: String) async {
        let anomalyReportedName = NSLocalizedString("AnomalyDetectionEngine.AnomalyReported", value: "AnomalyReported", comment: "Analytics event name for anomaly reported")
        let parameters = ["description": anomaly]
        let escalateReported = checkEscalate(name: anomalyReportedName, parameters: parameters)
        await logAnalyticsEvent(
            name: anomalyReportedName,
            parameters: parameters,
            role: AnomalyDetectionAuditContext.role,
            staffID: AnomalyDetectionAuditContext.staffID,
            context: AnomalyDetectionAuditContext.context,
            escalate: escalateReported
        )

        // TODO: Implement actual anomaly reporting (e.g., send to server, update UI)

        // For demo, print to console
        print(NSLocalizedString("AnomalyDetectionEngine.ReportAnomalyConsole", value: "Reporting anomaly: %@", comment: "Console output when reporting anomaly"), anomaly)
    }

    /// Returns audit logs asynchronously.
    /// - Returns: An array of audit log entries.
    public func auditLog() async -> [String] {
        // Stub implementation: return recent analytics event names as audit logs
        return analyticsEventBuffer.map { event in
            let paramsString = event.parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? NSLocalizedString("AnomalyDetectionEngine.NoParameters", value: "no parameters", comment: "No parameters label")
            return String(format: NSLocalizedString("AnomalyDetectionEngine.AuditLogEntryFormat", value: "Event: %@, Parameters: %@, Role: %@, StaffID: %@, Context: %@, Escalate: %@, Timestamp: %@", comment: "Format for audit log entry"),
                          event.name,
                          paramsString,
                          event.role ?? "nil",
                          event.staffID ?? "nil",
                          event.context ?? "nil",
                          event.escalate.description,
                          DateFormatter.localizedString(from: event.timestamp, dateStyle: .short, timeStyle: .medium))
        }
    }

    /// Returns diagnostic information asynchronously.
    /// - Returns: A dictionary of diagnostic keys and values.
    public func diagnostics() async -> [String: String] {
        // Stub diagnostics info
        return [
            NSLocalizedString("AnomalyDetectionEngine.Diagnostics.EventBufferSizeKey", value: "EventBufferSize", comment: "Diagnostics key for event buffer size"): "\(analyticsEventBuffer.count)",
            NSLocalizedString("AnomalyDetectionEngine.Diagnostics.TestModeKey", value: "TestMode", comment: "Diagnostics key for test mode status"): "\(analyticsLogger.testMode)"
        ]
    }

    /// Logs an analytics event and stores it in the capped buffer.
    /// - Parameters:
    ///   - name: The event name.
    ///   - parameters: Optional event parameters.
    ///   - role: Role context for audit.
    ///   - staffID: Staff ID context for audit.
    ///   - context: Context string for audit.
    ///   - escalate: Whether the event should be escalated.
    private func logAnalyticsEvent(
        name: String,
        parameters: [String: Any]? = nil,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        // Append to buffer with capping
        DispatchQueue.main.async {
            self.analyticsEventBuffer.append((name: name, parameters: parameters, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date()))
            if self.analyticsEventBuffer.count > self.maxEventBufferSize {
                self.analyticsEventBuffer.removeFirst(self.analyticsEventBuffer.count - self.maxEventBufferSize)
            }
        }

        // Log via analytics logger
        await analyticsLogger.logEvent(name, parameters: parameters, role: role, staffID: staffID, context: context, escalate: escalate)
    }

    /// Helper function to determine if an event should be escalated based on its name or parameters.
    /// - Parameters:
    ///   - name: The event name.
    ///   - parameters: Optional parameters dictionary.
    /// - Returns: True if escalation keywords are found, false otherwise.
    private func checkEscalate(name: String, parameters: [String: Any]?) -> Bool {
        let keywords = ["danger", "critical", "delete"]

        let lowerName = name.lowercased()
        for keyword in keywords {
            if lowerName.contains(keyword) {
                return true
            }
        }

        if let params = parameters {
            for value in params.values {
                if let strValue = value as? String {
                    let lowerValue = strValue.lowercased()
                    for keyword in keywords {
                        if lowerValue.contains(keyword) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
}

#if DEBUG
import XCTest
import SwiftUI

/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features.
struct AnomalyDetectionEngine_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString("AnomalyDetectionEngine.Preview.AccessibilityLabel", value: "Anomaly Detection Engine Diagnostics Preview", comment: "Accessibility label for diagnostics preview")))
    }

    /// A simple SwiftUI view displaying diagnostics information from the engine.
    struct DiagnosticsView: View {
        @State private var diagnostics: [String: String] = [:]

        private let engine = AnomalyDetectionEngine(analyticsLogger: NullAnomalyDetectionAnalyticsLogger())

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("AnomalyDetectionEngine.Preview.Title", value: "Diagnostics", comment: "Title for diagnostics preview"))
                    .font(.headline)
                ForEach(diagnostics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key + ":")
                            .bold()
                        Text(value)
                    }
                }
                Spacer()
                Button(action: loadDiagnostics) {
                    Text(NSLocalizedString("AnomalyDetectionEngine.Preview.ReloadButton", value: "Reload Diagnostics", comment: "Button label to reload diagnostics"))
                }
                .accessibilityHint(Text(NSLocalizedString("AnomalyDetectionEngine.Preview.ReloadButtonHint", value: "Reloads the diagnostic information from the engine", comment: "Accessibility hint for reload diagnostics button")))
            }
            .padding()
            .onAppear(perform: loadDiagnostics)
        }

        private func loadDiagnostics() {
            Task {
                diagnostics = await engine.diagnostics()
            }
        }
    }
}
#endif
