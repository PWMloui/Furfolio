//
//  TextAnalysisEngine.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//


//
//  TextAnalysisEngine.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//
//
//  MARK: - File Overview and Architecture
//
//  TextAnalysisEngine.swift provides a modular, extensible framework for analyzing user text input, generating actionable insights, and logging analytics/audit events for the Furfolio app.
//
//  Architecture:
//  - Core class: `TextAnalysisEngine` encapsulates analysis logic, diagnostics, and event logging.
//  - Analytics: Pluggable analytics logger protocol (`TextAnalysisAnalyticsLogger`) supports async/await, test/preview logging, and Trust Center compliance.
//  - Audit & Trust Center: All analysis actions and results are logged for auditability, with a capped buffer for recent events (for admin/diagnostics).
//  - Diagnostics: Built-in diagnostics API for preview/testing, with accessibility and localization support.
//  - Localization: All user-facing and log strings use `NSLocalizedString` for full localization, compliance, and accessibility.
//  - Accessibility: Diagnostics and log messages are accessible and VoiceOver-friendly.
//  - Extensibility: New analysis modules or loggers can be injected via protocol conformance.
//  - Testability: Null logger and testMode for safe QA/previews; preview provider demonstrates diagnostics and accessibility.
//
//  Compliance:
//  - All analytics/audit events are local and buffer-capped unless integrated with a secure backend.
//  - All user-facing/log event strings are localization-ready for internationalization and regulatory compliance.
//
//  For maintainers: See doc-comments on each type/method for extension points, diagnostics, and usage.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TextAnalysisAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TextAnalysisEngine"
}

// MARK: - Analytics Logger Protocol
/**
 Protocol for logging analytics and audit events for text analysis.
 - Supports async/await for modern concurrency.
 - `testMode` enables console-only logging for QA, previews, and tests (default: false).
 - Extend for integration with backend analytics or Trust Center.
 */
