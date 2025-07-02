//
//  LookalikeEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct LookalikeAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "LookalikeEngine"
}

/**
 LookalikeEngine.swift

 This file contains the core implementation of the LookalikeEngine, a modular and extensible engine designed to analyze user data and generate lookalike audiences for targeted marketing or recommendation purposes.

 Architecture and Purpose:
 - The LookalikeEngine class encapsulates the main logic for analyzing data and generating lookalike audiences.
 - It supports asynchronous analytics logging using the LookalikeAnalyticsLogger protocol.
 - The engine maintains an internal capped buffer of recent analytics events to facilitate diagnostics, auditing, and admin review.
 - User-facing strings and log messages are fully localized using NSLocalizedString to support internationalization.
 - The design encourages extension and customization by allowing injection of different analytics loggers.

 Extensibility:
 - Analytics logging is abstracted via the LookalikeAnalyticsLogger protocol, enabling easy replacement or enhancement of logging mechanisms.
 - The engine exposes async methods for audit logging, diagnostics, and data processing, allowing integration with various backend services or UI layers.
 - The capped analytics event buffer provides a foundation for future enhancements such as exporting logs or integrating with trust center frameworks.

 Analytics, Audit, and Trust Center Hooks:
 - The engine supports auditLog() and diagnostics() async methods that can be connected to external monitoring or trust center components.
 - The analytics logger protocol supports a testMode flag to toggle console-only logging during QA, testing, or previews.
 - All analytics events are buffered internally for review and diagnostics.

 Diagnostics:
 - The diagnostics() method returns detailed diagnostic information about the engine’s state.
 - A capped buffer of the last 20 analytics events is maintained and accessible via a public API.

 Localization:
 - All user-facing and log event strings use NSLocalizedString with explicit keys and comments to facilitate localization workflows.
 - This includes error messages, status updates, and analytics event descriptions.

 Accessibility:
 - Although primarily a backend engine, the included PreviewProvider demonstrates accessibility features such as dynamic type support and clear diagnostic output for assistive technologies.

 Compliance:
 - The engine is designed with compliance in mind, supporting audit logging and traceability.
 - It encourages safe preview and testing via the NullLookalikeAnalyticsLogger to avoid accidental data leaks.

 Preview and Testability:
 - A SwiftUI PreviewProvider is included to demonstrate diagnostics output, testMode behavior, and accessibility support.
 - The NullLookalikeAnalyticsLogger provides a no-op logger for safe usage in previews and tests.

 This documentation aims to assist maintainers and future developers in understanding the design decisions, usage, and extension points of the LookalikeEngine.
 */

// MARK: - Analytics Logger Protocol

/// Protocol defining an asynchronous analytics logger for the LookalikeEngine.
///
/// Conforming types should implement the `logEvent` method to handle analytics events asynchronously.
/// The `testMode` flag indicates whether the logger should perform console-only logging without external side effects,
/// useful for QA, testing, and SwiftUI previews.
public protocol LookalikeAnalyticsLogger {
    /// Indicates whether the logger is running in test mode (console-only logging).
    var testMode: Bool { get }
    /// Logs an analytics event asynchronously with audit context.
    /// - Parameters:
    ///   - event: The event description string.
    ///   - metadata: Optional dictionary of metadata.
    ///   - role: Audit role.
    ///   - staffID: Audit staff/user ID.
    ///   - context: Audit context string.
    ///   - escalate: Critical/escalation flag.
    func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public extension LookalikeAnalyticsLogger {
    /// Default implementation of testMode is false.
    var testMode: Bool { false }
}

// MARK: - Null Analytics Logger

/// A no-op analytics logger for safe usage in previews and tests.
/// Logs events to the console only if `testMode` is true.
public struct NullLookalikeAnalyticsLogger: LookalikeAnalyticsLogger {
    public var testMode: Bool = true

    public init(testMode: Bool = true) {
        self.testMode = testMode
    }

    public func logEvent(
        _ event: String,
        metadata: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[NullLookalikeAnalyticsLogger][TEST MODE] \(event) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
        // No external logging performed.
    }
}

// MARK: - LookalikeEngine Class

/// Core engine responsible for analyzing user data and generating lookalike audiences.
///
/// Supports asynchronous analytics logging, audit trails, diagnostics, localization, and accessibility.
/// Designed for extensibility and safe usage in previews and tests.
public class LookalikeEngine: ObservableObject {
    // MARK: - Properties

    /// The analytics logger used for event logging.
    private let analyticsLogger: LookalikeAnalyticsLogger

