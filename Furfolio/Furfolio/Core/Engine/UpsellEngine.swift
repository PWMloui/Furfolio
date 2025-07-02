//
//  UpsellEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

//
//  UpsellEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//
//  MARK: - UpsellEngine.swift: Architecture and Maintenance Notes
//
//  Overview:
//  UpsellEngine is a modular engine for managing upsell suggestions, analytics, and compliance within Furfolio.
//
//  Architecture:
//  - Central class `UpsellEngine` manages suggestion logic, analytics, diagnostics, and compliance hooks.
//  - Analytics logging is abstracted via `UpsellAnalyticsLogger` protocol (async/await-ready).
//  - All user-facing/log event strings use NSLocalizedString for localization and compliance.
//  - Event buffer (last 20) available for diagnostics/audit/admin.
//
//  Extensibility:
//  - Plug in custom analytics loggers conforming to `UpsellAnalyticsLogger`.
//  - Override/extend suggestion logic as needed.
//  - Add new upsell types via enum/case expansion.
//
//  Analytics/Audit/Trust Center Hooks:
//  - All analytics events are routed through the logger protocol.
//  - Audit logs and diagnostics accessible for Trust Center/admin panels.
//
//  Diagnostics:
//  - Diagnostics API exposes event buffer and system state for debugging.
//
//  Localization:
//  - All messages and logs are wrapped in NSLocalizedString with key, value, comment.
//
//  Accessibility:
//  - All user-facing output is accessible and localizable.
//  - PreviewProvider demonstrates accessibility actions.
//
//  Compliance:
//  - All logs/messages are localizable for compliance.
//  - Event buffer capped for privacy.
//
//  Preview/Testability:
//  - Null logger and testMode for QA/previews.
//  - PreviewProvider shows diagnostics, testMode, accessibility.
//
//  For future maintainers: See doc-comments throughout for guidance.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct UpsellAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "UpsellEngine"
}

