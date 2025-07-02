//
//  SecondaryButton.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//
//
//  ──────────────────────────────────────────────────────────────────────────────
//  SecondaryButton Architecture & Maintainer Guide
//  ──────────────────────────────────────────────────────────────────────────────
//  SecondaryButton is a customizable, extensible SwiftUI button component
//  designed for secondary actions in the Furfolio app. It is architected for:
//
//  • Extensibility: Analytics logger is injected via protocol; icon, color, and
//    accessibility options are customizable. All user-facing strings are
//    localization-ready, and the view is preview/test friendly.
//  • Analytics/Audit/Trust Center: All button taps are logged via an injected
//    analytics logger conforming to SecondaryButtonAnalyticsLogger, supporting
//    async/await and a capped buffer for diagnostics/auditing. testMode enables
//    console-only logging for QA/previews. Audit context and escalation flags
//    are included for compliance and trust center reporting.
//  • Diagnostics: Recent analytics events (last 20) are buffered and retrievable
//    for admin/diagnostics/Trust Center review, including full audit metadata.
//  • Localization: All user-facing/logged strings use NSLocalizedString with
//    keys, values, and comments for easy extraction and translation.
//  • Accessibility: Customizable accessibility labels/hints, VoiceOver-friendly.
//  • Compliance: Designed for auditability, transparency, and future expansion
//    (e.g., Trust Center, compliance reporting).
//  • Preview/Testability: Null logger and testMode make it safe for previews/
//    tests; PreviewProvider demonstrates accessibility and diagnostics.
//
//  Future maintainers: See doc-comments on types/APIs for details. To extend
//  analytics, subclass or swap in a new logger. To localize, update the
//  NSLocalizedString keys/values. For diagnostics, use the public API to fetch
//  recent events. For accessibility, override labels/hints as needed.
//
//  ──────────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SecondaryButtonAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SecondaryButton"
}