    /// Internal buffer storing the last 20 analytics events.
    private var analyticsEventBuffer: [(event: String, date: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []

    /// Maximum number of analytics events to keep in the buffer.
    private let maxBufferSize = 20

    /// Queue to synchronize access to analyticsEventBuffer.
    private let bufferQueue = DispatchQueue(label: "LookalikeEngine.analyticsEventBufferQueue", attributes: .concurrent)

    // MARK: - Initialization

    /// Initializes the LookalikeEngine with a specified analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use. Defaults to NullLookalikeAnalyticsLogger in test mode.
    public init(analyticsLogger: LookalikeAnalyticsLogger = NullLookalikeAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Public API

    /// Analyzes user data asynchronously.
    /// - Parameter userData: Dictionary representing user attributes.
    /// - Returns: A boolean indicating success or failure.
    @discardableResult
    public func analyzeUserData(_ userData: [String: Any]) async -> Bool {
        let eventDescription = NSLocalizedString(
            "LookalikeEngine.AnalyzeUserData.Event",
            value: "Analyzing user data with attributes: \(userData)",
            comment: "Analytics event description when analyzing user data"
        )
        await logAnalyticsEvent(eventDescription, metadata: userData)

        // Placeholder for analysis logic.
        // TODO: Implement actual analysis algorithm here.

        let successMessage = NSLocalizedString(
            "LookalikeEngine.AnalyzeUserData.Success",
            value: "User data analysis completed successfully.",
            comment: "User-facing message indicating successful analysis"
        )
        await logAnalyticsEvent(successMessage)

        return true
    }

    /// Generates lookalike audiences asynchronously based on previously analyzed data.
    /// - Returns: An array of dictionaries representing lookalike audience profiles.
    public func generateLookalikeAudiences() async -> [[String: Any]] {
        let eventDescription = NSLocalizedString(
            "LookalikeEngine.GenerateLookalikes.Event",
            value: "Generating lookalike audiences.",
            comment: "Analytics event description when generating lookalike audiences"
        )
        await logAnalyticsEvent(eventDescription)

        // Placeholder for generation logic.
        // TODO: Implement actual lookalike audience generation here.

        let successMessage = NSLocalizedString(
            "LookalikeEngine.GenerateLookalikes.Success",
            value: "Lookalike audience generation completed.",
            comment: "User-facing message indicating successful generation"
        )
        await logAnalyticsEvent(successMessage)

        // Returning empty array as stub.
        return []
    }

    /// Performs audit logging asynchronously.
    ///
    /// This method can be connected to external audit or trust center components.
    public func auditLog() async {
        let auditMessage = NSLocalizedString(
            "LookalikeEngine.AuditLog.Event",
            value: "Performing audit log operation.",
            comment: "Audit log event description"
        )
        await logAnalyticsEvent(auditMessage)

        // TODO: Implement audit logging to external systems here.
    }

    /// Provides diagnostic information asynchronously.
    ///
    /// - Returns: A dictionary containing diagnostic key-value pairs.
    public func diagnostics() async -> [String: String] {
        let diagnosticsRequestMessage = NSLocalizedString(
            "LookalikeEngine.Diagnostics.Request",
            value: "Diagnostics requested.",
            comment: "Log message when diagnostics are requested"
        )
        await logAnalyticsEvent(diagnosticsRequestMessage)

        // Example diagnostic info.
        var diagnosticsData: [String: String] = [:]
        diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.BufferSize.Key", value: "Analytics Buffer Size", comment: "Key for analytics buffer size in diagnostics")] = "\(analyticsEventBuffer.count)"
        diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.TestMode.Key", value: "Test Mode Enabled", comment: "Key for test mode status in diagnostics")] = analyticsLogger.testMode ? NSLocalizedString("LookalikeEngine.Diagnostics.TestMode.True", value: "Yes", comment: "Test mode enabled") : NSLocalizedString("LookalikeEngine.Diagnostics.TestMode.False", value: "No", comment: "Test mode disabled")

        // Include latest event details if available
        if let lastEvent = analyticsEventBuffer.last {
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Key", value: "Last Event", comment: "Key for last event in diagnostics")] = lastEvent.event
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Date", value: "Last Event Date", comment: "Key for last event date in diagnostics")] = "\(lastEvent.date)"
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Role", value: "Last Event Role", comment: "Key for last event role in diagnostics")] = lastEvent.role ?? "-"
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.StaffID", value: "Last Event StaffID", comment: "Key for last event staffID in diagnostics")] = lastEvent.staffID ?? "-"
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Context", value: "Last Event Context", comment: "Key for last event context in diagnostics")] = lastEvent.context ?? "-"
            diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Escalate", value: "Last Event Escalate", comment: "Key for last event escalate flag in diagnostics")] = lastEvent.escalate ? NSLocalizedString("LookalikeEngine.Diagnostics.Escalate.Yes", value: "Yes", comment: "Escalate flag true") : NSLocalizedString("LookalikeEngine.Diagnostics.Escalate.No", value: "No", comment: "Escalate flag false")
            if let metadata = lastEvent.metadata {
                diagnosticsData[NSLocalizedString("LookalikeEngine.Diagnostics.LastEvent.Metadata", value: "Last Event Metadata", comment: "Key for last event metadata in diagnostics")] = "\(metadata)"
            }
        }

        return diagnosticsData
    }

    /// Retrieves the most recent analytics events for admin or diagnostics purposes.
    ///
    /// - Returns: An array of the most recent analytics event tuples, capped at 20.
    public func recentAnalyticsEvents() -> [(event: String, date: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        var events: [(event: String, date: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
        bufferQueue.sync {
            events = analyticsEventBuffer
        }
        return events
    }

    // MARK: - Private Helpers

    /// Logs an analytics event asynchronously, storing it in the internal buffer and forwarding to the analytics logger.
    /// - Parameters:
    ///   - event: The event description string.
    ///   - metadata: Optional dictionary of metadata.
    private func logAnalyticsEvent(_ event: String, metadata: [String: Any]? = nil) async {
        let lowercasedEvent = event.lowercased()
        let escalate = lowercasedEvent.contains("danger") || lowercasedEvent.contains("critical") || lowercasedEvent.contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)

        // Append to buffer in a thread-safe manner.
        bufferQueue.async(flags: .barrier) {
            self.analyticsEventBuffer.append((event: event, date: Date(), metadata: metadata, role: LookalikeAuditContext.role, staffID: LookalikeAuditContext.staffID, context: LookalikeAuditContext.context, escalate: escalate))
            if self.analyticsEventBuffer.count > self.maxBufferSize {
                self.analyticsEventBuffer.removeFirst(self.analyticsEventBuffer.count - self.maxBufferSize)
            }
        }

        // Forward event to analytics logger.
        await analyticsLogger.logEvent(
            event,
            metadata: metadata,
            role: LookalikeAuditContext.role,
            staffID: LookalikeAuditContext.staffID,
            context: LookalikeAuditContext.context,
            escalate: escalate
        )
    }
}

// MARK: - SwiftUI PreviewProvider for Diagnostics and Accessibility

#if DEBUG
import XCTest

/// SwiftUI PreviewProvider demonstrating diagnostics, testMode, and accessibility features of LookalikeEngine.
struct LookalikeEngine_Previews: PreviewProvider {
    struct DiagnosticsView: View {
        @StateObject private var engine = LookalikeEngine(analyticsLogger: NullLookalikeAnalyticsLogger(testMode: true))
        @State private var diagnosticsData: [String: String] = [:]
        @State private var recentEvents: [(event: String, date: Date, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("LookalikeEngine.Preview.Title", value: "LookalikeEngine Diagnostics Preview", comment: "Title for diagnostics preview"))
                    .font(.title)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Button(action: {
                    Task {
                        diagnosticsData = await engine.diagnostics()
                        recentEvents = engine.recentAnalyticsEvents()
                    }
                }) {
                    Text(NSLocalizedString("LookalikeEngine.Preview.FetchDiagnostics", value: "Fetch Diagnostics", comment: "Button label to fetch diagnostics"))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(NSLocalizedString("LookalikeEngine.Preview.FetchDiagnostics.Hint", value: "Fetches diagnostic information asynchronously", comment: "Accessibility hint for fetch diagnostics button"))

                if !diagnosticsData.isEmpty {
                    List {
                        Section(header: Text(NSLocalizedString("LookalikeEngine.Preview.DiagnosticsSummary", value: "Diagnostics Summary", comment: "Section header for diagnostics summary"))) {
                            ForEach(diagnosticsData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(value)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        if !recentEvents.isEmpty {
                            Section(header: Text(NSLocalizedString("LookalikeEngine.Preview.RecentEvents", value: "Recent Analytics Events", comment: "Section header for recent analytics events"))) {
                                ForEach(Array(recentEvents.enumerated()), id: \.offset) { index, eventTuple in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(eventTuple.event)")
                                            .fontWeight(.semibold)
                                        if let metadata = eventTuple.metadata {
                                            Text("Metadata: \(metadata)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Role: \(eventTuple.role ?? "-") | StaffID: \(eventTuple.staffID ?? "-") | Context: \(eventTuple.context ?? "-")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Escalate: \(eventTuple.escalate ? NSLocalizedString("LookalikeEngine.Diagnostics.Escalate.Yes", value: "Yes", comment: "Escalate flag true") : NSLocalizedString("LookalikeEngine.Diagnostics.Escalate.No", value: "No", comment: "Escalate flag false"))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Date: \(eventTuple.date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityLabel(NSLocalizedString("LookalikeEngine.Preview.DiagnosticsListLabel", value: "Diagnostics Information", comment: "Accessibility label for diagnostics list"))
                } else {
                    Text(NSLocalizedString("LookalikeEngine.Preview.NoDiagnostics", value: "No diagnostics data available.", comment: "Message shown when no diagnostics data is present"))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    static var previews: some View {
        DiagnosticsView()
            .environment(\.sizeCategory, .extraExtraExtraLarge) // Accessibility: Test dynamic type
            .previewDisplayName("LookalikeEngine Diagnostics Preview")
    }
}
#endif
