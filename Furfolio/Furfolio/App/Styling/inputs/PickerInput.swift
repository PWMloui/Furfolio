//
//  PickerInput.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//


/**
 PickerInput.swift
 Furfolio

 ## Overview
 PickerInput is a generic, extensible SwiftUI view for presenting a selection input (picker), with built-in support for analytics, diagnostics, accessibility, localization, compliance, and preview/testability.

 ## Architecture
 - **PickerInput**: A SwiftUI view that presents a picker interface driven by a generic selection binding and options. Supports injection of analytics logging, accessibility, and localization.
 - **PickerInputAnalyticsLogger**: Protocol for async/await-ready analytics event logging, with a testMode for preview/test/QA environments.
 - **NullPickerInputAnalyticsLogger**: A no-op/test logger for previews/tests.
 - **Event Buffer**: PickerInput maintains a capped buffer of the last 20 analytics events for diagnostics/admins.

 ## Extensibility
 - Analytics logger is injectable, allowing custom implementations (e.g., Trust Center hooks, audit trails).
 - Optionally extend PickerInput for custom option types or display.

 ## Analytics/Audit/Trust Center Hooks
 - All user interactions (selection changes, open events) are logged via the analytics logger.
 - Analytics events are localized and can be routed to compliance/audit/Trust Center systems by providing a custom logger.

 ## Diagnostics
 - Recent analytics events are accessible via a public API for admin/diagnostic review.

 ## Localization
 - All user-facing strings and log event strings are wrapped in NSLocalizedString with keys, values, and comments.

 ## Accessibility
 - Supports accessibilityLabel and accessibilityHint customization.
 - Ensures picker is accessible to assistive technologies.

 ## Compliance
 - Designed for auditability and privacy: analytics logging is pluggable, and can be disabled or redirected as required.

 ## Preview/Testability
 - NullPickerInputAnalyticsLogger enables safe use in previews/tests.
 - testMode property allows console-only logging for QA/previews.
 - PreviewProvider demonstrates accessibility, testMode, and diagnostics.
*/

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct PickerInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "PickerInput"
}

/// Protocol for async/await-ready analytics logging of PickerInput events with audit context.
/// - testMode: If true, logs only to the console (for QA/tests/previews).
@MainActor
public protocol PickerInputAnalyticsLogger: AnyObject {
    /// If true, logger only logs to console (QA/tests/previews).
    var testMode: Bool { get set }
    /// Log a PickerInput analytics event.
    func log(event: PickerInputAnalyticsEvent) async
    /// Fetch recent analytics events for diagnostics/admin.
    func recentEvents() -> [PickerInputAnalyticsEvent]
}

/// Analytics event for PickerInput interactions with audit and compliance fields.
public struct PickerInputAnalyticsEvent: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let eventType: String
    public let details: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Null logger for PickerInput analytics (for previews/tests).
public final class NullPickerInputAnalyticsLogger: PickerInputAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(event: PickerInputAnalyticsEvent) async {
        if testMode {
            print("[PickerInput][testMode] Event logged:")
            print("  eventType: \(event.eventType)")
            print("  details: \(event.details)")
            print("  role: \(event.role ?? "nil")")
            print("  staffID: \(event.staffID ?? "nil")")
            print("  context: \(event.context ?? "nil")")
            print("  escalate: \(event.escalate)")
        }
        // No-op for previews/tests.
    }
    public func recentEvents() -> [PickerInputAnalyticsEvent] {
        return []
    }
}

/// Default in-memory analytics logger with capped buffer for diagnostics and trust center/audit compliance.
public final class DefaultPickerInputAnalyticsLogger: PickerInputAnalyticsLogger, ObservableObject {
    public var testMode: Bool = false
    /// Capped buffer of recent events (max 20).
    @Published private(set) var recentEventsBuffer: [PickerInputAnalyticsEvent] = []
    private let maxBuffer = 20
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func log(event: PickerInputAnalyticsEvent) async {
        await MainActor.run {
            if testMode {
                print("[PickerInput][testMode] Event logged:")
                print("  eventType: \(event.eventType)")
                print("  details: \(event.details)")
                print("  role: \(event.role ?? "nil")")
                print("  staffID: \(event.staffID ?? "nil")")
                print("  context: \(event.context ?? "nil")")
                print("  escalate: \(event.escalate)")
            }
            recentEventsBuffer.append(event)
            if recentEventsBuffer.count > maxBuffer {
                recentEventsBuffer.removeFirst(recentEventsBuffer.count - maxBuffer)
            }
        }
    }
    /// Fetch the most recent analytics events (for diagnostics/admin).
    public func recentEvents() -> [PickerInputAnalyticsEvent] {
        return recentEventsBuffer
    }
}

/// PickerInput: A generic, analytics-enabled, accessible, localizable, and compliance-ready SwiftUI picker view.
/// - Parameters:
///   - selection: Bound selection (generic).
///   - title: Title for the picker (localized).
///   - options: Array of options to present (must be Hashable & Identifiable).
///   - analyticsLogger: Analytics logger (injectable; default: NullPickerInputAnalyticsLogger).
///   - accessibilityLabel: Accessibility label (localized).
///   - accessibilityHint: Accessibility hint (localized).
public struct PickerInput<Option: Hashable & Identifiable & CustomStringConvertible>: View {
    @Binding var selection: Option
    let title: String
    let options: [Option]
    @ObservedObject var analyticsLogger: DefaultPickerInputAnalyticsLogger
    let accessibilityLabel: String
    let accessibilityHint: String
    /// Internal: track picker open/selection for event logging.
    @State private var pickerIsPresented = false

