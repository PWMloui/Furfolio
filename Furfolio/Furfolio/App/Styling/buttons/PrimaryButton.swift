//  PrimaryButton: Architecture & Extensibility Overview
//  -----------------------------------------------------------------------------
//  This file defines a flexible, extensible SwiftUI PrimaryButton component for
//  Furfolio. It is designed for robust analytics/auditability, accessibility,
//  localization, compliance, diagnostics, and preview/testability.
//
//  • Architecture:
//    - PrimaryButton is a SwiftUI View with customizable title, icon, color,
//      accessibility, and analytics logger.
//    - Analytics event logging is injected via a protocol (PrimaryButtonAnalyticsLogger).
//    - Analytics events are buffered (last 20) for diagnostics/auditing.
//
//  • Extensibility:
//    - Analytics logger can be swapped for Trust Center, audit, or custom loggers.
//    - Parameters are exposed for future compliance, accessibility, and
//      internationalization extensions.
//
//  • Analytics/Audit/Trust Center Hooks:
//    - All button taps are logged with event metadata (timestamp, label, role, staffID, context, escalate).
//    - Analytics logger protocol supports async/await for future integration
//      with remote or Trust Center endpoints.
//    - testMode property allows for non-persistent, console-only logging in
//      QA/tests/previews.
//
//  • Diagnostics:
//    - A buffer of the last 20 analytics events is kept for admin/diagnostics.
//    - Public API to fetch recent events for troubleshooting/compliance.
//
//  • Localization:
//    - All user-facing and log strings use NSLocalizedString with keys, values,
//      and developer comments for translators.
//
//  • Accessibility:
//    - Customizable accessibilityLabel and hint.
//    - VoiceOver-friendly by default.
//
//  • Compliance:
//    - Designed for future privacy, audit, and accessibility compliance.
//
//  • Preview/Testability:
//    - Includes Null logger for tests/previews.
//    - PreviewProvider demonstrates accessibility, testMode, and diagnostics.
//
//  ─────────────────────────────────────────────────────────────────────────────

import SwiftUI
import Combine

// MARK: - Audit Context (set at login/session)
public struct PrimaryButtonAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "PrimaryButton"
}

/// Protocol for PrimaryButton analytics logging with audit/trust center support.
/// Supports async/await, testMode for console-only logging, and diagnostics.
public protocol PrimaryButtonAnalyticsLogger: AnyObject {
    /// If true, analytics are only logged to the console (not persisted/sent).
    var testMode: Bool { get set }
    /// Log a button tap event asynchronously with audit fields.
    func logButtonTap(title: String, timestamp: Date, metadata: [String: String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    /// Fetch the most recent analytics events (up to the buffer cap) with full audit fields.
    func recentEvents() -> [PrimaryButtonAnalyticsEvent]
}

/// An analytics event for PrimaryButton with audit/trust center fields.
public struct PrimaryButtonAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let title: String
    public let metadata: [String: String]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Null logger for tests/previews: does nothing, but conforms to protocol.
public final class NullPrimaryButtonAnalyticsLogger: PrimaryButtonAnalyticsLogger {
    public var testMode: Bool = true
    private var buffer: [PrimaryButtonAnalyticsEvent] = []
    public init() {}
    public func logButtonTap(title: String, timestamp: Date, metadata: [String: String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        // No-op for preview/testing.
    }
    public func recentEvents() -> [PrimaryButtonAnalyticsEvent] {
        []
    }
}

/// Default in-memory analytics logger with capped buffer, audit fields, and diagnostics API.
public final class InMemoryPrimaryButtonAnalyticsLogger: PrimaryButtonAnalyticsLogger, ObservableObject {
    public var testMode: Bool = false
    @Published private(set) var buffer: [PrimaryButtonAnalyticsEvent] = []
    private let bufferLimit = 20
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func logButtonTap(title: String, timestamp: Date, metadata: [String: String]? = nil, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let event = PrimaryButtonAnalyticsEvent(timestamp: timestamp, title: title, metadata: metadata, role: role, staffID: staffID, context: context, escalate: escalate)
        DispatchQueue.main.async {
            self.buffer.append(event)
            if self.buffer.count > self.bufferLimit {
                self.buffer.removeFirst(self.buffer.count - self.bufferLimit)
            }
            if self.testMode {
                print(NSLocalizedString("PrimaryButton_ConsoleLog",
                                       value: "[TestMode] Button tapped: \(title) at \(timestamp), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)",
                                       comment: "Console log for PrimaryButton in test mode"))
            }
        }
    }
    public func recentEvents() -> [PrimaryButtonAnalyticsEvent] {
        buffer
    }
}

/// A SwiftUI PrimaryButton with analytics, accessibility, localization, and audit compliance.
public struct PrimaryButton: View {
    /// Button title (localization-ready key).
    public let titleKey: String
    /// Button icon (optional, system image name).
    public let icon: String?
    /// Button color.
    public let color: Color
    /// Accessibility label (for VoiceOver, localization-ready key).
    public let accessibilityLabelKey: String?
    /// Accessibility hint (for VoiceOver, localization-ready key).
    public let accessibilityHintKey: String?
    /// Action to perform on tap.
    public let action: () -> Void
    /// Analytics logger (injected for audit/diagnostics).
    public weak var analyticsLogger: PrimaryButtonAnalyticsLogger?
    /// Additional metadata for analytics.
    public let analyticsMetadata: [String: String]?
    
    /// Initialize a PrimaryButton.
    /// - Parameters:
    ///   - titleKey: Localization key for the button title.
    ///   - icon: Optional SF Symbol name.
    ///   - color: Button background color.
    ///   - accessibilityLabelKey: Localization key for accessibility label.
    ///   - accessibilityHintKey: Localization key for accessibility hint.
    ///   - analyticsLogger: Analytics logger (default: nil).
    ///   - analyticsMetadata: Metadata for analytics events.
    ///   - action: Action closure.
    public init(
        titleKey: String,
        icon: String? = nil,
        color: Color = .accentColor,
        accessibilityLabelKey: String? = nil,
        accessibilityHintKey: String? = nil,
        analyticsLogger: PrimaryButtonAnalyticsLogger? = nil,
        analyticsMetadata: [String: String]? = nil,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.icon = icon
        self.color = color
        self.accessibilityLabelKey = accessibilityLabelKey
        self.accessibilityHintKey = accessibilityHintKey
        self.analyticsLogger = analyticsLogger
        self.analyticsMetadata = analyticsMetadata
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            Task {
                let titleLocalized = NSLocalizedString(titleKey, value: titleKey, comment: "PrimaryButton title")
                let lowercasedTitle = titleLocalized.lowercased()
                let lowercasedIcon = icon?.lowercased() ?? ""
                let escalate = lowercasedTitle.contains("delete") || lowercasedTitle.contains("danger") || lowercasedTitle.contains("critical") || lowercasedIcon.contains("delete") || lowercasedIcon.contains("danger") || lowercasedIcon.contains("critical")
                await analyticsLogger?.logButtonTap(
                    title: titleLocalized,
                    timestamp: Date(),
                    metadata: analyticsMetadata,
                    role: PrimaryButtonAuditContext.role,
                    staffID: PrimaryButtonAuditContext.staffID,
                    context: PrimaryButtonAuditContext.context,
                    escalate: escalate
                )
            }
            action()
        }) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .imageScale(.medium)
                }
                Text(NSLocalizedString(titleKey, value: titleKey, comment: "PrimaryButton title"))
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .accessibilityLabel(
            accessibilityLabelKey.map { NSLocalizedString($0, value: $0, comment: "PrimaryButton accessibilityLabel") }
        )
        .accessibilityHint(
            accessibilityHintKey.map { NSLocalizedString($0, value: $0, comment: "PrimaryButton accessibilityHint") }
        )
    }
}

