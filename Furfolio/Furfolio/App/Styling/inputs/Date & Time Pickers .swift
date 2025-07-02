//
//  Date & Time Pickers .swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 Date & Time Pickers.swift

 Architecture:
 This file implements a reusable SwiftUI DateTimePicker view with support for selecting dates, times, or both.
 It is designed to be extensible via dependency injection of an analytics logger and supports async/await logging.
 It includes audit context and enhanced logging to support trust center and compliance requirements.

 Extensibility:
 The analytics logger conforms to the DateTimePickerAnalyticsLogger protocol, allowing injection of
 custom analytics implementations. The view exposes parameters for accessibility and localization.

 Analytics / Audit / Trust Center Hooks:
 The DateTimePickerAnalyticsLogger protocol supports async logging of user interactions with detailed audit context.
 A capped buffer of the last 20 analytics events is maintained for diagnostics and audit purposes.
 The NullDateTimePickerAnalyticsLogger enables no-op logging for previews and tests.
 Audit context (role, staffID, context) can be set globally per session.

 Diagnostics:
 The view exposes a public API to fetch recent analytics events for admin or diagnostic use.
 Events are timestamped and stored in a thread-safe manner.

 Localization:
 All user-facing and log event strings are wrapped with NSLocalizedString for localization support.
 Localization keys, default values, and comments are provided.

 Accessibility:
 The view supports accessibility labels and hints as configurable parameters to enhance usability.

 Compliance:
 This component is designed with compliance in mind by supporting audit trails and accessibility.
 It can be extended to meet additional regulatory requirements as needed.

 Preview / Testability:
 A PreviewProvider demonstrates usage with accessibility labels, test mode logging, and diagnostics.
 The NullDateTimePickerAnalyticsLogger enables easy testing without external dependencies.
*/

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct DateTimePickerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DateTimePicker"
}

/// Protocol defining async analytics logging for DateTimePicker interactions with audit context.
/// Conforming types should implement the `logEvent` method to handle event logging.
/// The `testMode` property enables console-only logging for QA, tests, and previews.
public protocol DateTimePickerAnalyticsLogger {
    /// Indicates if the logger is operating in test mode (console-only logging).
    var testMode: Bool { get }

