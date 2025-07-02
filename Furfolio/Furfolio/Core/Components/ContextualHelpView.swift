/**
 ContextualHelpView.swift
 Furfolio

 # Architectural Overview
 ContextualHelpView is a modular, extensible SwiftUI view for displaying inline or popover help, tips, or guidance to users. It is designed for:
 - **Analytics/Audit/Trust Center**: All user interactions/events are routed through a swappable, protocol-based analytics logger. This enables Trust Center, audit, or compliance hooks, and supports admin/diagnostic review.
 - **Extensibility**: The analytics logger, icon, actions, and visibility are all injectable, supporting test/preview, QA, and enterprise scenarios.
 - **Diagnostics/Buffering**: The analytics logger buffers the last 20 events, with a public API to fetch recent events for admin/diagnostics.
 - **Localization**: All user-facing and log event strings are wrapped in NSLocalizedString with keys, values, and comments for full localization and compliance.
 - **Accessibility**: All controls and text have accessibility labels, hints, and identifiers, and are grouped for screen readers.
 - **Compliance**: Designed for privacy, audit, and Trust Center readiness; no analytics are sent unless logger is swapped in.
 - **Preview/Testability**: The logger and visibility are fully injectable, with a NullContextualHelpAnalyticsLogger for previews/tests, and diagnostics buffer visible in SwiftUI previews.

 # Extending/Customizing
 - Swap ContextualHelpView.analyticsLogger with any ContextualHelpAnalyticsLogger (e.g., for Trust Center, print, admin, or QA).
 - Use .testMode on the logger for console-only logging.
 - Use NullContextualHelpAnalyticsLogger for previews/tests to avoid analytics.
 - Fetch recent analytics events using ContextualHelpView.recentAnalyticsEvents.
 - All user-facing strings and log events are localized; add translations via Localizable.strings as needed.
 - Accessibility is robust; verify with screen readers.
 - PreviewProvider demonstrates test, accessibility, and diagnostics buffer scenarios.

 # For Future Maintainers
 - All major methods/properties are documented.
 - Update analytics event keys in one place for compliance.
 - Use async/await for all logger calls for future concurrency.
 - Add additional Trust Center, compliance, or diagnostic hooks as needed.
*/
//
//  ContextualHelpView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–ready, preview/test–injectable, robust accessibility.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Audit Context (set at login/session)
public struct ContextualHelpAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ContextualHelpView"
}

// MARK: - Analytics/Audit Protocol

/**
 Protocol for contextual help analytics logging.
 Conformers should implement async logging. Used for audit, Trust Center, QA, or diagnostics.
 */
public protocol ContextualHelpAnalyticsLogger {
    var testMode: Bool { get }
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/**
 Null logger for previews/tests. Does nothing.
 */
public struct NullContextualHelpAnalyticsLogger: ContextualHelpAnalyticsLogger {
    public let testMode: Bool
    public init(testMode: Bool = false) { self.testMode = testMode }
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[NullContextualHelpAnalyticsLogger][testMode] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
}

/**
 Default analytics logger with async/await, testMode, and capped event buffer for diagnostics/admin.
 */
public actor DefaultContextualHelpAnalyticsLogger: ContextualHelpAnalyticsLogger {
    public private(set) var eventBuffer: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
    public let testMode: Bool
    private let bufferLimit: Int = 20
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    /// Logs an event and info, buffers last N events, and prints to console if testMode.
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let now = Date()
        eventBuffer.append((now, event, info, role, staffID, context, escalate))
        if eventBuffer.count > bufferLimit {
            eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
        }
        if testMode {
            print("[ContextualHelpAnalytics][testMode] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
        // Insert Trust Center, audit, or compliance hooks here as needed.
    }
    /// Returns the last N analytics events for diagnostics/admin.
    public func recentEvents() async -> [(Date, String, [String: Any]?, String?, String?, String?, Bool)] {
        eventBuffer
    }
}

// MARK: - ContextualHelpView (Enhanced)

/**
 ContextualHelpView: Inline help/tip component with analytics, accessibility, and compliance hooks.
 */
struct ContextualHelpView: View {
    /// Title of the help message (localized).
    let title: String
    /// Body/message of the help (localized).
    let message: String

    /// Icon type: system SF Symbol or asset.
    enum IconType {
        case systemName(String)
        case assetName(String)
    }
    /// Icon to display.
    var icon: IconType = .systemName("questionmark.circle.fill")
    /// Show dismiss (X) button.
    var showDismissButton: Bool = true
    /// Optional secondary action button label (localized).
    var secondaryActionLabel: String? = nil
    /// Optional secondary action handler.
    var secondaryActionHandler: (() -> Void)? = nil

    /// External binding for visibility (optional).
    @Binding var externalIsVisible: Bool?
    /// Internal state for visibility if no external binding.
    @State private var internalIsVisible: Bool = true
    /// Returns the correct binding for visibility.
    private var isVisibleBinding: Binding<Bool> {
        Binding<Bool>(
            get: { externalIsVisible ?? internalIsVisible },
            set: { newValue in
                if externalIsVisible != nil {
                    externalIsVisible = newValue
                } else {
                    internalIsVisible = newValue
                }
            }
        )
    }

    /// Analytics logger (swap for QA, Trust Center, print, or admin review).
    static var analyticsLogger: ContextualHelpAnalyticsLogger = NullContextualHelpAnalyticsLogger()
    /// Capped buffer of recent analytics events for diagnostics/admin.
    static var recentAnalyticsEvents: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] {
        get async {
            // Only works for DefaultContextualHelpAnalyticsLogger; otherwise returns [].
            if let actorLogger = analyticsLogger as? DefaultContextualHelpAnalyticsLogger {
                return await actorLogger.recentEvents()
            }
            return []
        }
    }

    #if os(iOS) || os(tvOS)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    var body: some View {
        if isVisibleBinding.wrappedValue {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    iconView
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.accent)
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("ContextualHelpView.title.\(title)", value: title, comment: "Contextual help title"))
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("ContextualHelpView_Title")
                    Spacer()
                    if showDismissButton {
                        Button(action: {
                            Task { await dismiss() }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(NSLocalizedString("ContextualHelpView.dismiss.label", value: "Dismiss Help", comment: "Accessibility: Dismiss help button")))
                        .accessibilityHint(Text(NSLocalizedString("ContextualHelpView.dismiss.hint", value: "Closes the help message.", comment: "Accessibility: Dismiss help hint")))
                        .accessibilityIdentifier("ContextualHelpView_DismissButton")
                    }
                }
                Text(NSLocalizedString("ContextualHelpView.message.\(message)", value: message, comment: "Contextual help message"))
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(Text(NSLocalizedString("ContextualHelpView.message.\(message)", value: message, comment: "Contextual help message")))
                    .accessibilityIdentifier("ContextualHelpView_Message")

