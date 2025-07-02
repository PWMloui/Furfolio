//
//  CheckboxInput.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct CheckboxInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "CheckboxInput"
}

/**
 CheckboxInput Architecture and Extensibility

 CheckboxInput is a reusable SwiftUI component designed to represent a checkbox input control with customizable title and optional icon. It is built with extensibility, localization, accessibility, analytics, diagnostics, and compliance in mind to cater to a wide range of application needs.

 - Architecture:
    The component is a SwiftUI View with a binding to a boolean state representing the checkbox's checked state. It supports an optional icon and localized strings for title, accessibility labels, and hints.

 - Extensibility:
    Analytics logging is abstracted via the `CheckboxInputAnalyticsLogger` protocol, allowing injection of different logging implementations (e.g., production, testing, preview).

 - Analytics / Audit / Trust Center Hooks:
    The component logs user interactions asynchronously using the injected analytics logger. It maintains a capped buffer of the last 20 events for diagnostics and audit purposes.

 - Diagnostics:
    A public API exposes recent analytics events for administrative or diagnostic inspection.

 - Localization:
    All user-facing strings and analytics event messages are wrapped in `NSLocalizedString` with explicit keys and comments to support localization workflows.

 - Accessibility:
    Accessibility labels and hints are customizable and localized to ensure compliance with accessibility standards.

 - Compliance:
    Designed to support audit trails and trust center requirements via analytics event logging and diagnostics.

 - Preview/Testability:
    Includes a `NullCheckboxInputAnalyticsLogger` for previews and tests that logs only to console with a `testMode` flag. PreviewProvider demonstrates accessibility, diagnostics, and testMode usage.

 Future maintainers can extend analytics logging by implementing `CheckboxInputAnalyticsLogger` and inject their implementation. Localization keys should be added to Localizable.strings files accordingly.
 */

/**
 Protocol defining asynchronous analytics logging for CheckboxInput events, supporting Trust Center/Compliance/Audit context.

 Conforming types should implement async logging of events, provide a `testMode` flag indicating if the logger is in QA/test/preview mode, and support fetching recent audit events.
 */
public protocol CheckboxInputAnalyticsLogger {
    /// Indicates if the logger is running in test/preview mode (console-only logging).
    var testMode: Bool { get }
    func logEvent(
        _ event: String,
        newValue: Bool,
        title: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    func recentEvents() -> [CheckboxInputAnalyticsEvent]
}

/// Struct representing a single analytics/audit event for trust center/compliance.
public struct CheckboxInputAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let newValue: Bool
    public let title: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/**
 A no-op analytics logger for testing, previews, and QA.
 Logs events only to the console and sets `testMode` to true. Returns no stored events.
 */
public struct NullCheckboxInputAnalyticsLogger: CheckboxInputAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func logEvent(
        _ event: String,
        newValue: Bool,
        title: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("""
CheckboxInput [TestMode] Event Logged:
  event: \(event)
  newValue: \(newValue)
  title: \(title)
  role: \(role ?? "nil")
  staffID: \(staffID ?? "nil")
  context: \(context ?? "nil")
  escalate: \(escalate)
""")
        }
    }

    public func recentEvents() -> [CheckboxInputAnalyticsEvent] {
        return []
    }
}

/**
 A SwiftUI checkbox input view with analytics, localization, accessibility, diagnostics, and trust center/compliance audit context support.

 - Parameters:
    - isChecked: Binding to the checkbox state.
    - title: Localized title string.
    - icon: Optional SwiftUI Image to display alongside the title.
    - analyticsLogger: Injected analytics logger conforming to CheckboxInputAnalyticsLogger.
    - accessibilityLabel: Localized accessibility label for the checkbox.
    - accessibilityHint: Localized accessibility hint describing the checkbox action.
 */
public struct CheckboxInput: View {
    @Binding public var isChecked: Bool
    public let title: String
    public let icon: Image?
    public let analyticsLogger: CheckboxInputAnalyticsLogger
    public let accessibilityLabel: String
    public let accessibilityHint: String

    /// Internal capped buffer of last 20 analytics events for diagnostics/audit (trust center).
    @State private var recentEvents: [CheckboxInputAnalyticsEvent] = []

    /// Maximum number of events to keep in the buffer.
    private let maxEventBufferSize = 20