#if DEBUG
/// PreviewProvider demonstrating accessibility, testMode, diagnostics, and audit fields.
struct PrimaryButton_Previews: PreviewProvider {
    static class DiagnosticsDemo: ObservableObject {
        @Published var recentEvents: [PrimaryButtonAnalyticsEvent] = []
        let logger = InMemoryPrimaryButtonAnalyticsLogger(testMode: true)
        init() {
            // Preload with some fake events for diagnostics preview including audit fields.
            Task {
                for i in 1...3 {
                    await logger.logButtonTap(
                        title: NSLocalizedString("Preview_Button_Title", value: "Preview \(i)", comment: "Preview button title"),
                        timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                        metadata: ["preview": "true"],
                        role: "tester",
                        staffID: "staff\(i)",
                        context: "previewContext",
                        escalate: false
                    )
                }
                DispatchQueue.main.async {
                    self.recentEvents = self.logger.recentEvents()
                }
            }
        }
    }
    
    static var previews: some View {
        let diagnostics = DiagnosticsDemo()
        VStack(spacing: 20) {
            PrimaryButton(
                titleKey: "PrimaryButton_Save",
                icon: "tray.and.arrow.down",
                color: .blue,
                accessibilityLabelKey: "PrimaryButton_Save_A11yLabel",
                accessibilityHintKey: "PrimaryButton_Save_A11yHint",
                analyticsLogger: diagnostics.logger,
                analyticsMetadata: ["context": "preview"]
            ) {
                // Simulate save action
            }
            .previewDisplayName("Save Button (Accessibility/TestMode)")

            PrimaryButton(
                titleKey: "PrimaryButton_Delete",
                icon: "trash",
                color: .red,
                accessibilityLabelKey: "PrimaryButton_Delete_A11yLabel",
                accessibilityHintKey: "PrimaryButton_Delete_A11yHint",
                analyticsLogger: NullPrimaryButtonAnalyticsLogger(),
                analyticsMetadata: ["context": "preview"]
            ) {
                // Simulate delete action
            }
            .previewDisplayName("Delete Button (Null Logger)")
            
            // Diagnostics: Show recent analytics events with full audit fields
            VStack(alignment: .leading) {
                Text(NSLocalizedString("PrimaryButton_RecentEvents", value: "Recent Events", comment: "Diagnostics recent events title"))
                    .font(.headline)
                ForEach(diagnostics.logger.recentEvents()) { event in
                    Text(
                        String(
                            format: NSLocalizedString("PrimaryButton_EventFormat",
                                                      value: "%@ at %@ (role: %@, staffID: %@, context: %@, escalate: %@)",
                                                      comment: "Event format: title at timestamp with audit fields"),
                            event.title,
                            DateFormatter.localizedString(from: event.timestamp, dateStyle: .short, timeStyle: .medium),
                            event.role ?? "nil",
                            event.staffID ?? "nil",
                            event.context ?? "nil",
                            event.escalate ? "true" : "false"
                        )
                    )
                    .font(.caption)
                }
            }
            .padding(.top)
        }
        .padding()
        .environment(\.locale, .init(identifier: "en"))
    }
}
#endif