/// Protocol for async/await-ready analytics logging for upsell events.
/// - testMode: If true, logs only to console (for QA/tests/previews).
@MainActor
public protocol UpsellAnalyticsLogger: AnyObject {
    /// If true, logs only to console (QA/tests/previews).
    var testMode: Bool { get set }
    /// Log an analytics event with optional metadata and full audit context.
    func log(
        event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null implementation for tests/previews.
public class NullUpsellAnalyticsLogger: UpsellAnalyticsLogger {
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
        if testMode {
            let metaStr = metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            print("[NullUpsellAnalyticsLogger][TEST MODE] \(event) | \(metaStr) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Analytics event structure for diagnostics/audit.
public struct UpsellAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let metadata: [String: Any]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Main engine for managing upsell suggestions, analytics, diagnostics, and compliance.
@MainActor
public class UpsellEngine: ObservableObject {
    /// Analytics logger for event reporting.
    private let analyticsLogger: UpsellAnalyticsLogger
    /// Buffer of last 20 analytics events for diagnostics/audit.
    @Published private(set) var recentEvents: [UpsellAnalyticsEvent] = []
    /// Maximum number of events to retain for diagnostics.
    private let eventBufferLimit = 20
    /// Indicates if testMode is enabled (console-only logging).
    public var testMode: Bool {
        get { analyticsLogger.testMode }
        set { analyticsLogger.testMode = newValue }
    }

    /// Initialize with a logger (default: NullUpsellAnalyticsLogger).
    public init(analyticsLogger: UpsellAnalyticsLogger = NullUpsellAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    /// Suggest an upsell to the user (stub for extensibility).
    /// - Parameters:
    ///   - context: The context in which to suggest.
    ///   - userID: The user identifier.
    public func suggestUpsell(context: String, userID: String?) async {
        let eventKey = "upsell_suggested"
        let message = NSLocalizedString(
            "UpsellEngine.suggested",
            value: "Upsell suggested in context: %@",
            comment: "Log message when an upsell is suggested"
        )
        let formatted = String(format: message, context)
        await logEvent(eventKey, metadata: [
            "context": context,
            "userID": userID as Any,
            "description": formatted
        ])
    }

    /// Audit log for compliance and Trust Center.
    public func auditLog() -> [UpsellAnalyticsEvent] {
        // Returns the recent event buffer for audit purposes.
        return recentEvents
    }

    /// Diagnostics for admin panels or QA.
    public func diagnostics() -> String {
        let diagKey = "UpsellEngine.diagnostics"
        let diagMsg = NSLocalizedString(
            diagKey,
            value: "Diagnostics: %d recent events. Test Mode: %@",
            comment: "Diagnostics string for UpsellEngine"
        )
        let mode = testMode ? NSLocalizedString("UpsellEngine.testModeOn", value: "ON", comment: "Test mode ON") :
            NSLocalizedString("UpsellEngine.testModeOff", value: "OFF", comment: "Test mode OFF")
        let eventLines = recentEvents.map { event in
            let dateStr = DateFormatter.localizedString(from: event.timestamp, dateStyle: .short, timeStyle: .medium)
            let metaStr = event.metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = event.role ?? "-"
            let staffID = event.staffID ?? "-"
            let context = event.context ?? "-"
            let escalate = event.escalate ? "YES" : "NO"
            return "[\(dateStr)] \(event.event) | \(metaStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
        return ([String(format: diagMsg, recentEvents.count, mode)] + eventLines).joined(separator: "\n")
    }

    /// Fetches the last N analytics events (default: 20).
    /// - Parameter limit: Number of events to fetch.
    public func fetchRecentEvents(limit: Int = 20) -> [UpsellAnalyticsEvent] {
        return Array(recentEvents.suffix(limit))
    }

    /// Internal: Log an analytics event and update buffer.
    private func logEvent(_ event: String, metadata: [String: Any]?) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        let analyticsEvent = UpsellAnalyticsEvent(
            timestamp: Date(),
            event: event,
            metadata: metadata,
            role: UpsellAuditContext.role,
            staffID: UpsellAuditContext.staffID,
            context: UpsellAuditContext.context,
            escalate: escalate
        )
        // Update buffer (capped at eventBufferLimit)
        if recentEvents.count >= eventBufferLimit {
            recentEvents.removeFirst()
        }
        recentEvents.append(analyticsEvent)
        await analyticsLogger.log(
            event: event,
            metadata: metadata,
            role: UpsellAuditContext.role,
            staffID: UpsellAuditContext.staffID,
            context: UpsellAuditContext.context,
            escalate: escalate
        )
        // For compliance, all logs/messages are localized
    }
}

// MARK: - SwiftUI PreviewProvider for diagnostics, testMode, accessibility
#if DEBUG
struct UpsellEngine_Previews: PreviewProvider {
    static var previews: some View {
        UpsellEnginePreviewView()
            .environment(\.locale, .init(identifier: "en"))
            .accessibilityElement(children: .contain)
    }

    struct UpsellEnginePreviewView: View {
        @StateObject var engine = UpsellEngine(analyticsLogger: NullUpsellAnalyticsLogger())
        @State private var showDiag = false
        var body: some View {
            VStack(spacing: 20) {
                Text(NSLocalizedString(
                    "UpsellEngine.previewTitle",
                    value: "UpsellEngine Diagnostics Preview",
                    comment: "Preview title for UpsellEngine"
                ))
                    .font(.headline)
                    .accessibilityLabel(Text(NSLocalizedString(
                        "UpsellEngine.previewTitle.accessibility",
                        value: "Upsell Engine Diagnostics Preview",
                        comment: "Accessibility label for preview title"
                    )))
                Button(action: {
                    Task {
                        await engine.suggestUpsell(context: "Preview", userID: "testUser")
                    }
                }) {
                    Text(NSLocalizedString(
                        "UpsellEngine.previewSuggestButton",
                        value: "Suggest Upsell",
                        comment: "Button to trigger upsell suggestion in preview"
                    ))
                }
                .accessibilityHint(Text(NSLocalizedString(
                    "UpsellEngine.previewSuggestButton.hint",
                    value: "Triggers a test upsell event",
                    comment: "Accessibility hint for suggest button"
                )))
                HStack {
                    Text(NSLocalizedString(
                        "UpsellEngine.previewTestMode",
                        value: "Test Mode:",
                        comment: "Label for test mode"
                    ))
                    Toggle(isOn: Binding(
                        get: { engine.testMode },
                        set: { engine.testMode = $0 }
                    )) {
                        Text(engine.testMode ?
                             NSLocalizedString("UpsellEngine.testModeOn", value: "ON", comment: "Test mode ON") :
                             NSLocalizedString("UpsellEngine.testModeOff", value: "OFF", comment: "Test mode OFF"))
                    }
                    .accessibilityLabel(Text(NSLocalizedString(
                        "UpsellEngine.previewTestMode.accessibility",
                        value: "Test Mode Toggle",
                        comment: "Accessibility label for test mode toggle"
                    )))
                }
                Button(action: { showDiag.toggle() }) {
                    Text(NSLocalizedString(
                        "UpsellEngine.previewDiagnosticsButton",
                        value: "Show Diagnostics",
                        comment: "Show diagnostics button"
                    ))
                }
                .accessibilityHint(Text(NSLocalizedString(
                    "UpsellEngine.previewDiagnosticsButton.hint",
                    value: "Shows recent analytics events",
                    comment: "Accessibility hint for diagnostics button"
                )))
                if showDiag {
                    ScrollView {
                        Text(engine.diagnostics())
                            .font(.caption)
                            .padding(.bottom, 5)
                        ForEach(engine.fetchRecentEvents()) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                let dateStr = DateFormatter.localizedString(from: event.timestamp, dateStyle: .short, timeStyle: .medium)
                                let metaStr = event.metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
                                let role = event.role ?? "-"
                                let staffID = event.staffID ?? "-"
                                let context = event.context ?? "-"
                                let escalate = event.escalate ? "YES" : "NO"
                                Text(
                                    String(
                                        format: NSLocalizedString(
                                            "UpsellEngine.previewEventFormat",
                                            value: "[%@] %@ | %@ | role:%@ staffID:%@ context:%@ escalate:%@",
                                            comment: "Event timestamp and name with audit details"
                                        ),
                                        dateStr,
                                        event.event,
                                        metaStr,
                                        role,
                                        staffID,
                                        context,
                                        escalate
                                    )
                                )
                            }
                            .padding(4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(4)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .padding()
        }
    }
}
#endif
