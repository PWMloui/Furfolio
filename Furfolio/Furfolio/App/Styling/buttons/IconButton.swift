/**
 # IconButton
 
 ## Overview
 `IconButton` is a reusable, extensible SwiftUI component for displaying tappable icons with accessibility, analytics, diagnostics, localization, and audit/trust center compliance support.
 
 ## Architecture
 - **Composable SwiftUI View**: Accepts icon (Image), action, color, size, and accessibility parameters.
 - **Analytics & Audit**: Analytics events are sent via an injected `IconButtonAnalyticsLogger` protocol, supporting async/await for future extensibility (e.g., network logging), with audit context fields for role, staffID, and context, and escalation flags for compliance.
 - **Diagnostics**: A capped buffer (last 20 events) is maintained for admin/diagnostic access, including audit fields.
 - **Localization**: All user-facing and log strings use `NSLocalizedString` with keys, values, and comments for easy localization.
 - **Accessibility**: Full support for VoiceOver via `accessibilityLabel`, `accessibilityHint`, and traits.
 - **Compliance**: Designed for auditability and Trust Center integration, with hooks for external analytics or compliance modules.
 - **Preview/Testability**: Test/preview mode disables analytics side effects and enables console logging for QA or diagnostics.
 
 ## Extensibility
 - Implement custom analytics loggers by conforming to `IconButtonAnalyticsLogger`.
 - Swap loggers for production, QA, or preview via dependency injection.
 - Easily adapt for new icon/image sources, themes, or compliance requirements.
 
 ## Diagnostics
 - Fetch recent analytics events (last 20) including audit fields for admin/diagnostic panels.
 
 ## Localization
 - All UI and log strings are localization-ready with explicit keys and comments.
 
 ## Accessibility
 - Designed for full accessibility compliance; all interactive elements have labels and hints.
 
 ## Audit Context
 - Audit context (role, staffID, context) is set at login/session and included in all analytics events.
 - Escalation flag is set for critical events (e.g., delete, critical, danger).
 
 ## Example Usage
 ```swift
 IconButton(
     icon: Image(systemName: "star"),
     action: { print("Tapped") },
     accessibilityLabel: NSLocalizedString("icon_button.star.label", value: "Favorite", comment: "Accessibility label for star/favorite button"),
     analyticsLogger: MyAnalyticsLogger()
 )
 ```
 */

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct IconButtonAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "IconButton"
}

/// Protocol for analytics logging for IconButton events, supporting async/await and audit compliance.
/// Implementations may log to network, file, or only console (testMode).
public protocol IconButtonAnalyticsLogger: AnyObject {
    /// If true, analytics events are only logged to the console (for QA, previews, tests).
    var testMode: Bool { get set }
    
