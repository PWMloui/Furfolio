//
//  Multi-lineInput.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct MultiLineInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "MultiLineInput"
}

/**
 Multi-lineInput Component Architecture and Features:
 
 This SwiftUI component provides a customizable multi-line text input view with built-in support for analytics logging, accessibility, localization, diagnostics, and compliance readiness.
 
 Architecture & Extensibility:
 - Designed as a reusable SwiftUI view with configurable parameters for placeholder, line limits, and accessibility.
 - Analytics logging is injected via a protocol, allowing for production, testing, or preview implementations.
 - Event buffering supports diagnostics and audit trails.
 
 Analytics / Audit / Trust Center Hooks:
 - Async/await-ready analytics logger protocol `MultiLineInputAnalyticsLogger` supports seamless integration with backend or local analytics.
 - Includes a testMode flag to enable console-only logging for QA, tests, and previews.
 - Captures user interaction events with localized event names and details, including audit context.
 
 Diagnostics:
 - Maintains a capped buffer of the last 20 analytics events for diagnostic retrieval.
 - Public API to fetch recent events for admin or diagnostic tooling.
 
 Localization:
 - All user-facing strings and analytics event strings are wrapped with NSLocalizedString with keys and comments.
 - Supports easy localization and internationalization.
 
 Accessibility:
 - Supports configurable accessibility labels and hints.
 - Ensures VoiceOver and assistive technologies can properly describe the input.
 
 Compliance:
 - Designed with auditability and traceability in mind.
 - Analytics events capture relevant user interaction data without sensitive information, including role and staffID for audit.
 
 Preview / Testability:
 - Includes a Null logger implementation for previews and tests.
 - PreviewProvider demonstrates accessibility, testMode analytics, and diagnostics features.
 
 Future maintainers should find this component easy to extend, localize, and integrate into larger applications with robust audit and diagnostic capabilities.
 */

/// Protocol defining an async/await-ready analytics logger for MultiLineInput component with audit context.
public protocol MultiLineInputAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously with audit context and escalation flag.
    /// - Parameters:
    ///   - eventName: The localized name of the event.
    ///   - parameters: Dictionary of localized event parameters.
    ///   - role: Audit role context.
    ///   - staffID: Audit staff ID context.
    ///   - context: Audit context string.
    ///   - escalate: Flag indicating if the event requires escalation.
    func logEvent(
        eventName: String,
        parameters: [String: String],
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    
    /// Returns the recent analytics events for diagnostics.
    func recentEvents() -> [MultiLineInputAnalyticsEvent]
}

/// Struct representing a single analytics event with audit context.
public struct MultiLineInputAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let eventName: String
    public let parameters: [String: String]
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Null implementation of MultiLineInputAnalyticsLogger for previews and tests.
/// Performs no-op logging but prints audit fields if testMode is true.
public struct NullMultiLineInputAnalyticsLogger: MultiLineInputAnalyticsLogger {
    public let testMode = true
    
    public init() {}
    
    public func logEvent(
        eventName: String,
        parameters: [String : String],
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("Analytics Event: \(eventName), parameters: \(parameters), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
        // No event storage for Null logger.
    }
    
    public func recentEvents() -> [MultiLineInputAnalyticsEvent] {
        return []
    }
}

/// A SwiftUI view representing a multi-line text input with analytics, accessibility, localization, and audit support.
public struct MultiLineInput: View {
    /// Binding to the text content.
    @Binding public var text: String
    
    /// Placeholder text displayed when the input is empty.
    public let placeholder: String
    
    /// Minimum number of visible text lines.
    public let minLines: Int
    
    /// Maximum number of visible text lines.
    public let maxLines: Int
    
    /// Injected analytics logger.
    public let analyticsLogger: MultiLineInputAnalyticsLogger
    
    /// Accessibility label for the input.
    public let accessibilityLabel: String
    
    /// Accessibility hint for the input.
    public let accessibilityHint: String
    
    /// Internal state to keep track of the dynamic height of the text input.
    @State private var textViewHeight: CGFloat = 0
    
    /// Internal capped buffer of recent analytics events for diagnostics.
    @State private var recentEvents: [MultiLineInputAnalyticsEvent] = []
    
    /// Maximum number of events to keep in the buffer.
    private let maxEventBufferSize = 20
    
    /// Localization keys for placeholder and accessibility strings.
    private enum L10n {
        static let placeholderKey = "MultiLineInput_Placeholder"
        static let accessibilityLabelKey = "MultiLineInput_AccessibilityLabel"
        static let accessibilityHintKey = "MultiLineInput_AccessibilityHint"
        
        static let eventFocusKey = "MultiLineInput_Event_Focus"
        static let eventBlurKey = "MultiLineInput_Event_Blur"
        static let eventTextChangeKey = "MultiLineInput_Event_TextChange"
    }
    
