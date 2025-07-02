//
//  ToggleButton.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ToggleButtonAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ToggleButton"
}

/**
 `ToggleButton` is a reusable SwiftUI component designed to provide a customizable toggle switch with integrated analytics, accessibility, localization, and diagnostics support.

 # Architecture
 - Built as a SwiftUI `View` with binding support for state management.
 - Supports injection of an analytics logger conforming to `ToggleButtonAnalyticsLogger` protocol.
 - Uses async/await for logging analytics events to enable non-blocking UI updates.
 - Maintains an internal capped buffer of recent analytics events for diagnostics and audit purposes.

 # Extensibility
 - Analytics logging is abstracted via a protocol, allowing easy replacement or extension with real or mock loggers.
 - Customizable parameters include title, icon, color, accessibility labels/hints, enabling adaptation to various UI requirements.
 - Localization-ready strings ensure easy internationalization.

 # Analytics / Audit / Trust Center Hooks
 - Logs toggle state changes asynchronously via injected analytics logger.
 - Supports a testMode flag for console-only logging during QA, tests, or previews.
 - Maintains a capped event buffer (last 20 events) accessible via public API for diagnostics/admin review.

 # Diagnostics
 - Provides recent analytics events for inspection.
 - Includes a `NullToggleButtonAnalyticsLogger` for testing and preview environments without side effects.

 # Localization
 - All user-facing and log event strings use `NSLocalizedString` with keys, default values, and descriptive comments for translators.

 # Accessibility
 - Supports accessibility labels and hints, customizable per instance.
 - Ensures VoiceOver and other assistive technologies have meaningful context.

 # Compliance
 - Designed to support audit and trust center requirements via detailed analytics logging and diagnostics.
 - Enables traceability of user interactions with the toggle button.

 # Preview / Testability
 - Includes a comprehensive `PreviewProvider` demonstrating accessibility, testMode logging, and diagnostics.
 - Uses `NullToggleButtonAnalyticsLogger` in previews to avoid side effects.

 This documentation aims to assist future maintainers and developers in understanding the design decisions, usage, and extension points of the `ToggleButton` component.
 */
 
/// Protocol defining an async/await-ready analytics logger for ToggleButton events with audit context.
public protocol ToggleButtonAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging without external side effects).
    var testMode: Bool { get }
    
    /**
     Logs an analytics event asynchronously with detailed audit context.
     
     - Parameters:
        - event: The string describing the event to log.
        - newValue: The new toggle state after the change.
        - title: The title of the toggle button.
        - icon: Optional icon name associated with the toggle.
        - role: User role from audit context.
        - staffID: Staff ID from audit context.
        - context: Context string from audit context.
        - escalate: Flag indicating if the event should be escalated due to critical content.
     */
    func logEvent(
        _ event: String,
        newValue: Bool,
        title: String,
        icon: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    
    /**
     Retrieves recent logged events for diagnostics or administrative purposes.
     
     - Returns: An array of the most recent logged `ToggleButtonAnalyticsEvent` objects.
     */
    func recentEvents() -> [ToggleButtonAnalyticsEvent]
}

/// Struct representing a detailed analytics event for ToggleButton, including audit and escalation info.
public struct ToggleButtonAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let newValue: Bool
    public let title: String
    public let icon: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A no-op analytics logger used for previews, tests, and QA environments.
/// Logs events only to the console if `testMode` is true, printing all audit fields.
public struct NullToggleButtonAnalyticsLogger: ToggleButtonAnalyticsLogger {
    public let testMode: Bool
    
    public init(testMode: Bool = true) {
        self.testMode = testMode
    }
    