    /// Log an analytics event with audit context, asynchronously.
    /// - Parameters:
    ///   - event: The event name.
    ///   - metadata: Optional metadata dictionary.
    ///   - role: Audit role (e.g., user role).
    ///   - staffID: Audit staff ID.
    ///   - context: Audit context string.
    ///   - escalate: Whether this event should be escalated for compliance.
    func log(event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    
    /// Retrieve the most recent analytics events (max 20), including audit fields.
    func recentEvents() -> [IconButtonAnalyticsEvent]
}

/// Null analytics logger for previews/tests: no-ops except in testMode, where it prints to the console with audit info.
public final class NullIconButtonAnalyticsLogger: IconButtonAnalyticsLogger {
    public var testMode: Bool = false
    private var buffer: [IconButtonAnalyticsEvent] = []
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    public func log(event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let evt = IconButtonAnalyticsEvent(
            timestamp: Date(),
            event: event,
            metadata: metadata,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        buffer.append(evt)
        if buffer.count > 20 { buffer.removeFirst(buffer.count - 20) }
        if testMode {
            print("IconButton [TESTMODE] Analytics event: \(event), metadata: \(metadata ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [IconButtonAnalyticsEvent] {
        buffer
    }
}

/// Analytics event structure for IconButton events including audit fields for compliance.
public struct IconButtonAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let metadata: [String: Any]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A SwiftUI View representing a tappable icon button with analytics, accessibility, diagnostics, localization, and audit/trust center compliance support.
public struct IconButton: View {
    /// The icon image to display.
    public let icon: Image
    /// The action to perform when tapped.
    public let action: () -> Void
    /// The tint color of the icon.
    public var color: Color = .accentColor
    /// The icon size.
    public var size: CGFloat = 24
    /// The accessibility label for VoiceOver.
    public var accessibilityLabel: String
    /// The accessibility hint for VoiceOver (optional).
    public var accessibilityHint: String?
    /// The analytics logger (injected, defaults to Null logger).
    public var analyticsLogger: IconButtonAnalyticsLogger
    
    /// Internal event buffer (capped to 20) including audit info for diagnostics.
    @State private var eventBuffer: [IconButtonAnalyticsEvent] = []
    
    /// Initialize an IconButton.
    /// - Parameters:
    ///   - icon: The icon image.
    ///   - action: Action to perform on tap.
    ///   - color: Tint color.
    ///   - size: Icon size.
    ///   - accessibilityLabel: Accessibility label (localized).
    ///   - accessibilityHint: Accessibility hint (localized, optional).
    ///   - analyticsLogger: Analytics logger (default: NullIconButtonAnalyticsLogger).
    public init(
        icon: Image,
        action: @escaping () -> Void,
        color: Color = .accentColor,
        size: CGFloat = 24,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        analyticsLogger: IconButtonAnalyticsLogger = NullIconButtonAnalyticsLogger()
    ) {
        self.icon = icon
        self.action = action
        self.color = color
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.analyticsLogger = analyticsLogger
    }
    
    public var body: some View {
        Button(action: {
            action()
            Task {
                let eventName = NSLocalizedString(
                    "icon_button.tapped.event",
                    value: "icon_button_tapped",
                    comment: "Analytics event name for icon button tap"
                )
                let meta: [String: Any] = [
                    NSLocalizedString("icon_button.accessibility_label.key", value: "accessibilityLabel", comment: "Key for accessibility label in analytics metadata"):
                        accessibilityLabel,
                    NSLocalizedString("icon_button.timestamp.key", value: "timestamp", comment: "Key for timestamp in analytics metadata"):
                        ISO8601DateFormatter().string(from: Date())
                ]
                // Determine escalation flag based on event name or accessibility label containing critical keywords
                let lowercasedEventName = eventName.lowercased()
                let lowercasedLabel = accessibilityLabel.lowercased()
                let escalationKeywords = ["delete", "critical", "danger"]
                let shouldEscalate = escalationKeywords.contains(where: { lowercasedEventName.contains($0) || lowercasedLabel.contains($0) })
                
                await analyticsLogger.log(
                    event: eventName,
                    metadata: meta,
                    role: IconButtonAuditContext.role,
                    staffID: IconButtonAuditContext.staffID,
                    context: IconButtonAuditContext.context,
                    escalate: shouldEscalate
                )
                eventBuffer = analyticsLogger.recentEvents()
            }
        }) {
            icon
                .resizable()
                .scaledToFit()
                .foregroundColor(color)
                .frame(width: size, height: size)
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityHint(Text(accessibilityHint ?? ""))
                .accessibilityAddTraits(.isButton)
        }
        .onAppear {
            // Preload recent events buffer for diagnostics including audit info.
            eventBuffer = analyticsLogger.recentEvents()
        }
    }
    
    /// Fetch the most recent analytics events (last 20) including audit fields.
    public func recentEvents() -> [IconButtonAnalyticsEvent] {
        analyticsLogger.recentEvents()
    }
}

// MARK: - Preview

/// PreviewProvider demonstrating accessibility, testMode, diagnostics, and audit context.
struct IconButton_Previews: PreviewProvider {
    class PreviewLogger: IconButtonAnalyticsLogger {
        var testMode: Bool = true
        private var buffer: [IconButtonAnalyticsEvent] = []
        func log(event: String, metadata: [String : Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let evt = IconButtonAnalyticsEvent(
                timestamp: Date(),
                event: event,
                metadata: metadata,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            buffer.append(evt)
            if buffer.count > 20 { buffer.removeFirst(buffer.count - 20) }
            if testMode {
                print("PREVIEW [IconButton] event: \(event), metadata: \(metadata ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
            }
        }
        func recentEvents() -> [IconButtonAnalyticsEvent] {
            buffer
        }
    }
    
    static var previews: some View {
        let logger = PreviewLogger()
        VStack(spacing: 24) {
            Text(NSLocalizedString("icon_button.preview.title", value: "IconButton Preview", comment: "Title for IconButton preview section"))
                .font(.headline)
            IconButton(
                icon: Image(systemName: "star.fill"),
                action: {
                    print(NSLocalizedString("icon_button.preview.tapped", value: "Star button tapped (preview)", comment: "Console message for preview tap"))
                },
                color: .yellow,
                size: 40,
                accessibilityLabel: NSLocalizedString("icon_button.star.label", value: "Favorite", comment: "Accessibility label for star/favorite button"),
                accessibilityHint: NSLocalizedString("icon_button.star.hint", value: "Marks as favorite", comment: "Accessibility hint for star/favorite button"),
                analyticsLogger: logger
            )
            .accessibilityIdentifier("star-favorite-icon-button")
            
            // Diagnostics: show recent analytics events including audit context
            VStack(alignment: .leading) {
                Text(NSLocalizedString("icon_button.preview.diagnostics", value: "Recent Analytics Events:", comment: "Header for diagnostics section in preview"))
                    .font(.subheadline)
                ForEach(logger.recentEvents()) { event in
                    Text("\(event.timestamp): \(event.event), role: \(event.role ?? "nil"), staffID: \(event.staffID ?? "nil"), context: \(event.context ?? "nil"), escalate: \(event.escalate)")
                        .font(.caption)
                }
            }
            .padding(.top)
            
            Text(NSLocalizedString("icon_button.preview.accessibility_note", value: "Try with VoiceOver enabled to verify accessibility labels and hints.", comment: "Accessibility note for preview"))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .previewDisplayName(NSLocalizedString("icon_button.preview.display_name", value: "IconButton (Accessibility & Diagnostics)", comment: "Preview display name"))
    }
}