    /// Initializes a PickerInput view.
    /// - Parameters:
    ///   - selection: Binding to the selected option.
    ///   - title: Localized title for the picker.
    ///   - options: Options to display.
    ///   - analyticsLogger: Analytics logger (default: NullPickerInputAnalyticsLogger).
    ///   - accessibilityLabel: Localized accessibility label.
    ///   - accessibilityHint: Localized accessibility hint.
    public init(
        selection: Binding<Option>,
        title: String,
        options: [Option],
        analyticsLogger: DefaultPickerInputAnalyticsLogger = DefaultPickerInputAnalyticsLogger(testMode: true),
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self._selection = selection
        self.title = title
        self.options = options
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Picker(selection: $selection, label: Text(title)) {
                ForEach(options) { option in
                    Text(String(describing: option))
                        .tag(option)
                }
            }
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityHint(Text(accessibilityHint))
            .onAppear {
                logOpenEvent()
            }
            .onChange(of: selection) { newValue in
                logSelectionChangeEvent(newValue)
            }
        }
        .padding(.vertical)
    }

    /// Log analytics event for picker open with audit/trust center fields.
    private func logOpenEvent() {
        Task {
            let eventType = NSLocalizedString("PickerInputOpened", value: "Picker Opened", comment: "Picker was opened")
            let details = NSLocalizedString("PickerInputOpenedDetails", value: "User viewed picker: \(title)", comment: "Picker open details with title")
            let escalate = eventType.lowercased().contains("critical") || details.lowercased().contains("danger") || details.lowercased().contains("delete") || details.lowercased().contains("critical")
            let event = PickerInputAnalyticsEvent(
                timestamp: Date(),
                eventType: eventType,
                details: details,
                role: PickerInputAuditContext.role,
                staffID: PickerInputAuditContext.staffID,
                context: PickerInputAuditContext.context,
                escalate: escalate
            )
            await analyticsLogger.log(event: event)
        }
    }

    /// Log analytics event for selection change with audit/trust center fields.
    private func logSelectionChangeEvent(_ newValue: Option) {
        Task {
            let eventType = NSLocalizedString("PickerInputSelectionChanged", value: "Selection Changed", comment: "Picker selection changed")
            let details = NSLocalizedString("PickerInputSelectionChangedDetails", value: "User selected: \(String(describing: newValue)) in \(title)", comment: "Picker selection changed details with selected value and title")
            let escalate = eventType.lowercased().contains("critical") || details.lowercased().contains("danger") || details.lowercased().contains("delete") || details.lowercased().contains("critical")
            let event = PickerInputAnalyticsEvent(
                timestamp: Date(),
                eventType: eventType,
                details: details,
                role: PickerInputAuditContext.role,
                staffID: PickerInputAuditContext.staffID,
                context: PickerInputAuditContext.context,
                escalate: escalate
            )
            await analyticsLogger.log(event: event)
        }
    }

    /// Fetch the last 20 analytics events for diagnostics/admin with audit context.
    public func recentAnalyticsEvents() -> [PickerInputAnalyticsEvent] {
        return analyticsLogger.recentEvents()
    }
}

#if DEBUG
/// Preview/test model for PickerInput.
fileprivate struct Fruit: Hashable, Identifiable, CustomStringConvertible {
    let id: Int
    let name: String
    var description: String { name }
}

struct PickerInput_Previews: PreviewProvider {
    @State static var selectedFruit = Fruit(id: 1, name: "Apple")
    static let fruits = [
        Fruit(id: 1, name: "Apple"),
        Fruit(id: 2, name: "Banana"),
        Fruit(id: 3, name: "Cherry")
    ]
    static let analyticsLogger = DefaultPickerInputAnalyticsLogger(testMode: true)

    static var previews: some View {
        VStack(spacing: 24) {
            Text("PickerInput Demo (Accessibility, TestMode, Diagnostics, Compliance)")
                .font(.title2)
            PickerInput(
                selection: $selectedFruit,
                title: NSLocalizedString("FruitPickerTitle", value: "Select a Fruit", comment: "Title for fruit picker"),
                options: fruits,
                analyticsLogger: analyticsLogger,
                accessibilityLabel: NSLocalizedString("FruitPickerAccessibilityLabel", value: "Fruit Picker", comment: "Accessibility label for fruit picker"),
                accessibilityHint: NSLocalizedString("FruitPickerAccessibilityHint", value: "Choose your favorite fruit", comment: "Accessibility hint for fruit picker")
            )
            .onAppear {
                // Simulate a selection for diagnostics
                Task {
                    selectedFruit = fruits[2]
                }
            }
            VStack(alignment: .leading) {
                Text("Recent Analytics Events (Diagnostic & Compliance)")
                    .font(.headline)
                ForEach(analyticsLogger.recentEvents().reversed()) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.timestamp, formatter: DateFormatter.shortTime): \(event.eventType) - \(event.details)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Role: \(event.role ?? "nil"), StaffID: \(event.staffID ?? "nil"), Context: \(event.context ?? "nil"), Escalate: \(event.escalate ? "Yes" : "No")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.top)
        }
        .padding()
        .environment(\.locale, .init(identifier: "en"))
        .previewDisplayName("PickerInput Accessibility/TestMode/Diagnostics/Compliance")
    }
}

fileprivate extension DateFormatter {
    static var shortTime: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }
}
#endif