                if let label = secondaryActionLabel, let handler = secondaryActionHandler {
                    Button(action: {
                        Task {
                            let event = NSLocalizedString("ContextualHelpView.event.secondary_action", value: "secondary_action", comment: "Analytics event: secondary action")
                            let info: [String: Any] = [
                                NSLocalizedString("ContextualHelpView.info.title", value: "title", comment: "Analytics info: title"): title,
                                NSLocalizedString("ContextualHelpView.info.label", value: "label", comment: "Analytics info: label"): label
                            ]
                            let role = ContextualHelpAuditContext.role
                            let staffID = ContextualHelpAuditContext.staffID
                            let context = ContextualHelpAuditContext.context
                            let escalate = Self.shouldEscalate(event: event, info: info)
                            await Self.analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: context, escalate: escalate)
                            handler()
                        }
                    }) {
                        Text(NSLocalizedString("ContextualHelpView.secondary.label.\(label)", value: label, comment: "Secondary action label"))
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.accent)
                            .padding(.vertical, AppSpacing.small)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.medium)
                                    .stroke(AppColors.accent, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(Text(NSLocalizedString("ContextualHelpView.secondary.label.\(label)", value: label, comment: "Secondary action label")))
                    .accessibilityHint(Text(String(format: NSLocalizedString("ContextualHelpView.secondary.hint", value: "Performs the '%@' action for this help message.", comment: "Accessibility: secondary action hint"), label)))
                    .accessibilityIdentifier("ContextualHelpView_SecondaryActionButton")
                }
            }
            .padding(AppSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.medium)
                    .fill(AppColors.card)
                    .appShadow(AppShadows.card)
            )
            .padding(.horizontal, AppSpacing.medium)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: isVisibleBinding.wrappedValue)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(String(format: NSLocalizedString("ContextualHelpView.accessibility.inlineHelp", value: "Inline Help: %@. %@", comment: "Accessibility: help container label"), title, message)))
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("ContextualHelpView_Root")
            .onAppear {
                Task {
                    let event = NSLocalizedString("ContextualHelpView.event.help_shown", value: "help_shown", comment: "Analytics event: help shown")
                    let info: [String: Any] = [
                        NSLocalizedString("ContextualHelpView.info.title", value: "title", comment: "Analytics info: title"): title,
                        NSLocalizedString("ContextualHelpView.info.message", value: "message", comment: "Analytics info: message"): message
                    ]
                    let role = ContextualHelpAuditContext.role
                    let staffID = ContextualHelpAuditContext.staffID
                    let context = ContextualHelpAuditContext.context
                    let escalate = Self.shouldEscalate(event: event, info: info)
                    await Self.analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: context, escalate: escalate)
                }
            }
        }
    }

    /// Renders the icon (system SF Symbol or asset).
    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .systemName(let name):
            Image(systemName: name)
        case .assetName(let name):
            Image(name)
                .renderingMode(.template)
        }
    }

    /// Dismisses the help view and logs analytics.
    private func dismiss() async {
        #if os(iOS) || os(tvOS)
        feedbackGenerator.impactOccurred()
        #endif
        isVisibleBinding.wrappedValue = false
        let event = NSLocalizedString("ContextualHelpView.event.help_dismissed", value: "help_dismissed", comment: "Analytics event: help dismissed")
        let info: [String: Any] = [
            NSLocalizedString("ContextualHelpView.info.title", value: "title", comment: "Analytics info: title"): title
        ]
        let role = ContextualHelpAuditContext.role
        let staffID = ContextualHelpAuditContext.staffID
        let context = ContextualHelpAuditContext.context
        let escalate = Self.shouldEscalate(event: event, info: info)
        await Self.analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: context, escalate: escalate)
    }

    /// Determines if the event or info should be escalated for audit.
    private static func shouldEscalate(event: String, info: [String: Any]?) -> Bool {
        let keywords = ["danger", "critical", "delete"]
        let eventLower = event.lowercased()
        if keywords.contains(where: { eventLower.contains($0) }) {
            return true
        }
        if let info = info {
            for value in info.values {
                if let str = value as? String {
                    let lower = str.lowercased()
                    if keywords.contains(where: { lower.contains($0) }) {
                        return true
                    }
                }
            }
        }
        return false
    }
}