    public func logEvent(
        _ event: String,
        newValue: Bool,
        title: String,
        icon: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
                ToggleButton Event (Test Mode):
                Event: \(event)
                New Value: \(newValue)
                Title: \(title)
                Icon: \(icon ?? "nil")
                Role: \(role ?? "nil")
                StaffID: \(staffID ?? "nil")
                Context: \(context ?? "nil")
                Escalate: \(escalate)
                """)
        }
        // No external logging performed.
    }
    
    public func recentEvents() -> [ToggleButtonAnalyticsEvent] {
        // No events stored in null logger.
        return []
    }
}

/// A SwiftUI View representing a toggle button with integrated analytics, localization, accessibility, and diagnostics support.
public struct ToggleButton: View {
    /// Binding to the toggle state.
    @Binding public var isOn: Bool
    
    /// The title displayed next to the toggle.
    public let title: String
    
    /// Optional system image icon name displayed alongside the title.
    public let icon: String?
    
    /// The color used for the toggle when it is on.
    public let color: Color
    
    /// Accessibility label for the toggle button.
    public let accessibilityLabel: String
    
    /// Accessibility hint providing additional context.
    public let accessibilityHint: String
    
    /// The analytics logger to use for event logging.
    private let analyticsLogger: ToggleButtonAnalyticsLogger
    
    /// Internal capped buffer for recent analytics events.
    @State private var eventBuffer: [ToggleButtonAnalyticsEvent] = []
    
    /// Maximum number of events to retain in the buffer.
    private let maxEventBufferSize = 20
    
    /**
     Initializes a new `ToggleButton`.
     
     - Parameters:
        - isOn: Binding to the toggle state.
        - title: The display title for the toggle.
        - icon: Optional system image icon name.
        - color: The color for the toggle when active.
        - analyticsLogger: An injected analytics logger conforming to `ToggleButtonAnalyticsLogger`.
        - accessibilityLabel: Accessibility label for the toggle.
        - accessibilityHint: Accessibility hint for the toggle.
     */
    public init(
        isOn: Binding<Bool>,
        title: String,
        icon: String? = nil,
        color: Color = .blue,
        analyticsLogger: ToggleButtonAnalyticsLogger = NullToggleButtonAnalyticsLogger(),
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self._isOn = isOn
        self.title = NSLocalizedString(title, comment: "ToggleButton title")
        self.icon = icon
        self.color = color
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel ?? NSLocalizedString(title, comment: "Accessibility label for ToggleButton")
        self.accessibilityHint = accessibilityHint ?? NSLocalizedString("Double tap to toggle", comment: "Accessibility hint for ToggleButton")
    }
    
    public var body: some View {
        Button(action: toggle) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .foregroundColor(isOn ? color : .secondary)
                }
                Text(title)
                    .foregroundColor(isOn ? color : .primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? color : .secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? color : Color.secondary, lineWidth: 2)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }
    
    /// Toggles the state and logs the event asynchronously with audit context.
    private func toggle() {
        isOn.toggle()
        let eventDescription = String(
            format: NSLocalizedString("ToggleButton toggled to %@", comment: "Analytics event description for toggle state"),
            isOn ? NSLocalizedString("ON", comment: "Toggle state ON") : NSLocalizedString("OFF", comment: "Toggle state OFF")
        )
        
        // Determine if escalation is needed based on keywords in title, icon, or accessibilityLabel
        let lowerTitle = title.lowercased()
        let lowerIcon = icon?.lowercased() ?? ""
        let lowerAccessibilityLabel = accessibilityLabel.lowercased()
        let escalationKeywords = ["delete", "danger", "critical"]
        let escalate = escalationKeywords.contains(where: { lowerTitle.contains($0) || lowerIcon.contains($0) || lowerAccessibilityLabel.contains($0) })
        
        Task {
            await analyticsLogger.logEvent(
                eventDescription,
                newValue: isOn,
                title: self.title,
                icon: self.icon,
                role: ToggleButtonAuditContext.role,
                staffID: ToggleButtonAuditContext.staffID,
                context: ToggleButtonAuditContext.context,
                escalate: escalate
            )
            await MainActor.run {
                appendEventToBuffer(
                    ToggleButtonAnalyticsEvent(
                        timestamp: Date(),
                        event: eventDescription,
                        newValue: isOn,
                        title: self.title,
                        icon: self.icon,
                        role: ToggleButtonAuditContext.role,
                        staffID: ToggleButtonAuditContext.staffID,
                        context: ToggleButtonAuditContext.context,
                        escalate: escalate
                    )
                )
            }
        }
    }
    
    /// Appends an event to the internal buffer, capping its size.
    /// - Parameter event: The `ToggleButtonAnalyticsEvent` to append.
    @MainActor
    private func appendEventToBuffer(_ event: ToggleButtonAnalyticsEvent) {
        eventBuffer.append(event)
        if eventBuffer.count > maxEventBufferSize {
            eventBuffer.removeFirst(eventBuffer.count - maxEventBufferSize)
        }
    }
    
    /// Public API to retrieve recent analytics events for diagnostics and audit review.
    public func recentEvents() -> [ToggleButtonAnalyticsEvent] {
        return eventBuffer
    }
}

struct ToggleButton_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var toggleState = false
        @State private var diagnosticsEvents: [ToggleButtonAnalyticsEvent] = []
        
        // Use NullToggleButtonAnalyticsLogger with testMode enabled for preview diagnostics.
        let logger = NullToggleButtonAnalyticsLogger(testMode: true)
        
        var body: some View {
            VStack(spacing: 20) {
                ToggleButton(
                    isOn: $toggleState,
                    title: NSLocalizedString("Enable Feature", comment: "Preview toggle title"),
                    icon: "bolt.fill",
                    color: .green,
                    analyticsLogger: logger,
                    accessibilityLabel: NSLocalizedString("Enable Feature Toggle", comment: "Preview accessibility label"),
                    accessibilityHint: NSLocalizedString("Double tap to enable or disable the feature", comment: "Preview accessibility hint")
                )
                .onChange(of: toggleState) { _ in
                    // Simulate fetching recent events for diagnostics and audit review.
                    diagnosticsEvents = logger.recentEvents()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Diagnostics (Last Events):", comment: "Diagnostics header"))
                        .font(.headline)
                    if diagnosticsEvents.isEmpty {
                        Text(NSLocalizedString("No events logged yet.", comment: "Diagnostics empty state"))
                            .italic()
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(diagnosticsEvents) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timestamp: \(event.timestamp.formatted(date: .numeric, time: .standard))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("Event: \(event.event)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("New Value: \(event.newValue ? "ON" : "OFF")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Title: \(event.title)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Icon: \(event.icon ?? "nil")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("ToggleButton Preview with Accessibility and Diagnostics")
    }
}