/// Protocol for analytics logging of SecondaryButton events with audit metadata.
/// - Conforms to: `Sendable`
/// - Async/await-ready for modern concurrency.
/// - `testMode`: If true, logs to console only (for previews/tests).
/// - Extend for integration with real analytics backends.
/// - Includes audit fields for Trust Center and compliance.
public protocol SecondaryButtonAnalyticsLogger: Sendable {
    /// If true, analytics events are logged to the console only (for QA/previews/tests).
    var testMode: Bool { get }
    /// Logs a button tap event with full audit metadata.
    /// - Parameters:
    ///   - title: Button title (localized).
    ///   - icon: Optional icon name.
    ///   - timestamp: Date/time of tap.
    ///   - metadata: Optional additional metadata dictionary.
    ///   - role: Optional user role for audit.
    ///   - staffID: Optional staff identifier for audit.
    ///   - context: Optional context for diagnostics.
    ///   - escalate: Flag indicating if the event should be escalated for compliance.
    func logButtonTap(title: String, icon: String?, timestamp: Date, metadata: [String: String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    /// Fetch the last N analytics events with full audit fields (for diagnostics/auditing).
    func recentEvents() -> [SecondaryButtonAnalyticsEvent]
}

/// Null logger for previews/tests: does nothing except optionally print to console with all audit fields.
public struct NullSecondaryButtonAnalyticsLogger: SecondaryButtonAnalyticsLogger {
    public let testMode: Bool
    private var _events: [SecondaryButtonAnalyticsEvent] = []
    public init(testMode: Bool = true) { self.testMode = testMode }
    public func logButtonTap(title: String, icon: String?, timestamp: Date, metadata: [String: String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("[SecondaryButton] (testMode) \(title) tapped at \(timestamp)")
            print("Icon: \(icon ?? "nil"), Metadata: \(metadata ?? [:]), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
        // No-op: does not store events.
    }
    public func recentEvents() -> [SecondaryButtonAnalyticsEvent] { [] }
}

/// Analytics event data for diagnostics/audit/Trust Center with full audit fields.
public struct SecondaryButtonAnalyticsEvent: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let icon: String?
    public let timestamp: Date
    public let metadata: [String: String]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Default analytics logger with capped buffer for recent events (last 20), including audit metadata.
public actor DefaultSecondaryButtonAnalyticsLogger: SecondaryButtonAnalyticsLogger {
    public let testMode: Bool
    private var events: [SecondaryButtonAnalyticsEvent] = []
    private let maxBuffer = 20
    public init(testMode: Bool = false) { self.testMode = testMode }
    public func logButtonTap(title: String, icon: String?, timestamp: Date, metadata: [String: String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let event = SecondaryButtonAnalyticsEvent(title: title, icon: icon, timestamp: timestamp, metadata: metadata, role: role, staffID: staffID, context: context, escalate: escalate)
        if testMode {
            print("[SecondaryButton] (testMode) \(title) tapped at \(timestamp)")
            print("Icon: \(icon ?? "nil"), Metadata: \(metadata ?? [:]), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
        events.append(event)
        if events.count > maxBuffer {
            events.removeFirst(events.count - maxBuffer)
        }
    }
    public func recentEvents() -> [SecondaryButtonAnalyticsEvent] {
        return events
    }
}

/// SecondaryButton: A SwiftUI button for secondary actions, with analytics, accessibility, and diagnostics hooks, including audit and escalation support.
public struct SecondaryButton: View {
    /// Localized title for the button.
    public let title: String
    /// Optional SF Symbol or asset name for the icon.
    public let icon: String?
    /// Optional color for the button (defaults to secondary color).
    public let color: Color
    /// Action to perform on tap.
    public let action: () -> Void
    /// Analytics logger (injected, default: Null logger in previews).
    public let analyticsLogger: SecondaryButtonAnalyticsLogger
    /// Optional accessibility label (localized).
    public let accessibilityLabel: String?
    /// Optional accessibility hint (localized).
    public let accessibilityHint: String?
    /// Optional context string for diagnostics/auditing (not shown to users).
    public let context: String?
    
    /// Creates a new SecondaryButton.
    /// - Parameters:
    ///   - title: Localized button title.
    ///   - icon: Optional icon name.
    ///   - color: Button color.
    ///   - analyticsLogger: Analytics logger (injected).
    ///   - accessibilityLabel: Custom accessibility label (optional).
    ///   - accessibilityHint: Custom accessibility hint (optional).
    ///   - context: Optional diagnostic context.
    ///   - action: Action to perform on tap.
    public init(
        title: String,
        icon: String? = nil,
        color: Color = .secondary,
        analyticsLogger: SecondaryButtonAnalyticsLogger = NullSecondaryButtonAnalyticsLogger(),
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        context: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.analyticsLogger = analyticsLogger
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.context = context
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            Task {
                let localizedTitle = NSLocalizedString("SecondaryButton.title.\(title)", value: title, comment: "SecondaryButton title: \(title)")
                let lowerTitle = localizedTitle.lowercased()
                let lowerIcon = icon?.lowercased()
                let lowerAccessibilityLabel = accessibilityLabel?.lowercased()
                let keywords = ["delete", "danger", "critical"]
                let shouldEscalate = keywords.contains(where: { lowerTitle.contains($0) || lowerIcon?.contains($0) == true || lowerAccessibilityLabel?.contains($0) == true })
                await analyticsLogger.logButtonTap(
                    title: localizedTitle,
                    icon: icon,
                    timestamp: Date(),
                    metadata: ["source": "SecondaryButton"],
                    role: SecondaryButtonAuditContext.role,
                    staffID: SecondaryButtonAuditContext.staffID,
                    context: SecondaryButtonAuditContext.context,
                    escalate: shouldEscalate
                )
            }
            action()
        }) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .imageScale(.medium)
                }
                Text(
                    NSLocalizedString("SecondaryButton.title.\(title)", value: title, comment: "SecondaryButton title: \(title)")
                )
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 1)
            )
        }
        .accessibilityLabel(
            accessibilityLabel ??
            NSLocalizedString("SecondaryButton.accessibilityLabel.\(title)", value: title, comment: "Accessibility label for SecondaryButton: \(title)")
        )
        .accessibilityHint(
            accessibilityHint ??
            NSLocalizedString("SecondaryButton.accessibilityHint.\(title)", value: "Double tap to \(title.lowercased())", comment: "Accessibility hint for SecondaryButton: \(title)")
        )
    }
}

#if DEBUG
/// PREVIEW: Demonstrates accessibility, testMode, and diagnostics in action with full audit metadata.
struct SecondaryButton_Previews: PreviewProvider {
    /// Test logger with in-memory diagnostics including audit fields.
    actor PreviewLogger: SecondaryButtonAnalyticsLogger {
        var testMode: Bool = true
        private var events: [SecondaryButtonAnalyticsEvent] = []
        func logButtonTap(title: String, icon: String?, timestamp: Date, metadata: [String : String]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[PreviewLogger] \(title) tapped at \(timestamp)")
            print("Icon: \(icon ?? "nil"), Metadata: \(metadata ?? [:]), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
            events.append(SecondaryButtonAnalyticsEvent(title: title, icon: icon, timestamp: timestamp, metadata: metadata, role: role, staffID: staffID, context: context, escalate: escalate))
            if events.count > 20 { events.removeFirst(events.count - 20) }
        }
        func recentEvents() -> [SecondaryButtonAnalyticsEvent] { events }
    }
    struct DiagnosticsView: View {
        @State private var events: [SecondaryButtonAnalyticsEvent] = []
        let logger: PreviewLogger
        var body: some View {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("SecondaryButton.preview.diagnosticsTitle", value: "Recent Analytics Events", comment: "Diagnostics section title"))
                    .font(.headline)
                List(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(event.title) (\(event.icon ?? "-"))")
                            .font(.subheadline)
                        Text(event.timestamp, style: .time)
                            .font(.caption)
                        if let metadata = event.metadata {
                            Text("Metadata: \(metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
                                .font(.caption2)
                        }
                        Text("Role: \(event.role ?? "-")")
                            .font(.caption2)
                        Text("StaffID: \(event.staffID ?? "-")")
                            .font(.caption2)
                        Text("Context: \(event.context ?? "-")")
                            .font(.caption2)
                        Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            .font(.caption2)
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 250)
                Button(NSLocalizedString("SecondaryButton.preview.refresh", value: "Refresh Diagnostics", comment: "Button to refresh diagnostics events")) {
                    Task {
                        events = await logger.recentEvents()
                    }
                }
            }
            .padding()
        }
    }
    static let previewLogger = PreviewLogger()
    static var previews: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("SecondaryButton.preview.header", value: "SecondaryButton Preview", comment: "Preview header"))
                .font(.title)
            SecondaryButton(
                title: NSLocalizedString("SecondaryButton.preview.save", value: "Save", comment: "Preview button title"),
                icon: "tray.and.arrow.down",
                color: .blue,
                analyticsLogger: previewLogger,
                accessibilityLabel: NSLocalizedString("SecondaryButton.preview.save.accessibilityLabel", value: "Save changes", comment: "Accessibility label for Save button"),
                accessibilityHint: NSLocalizedString("SecondaryButton.preview.save.accessibilityHint", value: "Double tap to save your changes", comment: "Accessibility hint for Save button"),
                context: "Preview - Save"
            ) {
                print("[Preview] Save tapped")
            }
            SecondaryButton(
                title: NSLocalizedString("SecondaryButton.preview.cancel", value: "Cancel", comment: "Preview button title"),
                icon: "xmark.circle",
                color: .red,
                analyticsLogger: previewLogger,
                accessibilityLabel: NSLocalizedString("SecondaryButton.preview.cancel.accessibilityLabel", value: "Cancel operation", comment: "Accessibility label for Cancel button"),
                accessibilityHint: NSLocalizedString("SecondaryButton.preview.cancel.accessibilityHint", value: "Double tap to cancel and discard changes", comment: "Accessibility hint for Cancel button"),
                context: "Preview - Cancel"
            ) {
                print("[Preview] Cancel tapped")
            }
            DiagnosticsView(logger: previewLogger)
        }
        .padding()
        .previewDisplayName(NSLocalizedString("SecondaryButton.preview.displayName", value: "SecondaryButton – Accessibility & Diagnostics", comment: "Preview display name"))
    }
}
#endif