public protocol TextAnalysisAnalyticsLogger: AnyObject {
    /// If true, disables persistent/remote logging and logs only to console (QA/testing/previews).
    var testMode: Bool { get set }
    /**
     Log an analytics event.
     - Parameters:
       - event: The event string (localizable).
       - metadata: Optional additional info for diagnostics/audit.
       - role: Optional user role for audit context.
       - staffID: Optional staff identifier for audit context.
       - context: Optional context string for audit context.
       - escalate: Flag to indicate if event is critical/dangerous.
     */
    func log(
        event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

// MARK: - Null Analytics Logger
/**
 Null object for safe analytics logging in previews/tests.
 Use in SwiftUI previews or unit tests to avoid side effects.
 */
public final class NullTextAnalysisAnalyticsLogger: TextAnalysisAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        metadata: [String : Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        // Print for preview diagnostics if testMode
        if testMode {
            let meta = metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            print("[TextAnalysisEngine][TEST MODE] \(event) | \(meta) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - TextAnalysisEngine Core
/**
 Engine for analyzing user text, generating insights, and logging analytics/audit events.
 - Use dependency injection for analyticsLogger to support testability and Trust Center compliance.
 - All user/log messages are localization-ready.
 */
public final class TextAnalysisEngine: ObservableObject {
    /// Analytics logger (injectable for compliance/testing)
    private let analyticsLogger: TextAnalysisAnalyticsLogger
    /// Buffer of recent analytics/audit events (capped for diagnostics/admin)
    private var eventBuffer: [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    /// Maximum number of recent events to retain
    private let eventBufferLimit = 20
    /// Serial queue for thread-safe event buffer access
    private let bufferQueue = DispatchQueue(label: "TextAnalysisEngine.eventBuffer")

    /**
     Initialize the text analysis engine.
     - Parameter analyticsLogger: Logger for analytics/audit events (default: NullTextAnalysisAnalyticsLogger).
     */
    public init(analyticsLogger: TextAnalysisAnalyticsLogger = NullTextAnalysisAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Public API

    /**
     Analyze a given text and return a localized insight.
     - Parameter text: The user input text to analyze.
     - Returns: A localized user-facing insight string.
     */
    public func analyze(text: String) async -> String {
        // Example stub: Detect if text is empty or contains "cat"
        let insight: String
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insight = NSLocalizedString(
                "analysis.empty",
                value: "No text entered. Please provide some input.",
                comment: "User-friendly message when analysis is requested on empty input"
            )
            await logEvent(
                NSLocalizedString(
                    "event.analysis.empty",
                    value: "Analysis attempted on empty input.",
                    comment: "Analytics log event for empty analysis"
                )
            )
        } else if text.localizedCaseInsensitiveContains("cat") {
            insight = NSLocalizedString(
                "analysis.cat_detected",
                value: "Your text mentions a cat! 🐾",
                comment: "Insight when the word 'cat' is detected in user text"
            )
            await logEvent(
                NSLocalizedString(
                    "event.analysis.cat_detected",
                    value: "Detected 'cat' in user input.",
                    comment: "Analytics log event for detecting 'cat'"
                ),
                metadata: ["input": text]
            )
        } else {
            insight = NSLocalizedString(
                "analysis.generic",
                value: "Text analyzed successfully.",
                comment: "Generic insight when analysis completes with no special findings"
            )
            await logEvent(
                NSLocalizedString(
                    "event.analysis.completed",
                    value: "Analysis completed on user input.",
                    comment: "Analytics log event for generic analysis"
                ),
                metadata: ["input": text]
            )
        }
        return insight
    }

    /**
     Generate a diagnostic report for admin/QA.
     - Returns: Localized diagnostic string including recent events.
     */
    public func diagnostics() -> String {
        let recentEvents = recentAnalyticsEvents().joined(separator: "\n")
        let diagnosticsString = String(
            format: NSLocalizedString(
                "diagnostics.report",
                value: "TextAnalysisEngine Diagnostics:\nRecent Events:\n%@",
                comment: "Admin/QA diagnostics report with recent analytics events"
            ),
            recentEvents
        )
        return diagnosticsString
    }

    /**
     Audit log for Trust Center/compliance (stub).
     - Returns: Localized audit log string.
     */
    public func auditLog() -> String {
        let logString = NSLocalizedString(
            "audit.log",
            value: "Audit Log: All analysis actions are tracked for compliance.",
            comment: "Audit log compliance message"
        )
        return logString
    }

    /**
     Fetch the most recent analytics/audit events (for diagnostics/admin).
     - Returns: Array of recent event strings.
     */
    public func recentAnalyticsEvents() -> [String] {
        bufferQueue.sync {
            eventBuffer.map { evt in
                let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
                let meta = evt.metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
                let role = evt.role ?? "-"
                let staffID = evt.staffID ?? "-"
                let context = evt.context ?? "-"
                let escalate = evt.escalate ? "YES" : "NO"
                return "[\(dateStr)] \(evt.event) | \(meta) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
            }
        }
    }

    // MARK: - Private Helpers

    /// Log an event to analytics and buffer (localization-ready).
    private func logEvent(_ event: String, metadata: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        bufferQueue.sync {
            if eventBuffer.count >= eventBufferLimit {
                eventBuffer.removeFirst(eventBuffer.count - eventBufferLimit + 1)
            }
            eventBuffer.append((timestamp: Date(), event: event, metadata: metadata, role: TextAnalysisAuditContext.role, staffID: TextAnalysisAuditContext.staffID, context: TextAnalysisAuditContext.context, escalate: escalate))
        }
        await analyticsLogger.log(
            event: event,
            metadata: metadata,
            role: TextAnalysisAuditContext.role,
            staffID: TextAnalysisAuditContext.staffID,
            context: TextAnalysisAuditContext.context,
            escalate: escalate
        )
    }
}

// MARK: - SwiftUI PreviewProvider for Diagnostics/TestMode/Accessibility
#if DEBUG
struct TextAnalysisEngine_Previews: PreviewProvider {
    static var previews: some View {
        let engine = TextAnalysisEngine(analyticsLogger: PreviewLogger())
        return Group {
            VStack(alignment: .leading, spacing: 16) {
                Text("Text Analysis Engine Preview")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Button("Run Empty Analysis") {
                    Task { _ = await engine.analyze(text: "") }
                }
                .accessibilityLabel(Text(NSLocalizedString(
                    "preview.button.empty",
                    value: "Run analysis on empty text input",
                    comment: "Accessibility label for empty analysis button"
                )))
                Button("Run 'cat' Analysis") {
                    Task { _ = await engine.analyze(text: "My cat is cute") }
                }
                .accessibilityLabel(Text(NSLocalizedString(
                    "preview.button.cat",
                    value: "Run analysis on text mentioning a cat",
                    comment: "Accessibility label for cat analysis button"
                )))
                Button("Show Diagnostics") {
                    print(engine.diagnostics())
                }
                .accessibilityLabel(Text(NSLocalizedString(
                    "preview.button.diagnostics",
                    value: "Show diagnostics report",
                    comment: "Accessibility label for diagnostics button"
                )))
                Button("Show Audit Log") {
                    print(engine.auditLog())
                }
                .accessibilityLabel(Text(NSLocalizedString(
                    "preview.button.audit",
                    value: "Show audit log",
                    comment: "Accessibility label for audit log button"
                )))
                ScrollView {
                    Text(engine.diagnostics())
                        .accessibilityLabel(Text(NSLocalizedString(
                            "preview.diagnostics.text",
                            value: "Diagnostics report text",
                            comment: "Accessibility label for diagnostics text"
                        )))
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
            .environment(\.locale, .init(identifier: "en")) // For localization testing
        }
    }

    /// Preview logger that prints to console and marks testMode true.
    final class PreviewLogger: TextAnalysisAnalyticsLogger {
        var testMode: Bool = true
        func log(event: String, metadata: [String : Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[PREVIEW ANALYTICS] \(event) \(metadata ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}
#endif