    /// Logs an analytics event asynchronously with detailed audit context.
    /// - Parameters:
    ///   - event: The event string to log.
    ///   - selectedDate: The date/time selected by the user.
    ///   - role: The role of the user (from audit context).
    ///   - staffID: The staff ID of the user (from audit context).
    ///   - context: The context of the event (from audit context).
    ///   - escalate: Flag indicating if the event should be escalated for compliance.
    func logEvent(
        _ event: String,
        selectedDate: Date,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /// Returns recent analytics events for diagnostics or audit.
    func recentEvents() -> [DateTimePickerAnalyticsEvent]
}

/// Represents a detailed analytics event for DateTimePicker interactions with audit context.
public struct DateTimePickerAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let selectedDate: Date
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A no-operation analytics logger for use in previews and tests.
/// Logs events to the console only if testMode is true, including all audit context fields.
/// Does not store any events.
public struct NullDateTimePickerAnalyticsLogger: DateTimePickerAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ event: String,
        selectedDate: Date,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
                [NullDateTimePickerAnalyticsLogger] Event: \(event)
                Selected Date: \(selectedDate)
                Role: \(role ?? "nil")
                StaffID: \(staffID ?? "nil")
                Context: \(context ?? "nil")
                Escalate: \(escalate)
                """)
        }
    }

    public func recentEvents() -> [DateTimePickerAnalyticsEvent] {
        []
    }
}

/// A SwiftUI view representing a date and/or time picker with analytics, audit, and accessibility support.
public struct DateTimePicker: View {
    /// The selection binding for the date/time value.
    @Binding public var selection: Date

    /// The minimum selectable date.
    public let minimumDate: Date?

    /// The maximum selectable date.
    public let maximumDate: Date?

    /// The mode of the picker: date, time, or dateAndTime.
    public let mode: UIDatePicker.Mode

    /// The injected analytics logger.
    private let analyticsLogger: DateTimePickerAnalyticsLogger

    /// Accessibility label for the picker.
    private let accessibilityLabel: String

    /// Accessibility hint for the picker.
    private let accessibilityHint: String

    /// Internal capped buffer for recent analytics events with audit context.
    @State private var recentEvents: [DateTimePickerAnalyticsEvent] = []

    /// Maximum number of events to keep in the buffer.
    private let maxEvents = 20

    /// Initializes a new DateTimePicker view.
    /// - Parameters:
    ///   - selection: Binding to the selected date/time.
    ///   - minimumDate: Optional minimum selectable date.
    ///   - maximumDate: Optional maximum selectable date.
    ///   - mode: Picker mode (date, time, or dateAndTime).
    ///   - analyticsLogger: Analytics logger (default is NullDateTimePickerAnalyticsLogger).
    ///   - accessibilityLabel: Accessibility label string.
    ///   - accessibilityHint: Accessibility hint string.
    public init(
        selection: Binding<Date>,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        mode: UIDatePicker.Mode = .dateAndTime,
        analyticsLogger: DateTimePickerAnalyticsLogger = NullDateTimePickerAnalyticsLogger(),
        accessibilityLabel: String = NSLocalizedString("DateTimePicker.Accessibility.Label", value: "Date and Time Picker", comment: "Accessibility label for date and time picker"),
        accessibilityHint: String = NSLocalizedString("DateTimePicker.Accessibility.Hint", value: "Select a date and time", comment: "Accessibility hint for date and time picker")
    ) {
        self._selection = selection
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.mode = mode
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        DatePicker(
            selection: $selection,
            in: (minimumDate ?? Date.distantPast)...(maximumDate ?? Date.distantFuture),
            displayedComponents: displayedComponents(for: mode)
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onChange(of: selection) { newValue in
            Task {
                await logSelectionChange(newValue)
            }
        }
    }

    /// Converts UIDatePicker.Mode to DatePicker.Components.
    /// - Parameter mode: The UIDatePicker.Mode.
    /// - Returns: The corresponding DatePicker.Components.
    private func displayedComponents(for mode: UIDatePicker.Mode) -> DatePicker.Components {
        switch mode {
        case .date:
            return .date
        case .time:
            return .hourAndMinute
        case .dateAndTime:
            return [.date, .hourAndMinute]
        @unknown default:
            return [.date, .hourAndMinute]
        }
    }

    /// Logs the selection change event asynchronously with audit context and updates the recent events buffer.
    /// - Parameter newValue: The new selected date/time.
    private func logSelectionChange(_ newValue: Date) async {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let eventKey = "DateTimePicker.Event.SelectionChanged"
        let eventValue = NSLocalizedString(eventKey, value: "User selected date/time: \(newValue)", comment: "Analytics event when user changes date/time selection")
        let eventString = "[\(timestamp)] \(eventValue)"

        // Determine if escalation is required
        var escalate = false
        let eventLower = eventString.lowercased()
        if eventLower.contains("critical") {
            escalate = true
        }
        if let minDate = minimumDate, newValue < minDate {
            escalate = true
        }
        if let maxDate = maximumDate, newValue > maxDate {
            escalate = true
        }

        let auditEvent = DateTimePickerAnalyticsEvent(
            timestamp: Date(),
            event: eventString,
            selectedDate: newValue,
            role: DateTimePickerAuditContext.role,
            staffID: DateTimePickerAuditContext.staffID,
            context: DateTimePickerAuditContext.context,
            escalate: escalate
        )

        await analyticsLogger.logEvent(
            eventString,
            selectedDate: newValue,
            role: DateTimePickerAuditContext.role,
            staffID: DateTimePickerAuditContext.staffID,
            context: DateTimePickerAuditContext.context,
            escalate: escalate
        )

        await MainActor.run {
            recentEvents.append(auditEvent)
            if recentEvents.count > maxEvents {
                recentEvents.removeFirst(recentEvents.count - maxEvents)
            }
        }
    }

    /// Public API to fetch recent analytics events for diagnostics, audit, or admin use.
    /// - Returns: Array of recent analytics event structs with audit context.
    public func fetchRecentEvents() -> [DateTimePickerAnalyticsEvent] {
        recentEvents
    }
}

#if DEBUG
struct DateTimePicker_Previews: PreviewProvider {
    struct AnalyticsLoggerMock: DateTimePickerAnalyticsLogger {
        let testMode = true

        func logEvent(
            _ event: String,
            selectedDate: Date,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            print("""
                [AnalyticsLoggerMock] Logged event: \(event)
                Selected Date: \(selectedDate)
                Role: \(role ?? "nil")
                StaffID: \(staffID ?? "nil")
                Context: \(context ?? "nil")
                Escalate: \(escalate)
                """)
        }

        func recentEvents() -> [DateTimePickerAnalyticsEvent] {
            []
        }
    }

    @State static private var previewDate = Date()

    static var previews: some View {
        VStack(spacing: 20) {
            Text("DateTimePicker Preview")
                .font(.headline)

            DateTimePicker(
                selection: $previewDate,
                minimumDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
                maximumDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
                mode: .dateAndTime,
                analyticsLogger: AnalyticsLoggerMock(),
                accessibilityLabel: NSLocalizedString("DateTimePicker.Preview.Accessibility.Label", value: "Preview Date and Time Picker", comment: "Accessibility label for preview"),
                accessibilityHint: NSLocalizedString("DateTimePicker.Preview.Accessibility.Hint", value: "Use this picker to select date and time in preview", comment: "Accessibility hint for preview")
            )
            .padding()

            Button("Show Recent Events") {
                let picker = DateTimePicker(
                    selection: $previewDate,
                    analyticsLogger: AnalyticsLoggerMock()
                )
                let events = picker.fetchRecentEvents()
                for event in events {
                    print("""
                        Event: \(event.event)
                        Timestamp: \(event.timestamp)
                        Selected Date: \(event.selectedDate)
                        Role: \(event.role ?? "nil")
                        StaffID: \(event.staffID ?? "nil")
                        Context: \(event.context ?? "nil")
                        Escalate: \(event.escalate)
                        """)
                }
                if events.isEmpty {
                    print("No recent events.")
                }
            }
        }
        .padding()
        .previewDisplayName("DateTimePicker with Analytics & Accessibility")
    }
}
#endif