    /**
     Initialize a CheckboxInput view.
     */
    public init(
        isChecked: Binding<Bool>,
        title: String,
        icon: Image? = nil,
        analyticsLogger: CheckboxInputAnalyticsLogger = NullCheckboxInputAnalyticsLogger(),
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self._isChecked = isChecked
        self.title = title
        self.icon = icon
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        Button(action: toggle) {
            HStack {
                if let icon = icon {
                    icon
                        .accessibilityHidden(true)
                }
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .accessibilityHidden(true)
                Text(title)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isChecked ?
            NSLocalizedString("CheckboxInput.Accessibility.Value.Checked", value: "Checked", comment: "Accessibility value when checkbox is checked") :
            NSLocalizedString("CheckboxInput.Accessibility.Value.Unchecked", value: "Unchecked", comment: "Accessibility value when checkbox is unchecked"))
    }

    /// Toggle the checkbox state and log the event asynchronously, including audit/trust center fields.
    private func toggle() {
        isChecked.toggle()
        let event = NSLocalizedString(
            "CheckboxInput.Analytics.Event.Toggle",
            value: "Checkbox toggled to \(isChecked ? "checked" : "unchecked")",
            comment: "Analytics event string when checkbox is toggled"
        )
        // Trust center/compliance: escalate if title contains critical language
        let lowerTitle = title.lowercased()
        let escalate = lowerTitle.contains("delete") || lowerTitle.contains("danger") || lowerTitle.contains("critical")
        let auditEvent = CheckboxInputAnalyticsEvent(
            timestamp: Date(),
            event: event,
            newValue: isChecked,
            title: self.title,
            role: CheckboxInputAuditContext.role,
            staffID: CheckboxInputAuditContext.staffID,
            context: CheckboxInputAuditContext.context,
            escalate: escalate
        )
        Task {
            await logEvent(auditEvent)
        }
    }

    /// Append event to buffer and log via analyticsLogger, including all audit fields.
    private func logEvent(_ event: CheckboxInputAnalyticsEvent) async {
        await MainActor.run {
            if recentEvents.count >= maxEventBufferSize {
                recentEvents.removeFirst()
            }
            recentEvents.append(event)
        }
        await analyticsLogger.logEvent(
            event.event,
            newValue: event.newValue,
            title: event.title,
            role: event.role,
            staffID: event.staffID,
            context: event.context,
            escalate: event.escalate
        )
    }

    /**
     Fetch recent analytics/audit events for diagnostics or admin review.

     - Returns: Array of last logged audit events, capped at 20.
     */
    public func fetchRecentEvents() -> [CheckboxInputAnalyticsEvent] {
        recentEvents
    }
}

struct CheckboxInput_Previews: PreviewProvider {
    @State static var checked = false

    static var previews: some View {
        VStack(spacing: 20) {
            CheckboxInput(
                isChecked: $checked,
                title: NSLocalizedString("CheckboxInput.Preview.Title", value: "Accept Terms and Conditions", comment: "Preview checkbox title"),
                icon: Image(systemName: "doc.text"),
                analyticsLogger: NullCheckboxInputAnalyticsLogger(),
                accessibilityLabel: NSLocalizedString("CheckboxInput.Preview.Accessibility.Label", value: "Accept terms and conditions checkbox", comment: "Preview accessibility label"),
                accessibilityHint: NSLocalizedString("CheckboxInput.Preview.Accessibility.Hint", value: "Toggles acceptance of terms and conditions", comment: "Preview accessibility hint")
            )
            .padding()

            Button(action: {
                // Demonstrate fetching recent audit events (all fields)
                let events = CheckboxInput(
                    isChecked: $checked,
                    title: "",
                    accessibilityLabel: "",
                    accessibilityHint: ""
                ).fetchRecentEvents()
                print("Recent Analytics Events:")
                for event in events {
                    print("""
  id: \(event.id)
  timestamp: \(event.timestamp)
  event: \(event.event)
  newValue: \(event.newValue)
  title: \(event.title)
  role: \(event.role ?? "nil")
  staffID: \(event.staffID ?? "nil")
  context: \(event.context ?? "nil")
  escalate: \(event.escalate)
""")
                }
            }) {
                Text(NSLocalizedString("CheckboxInput.Preview.ShowEventsButton", value: "Show Recent Events", comment: "Button title to show recent analytics events"))
            }
        }
        .padding()
        .previewDisplayName("CheckboxInput Preview with Accessibility and Diagnostics")
    }
}