// MARK: - Preview with Analytics Logger, testMode, accessibility, diagnostics buffer

#Preview {
    struct PreviewLogger: ContextualHelpAnalyticsLogger {
        let testMode: Bool
        var buffer: [(Date, String, [String: Any]?)] = []
        init(testMode: Bool = false) { self.testMode = testMode }
        func log(
            event: String,
            info: [String: Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            print("[ContextualHelpAnalytics][PreviewLogger][testMode:\(testMode)] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    // Use a DefaultContextualHelpAnalyticsLogger with testMode for diagnostics buffer.
    let logger = DefaultContextualHelpAnalyticsLogger(testMode: true)
    ContextualHelpView.analyticsLogger = logger
    @State var showHelp1 = true
    @State var showHelp2 = true
    @State var showHelp3 = true

    return VStack(spacing: AppSpacing.large) {
        Spacer()
        ContextualHelpView(
            title: NSLocalizedString("ContextualHelpView.preview.title.needAHand", value: "Need a hand?", comment: "Preview: help title"),
            message: NSLocalizedString("ContextualHelpView.preview.message.needAHand", value: "Tap the '+' to add new clients or pets. For more tips, visit the FAQ in Settings.", comment: "Preview: help message"),
            icon: .systemName("questionmark.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: NSLocalizedString("ContextualHelpView.preview.secondary.learnMore", value: "Learn More", comment: "Preview: secondary action"),
            secondaryActionHandler: {
                print("Learn More tapped (preview)")
            },
            externalIsVisible: .constant(true)
        )
        ContextualHelpView(
            title: NSLocalizedString("ContextualHelpView.preview.title.customIcon", value: "Custom Icon Example", comment: "Preview: custom icon title"),
            message: NSLocalizedString("ContextualHelpView.preview.message.customIcon", value: "This help view uses a custom asset icon and no dismiss button.", comment: "Preview: custom icon message"),
            icon: .assetName("customHelpIcon"),
            showDismissButton: false,
            externalIsVisible: .constant(true)
        )
        ContextualHelpView(
            title: NSLocalizedString("ContextualHelpView.preview.title.controlledVisibility", value: "Controlled Visibility", comment: "Preview: controlled visibility title"),
            message: NSLocalizedString("ContextualHelpView.preview.message.controlledVisibility", value: "This help view's visibility is controlled externally.", comment: "Preview: controlled visibility message"),
            icon: .systemName("info.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: NSLocalizedString("ContextualHelpView.preview.secondary.details", value: "Details", comment: "Preview: secondary action details"),
            secondaryActionHandler: { print("Details tapped (preview)") },
            externalIsVisible: .constant(true)
        )
        // Diagnostics: Show analytics buffer.
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("ContextualHelpView.preview.diagnostics.title", value: "Recent Analytics Events", comment: "Preview: diagnostics events title"))
                .font(.headline)
            // Use an async task to fetch recent events.
            DiagnosticsBufferView(logger: logger)
                .frame(maxHeight: 160)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityIdentifier("ContextualHelpView_Preview_DiagnosticsBuffer")
        Spacer()
    }
    .background(AppColors.background)
    .padding(AppSpacing.medium)
}

/// Diagnostics buffer view for preview: shows recent analytics events.
@MainActor
private struct DiagnosticsBufferView: View {
    let logger: DefaultContextualHelpAnalyticsLogger
    @State private var events: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    Text(
                        "\(event.0.formatted(date: .abbreviated, time: .standard)): event: \(event.1), info: \(event.2.map { "\($0)" } ?? "nil"), role: \(event.3 ?? "nil"), staffID: \(event.4 ?? "nil"), context: \(event.5 ?? "nil"), escalate: \(event.6)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                if events.isEmpty {
                    Text(NSLocalizedString("ContextualHelpView.preview.diagnostics.empty", value: "No analytics events yet.", comment: "Preview: diagnostics empty"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            Task {
                self.events = await logger.recentEvents()
            }
        }
        .onTapGesture {
            Task {
                self.events = await logger.recentEvents()
            }
        }
    }
}