    /// Initializes a new MultiLineInput view.
    /// - Parameters:
    ///   - text: Binding to the text content.
    ///   - placeholder: Placeholder string (localized).
    ///   - minLines: Minimum visible lines count.
    ///   - maxLines: Maximum visible lines count.
    ///   - analyticsLogger: Analytics logger instance.
    ///   - accessibilityLabel: Accessibility label string (localized).
    ///   - accessibilityHint: Accessibility hint string (localized).
    public init(text: Binding<String>,
                placeholder: String = NSLocalizedString(L10n.placeholderKey, value: "Enter text...", comment: "Placeholder for multi-line input"),
                minLines: Int = 3,
                maxLines: Int = 6,
                analyticsLogger: MultiLineInputAnalyticsLogger = NullMultiLineInputAnalyticsLogger(),
                accessibilityLabel: String = NSLocalizedString(L10n.accessibilityLabelKey, value: "Multi-line text input", comment: "Accessibility label for multi-line input"),
                accessibilityHint: String = NSLocalizedString(L10n.accessibilityHintKey, value: "Double tap to edit text", comment: "Accessibility hint for multi-line input")) {
        self._text = text
        self.placeholder = placeholder
        self.minLines = minLines
        self.maxLines = maxLines
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
    
    /// Public API to fetch recent analytics events for diagnostics.
    public func getRecentEvents() -> [MultiLineInputAnalyticsEvent] {
        return recentEvents
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                    .accessibilityHidden(true)
            }
            
            TextEditor(text: $text)
                .frame(minHeight: CGFloat(minLines) * UIFont.preferredFont(forTextStyle: .body).lineHeight,
                       maxHeight: CGFloat(maxLines) * UIFont.preferredFont(forTextStyle: .body).lineHeight)
                .padding(4)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
                .onAppear {
                    Task {
                        await logEvent(nameKey: L10n.eventFocusKey, parameters: [:])
                    }
                }
                .onTapGesture {
                    Task {
                        await logEvent(nameKey: L10n.eventFocusKey, parameters: [:])
                    }
                }
                .onChange(of: text) { newValue in
                    Task {
                        await logEvent(nameKey: L10n.eventTextChangeKey, parameters: ["textLength": "\(newValue.count)"])
                    }
                }
                .onDisappear {
                    Task {
                        await logEvent(nameKey: L10n.eventBlurKey, parameters: [:])
                    }
                }
        }
    }
    
    /// Helper method to log analytics events with localized event names and audit context.
    /// Updates the recent events buffer.
    /// - Parameters:
    ///   - nameKey: Localization key for the event name.
    ///   - parameters: Event parameters dictionary.
    private func logEvent(nameKey: String, parameters: [String: String]) async {
        let localizedEventName = NSLocalizedString(nameKey, value: nameKey, comment: "Analytics event name")
        
        // Determine escalation: true if textLength > 2000 or eventName contains "critical"
        var escalate = false
        if let textLengthStr = parameters["textLength"], let textLength = Int(textLengthStr), textLength > 2000 {
            escalate = true
        } else if localizedEventName.lowercased().contains("critical") {
            escalate = true
        }
        
        let event = MultiLineInputAnalyticsEvent(
            timestamp: Date(),
            eventName: localizedEventName,
            parameters: parameters,
            role: MultiLineInputAuditContext.role,
            staffID: MultiLineInputAuditContext.staffID,
            context: MultiLineInputAuditContext.context,
            escalate: escalate
        )
        
        await analyticsLogger.logEvent(
            eventName: localizedEventName,
            parameters: parameters,
            role: MultiLineInputAuditContext.role,
            staffID: MultiLineInputAuditContext.staffID,
            context: MultiLineInputAuditContext.context,
            escalate: escalate
        )
        
        if analyticsLogger.testMode {
            await MainActor.run {
                recentEvents.append(event)
                if recentEvents.count > maxEventBufferSize {
                    recentEvents.removeFirst(recentEvents.count - maxEventBufferSize)
                }
            }
        }
    }
}

struct MultiLineInput_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text: String = ""
        
        /// A simple analytics logger that prints events to console for preview/testing with audit context.
        struct ConsoleAnalyticsLogger: MultiLineInputAnalyticsLogger {
            let testMode = true
            
            func logEvent(
                eventName: String,
                parameters: [String : String],
                role: String?,
                staffID: String?,
                context: String?,
                escalate: Bool
            ) async {
                print("Analytics Event: \(eventName), parameters: \(parameters), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
            }
            
            func recentEvents() -> [MultiLineInputAnalyticsEvent] {
                return []
            }
        }
        
        var body: some View {
            VStack(spacing: 20) {
                MultiLineInput(
                    text: $text,
                    placeholder: NSLocalizedString("MultiLineInput_Placeholder", value: "Enter your notes here...", comment: "Placeholder text for preview"),
                    minLines: 4,
                    maxLines: 8,
                    analyticsLogger: ConsoleAnalyticsLogger(),
                    accessibilityLabel: NSLocalizedString("MultiLineInput_AccessibilityLabel", value: "Notes input", comment: "Accessibility label for preview"),
                    accessibilityHint: NSLocalizedString("MultiLineInput_AccessibilityHint", value: "Double tap and enter notes", comment: "Accessibility hint for preview")
                )
                .padding()
                .border(Color.gray)
                
                Text("Recent Analytics Events:")
                    .font(.headline)
                ScrollView {
                    ForEach(Array(MultiLineInput(text: $text).getRecentEvents().enumerated()), id: \.offset) { index, event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Timestamp: \(event.timestamp.description)")
                                .font(.caption2)
                            Text("Event Name: \(event.eventName)")
                                .font(.caption2)
                            Text("Parameters: \(event.parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
                                .font(.caption2)
                            Text("Role: \(event.role ?? "nil")")
                                .font(.caption2)
                            Text("Staff ID: \(event.staffID ?? "nil")")
                                .font(.caption2)
                            Text("Context: \(event.context ?? "nil")")
                                .font(.caption2)
                            Text("Escalate: \(event.escalate ? "Yes" : "No")")
                                .font(.caption2)
                        }
                        .padding(2)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 150)
                .border(Color.secondary)
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("MultiLineInput Preview with Analytics and Accessibility")
    }
}
