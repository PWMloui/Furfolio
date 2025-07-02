//
//  AnimatedEmptyStateView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, and robust.
//
//  MARK: - Architecture & Extensibility
//
//  AnimatedEmptyStateView is a modular SwiftUI component designed for displaying animated placeholder content in empty states, such as empty lists or onboarding screens.
//  It is built with extensibility in mind, allowing injection of custom analytics loggers, actions, and design tokens.
//  The component supports localization, accessibility, and robust design tokens with fallbacks to ensure visual consistency.
//
//  MARK: - Analytics / Audit / Trust Center
//
//  The view integrates with an async/await-ready analytics logger protocol, enabling audit-ready event logging for user interactions and view appearances.
//  It supports a testMode for console-only logging during QA, testing, or previews.
//  All analytics events are localized and structured for compliance and future Trust Center requirements.
//  Audit context fields such as role, staffID, and context are included in all logging calls for comprehensive audit trails.
//
//  MARK: - Diagnostics & Admin UI
//
//  The component exposes a public API to fetch the last N analytics events, including audit context fields, facilitating diagnostics and administrative UI features.
//
//  MARK: - Localization & Compliance
//
//  All user-facing strings and analytics event identifiers are wrapped in NSLocalizedString with descriptive keys and comments to support localization and compliance.
//
//  MARK: - Accessibility
//
//  Accessibility labels, traits, and element grouping are incorporated to ensure the view is usable with assistive technologies.
//
//  MARK: - Preview & Testability
//
//  The component supports preview injection of analytics loggers and actions, enabling comprehensive testing and diagnostics in SwiftUI previews.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct EmptyStateAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedEmptyStateView"
}

// MARK: - Analytics/Audit Logger Protocol

/// Protocol defining asynchronous analytics logging for empty state events.
/// Supports test mode for console-only logging during QA and previews.
/// Includes audit context fields for role, staffID, and context, plus escalation flag.
public protocol EmptyStateAnalyticsLogger {
    /// Indicates whether the logger is operating in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an analytics event with associated emoji, title, audit context, and escalation flag.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - emoji: The emoji representing the event context.
    ///   - title: The title associated with the event context.
    ///   - role: The user role for audit context.
    ///   - staffID: The staff identifier for audit context.
    ///   - context: The contextual string for audit.
    ///   - escalate: Flag indicating if the event should be escalated.
    func log(event: String, emoji: String, title: String, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

/// A no-operation analytics logger that performs no logging.
/// Useful as a default or placeholder logger.
public struct NullEmptyStateAnalyticsLogger: EmptyStateAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, emoji: String, title: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
}

/// A simple console logger for QA, testing, and preview purposes.
/// Logs events to the console asynchronously, including audit context and escalation.
public class ConsoleEmptyStateAnalyticsLogger: EmptyStateAnalyticsLogger {
    public let testMode: Bool = true

    public init() {}

    public func log(event: String, emoji: String, title: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let localizedEvent = NSLocalizedString(event, comment: "Analytics event identifier")
        let localizedTitle = NSLocalizedString(title, comment: "Title associated with analytics event")
        print("Analytics [TEST MODE]: \(localizedEvent), emoji: \(emoji), title: \(localizedTitle), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
    }
}

/// An animated placeholder view for empty states in lists or onboarding screens.
/// Supports localization, accessibility, analytics, diagnostics, audit context, escalation, and preview/test injection.
public struct AnimatedEmptyStateView: View {
    // MARK: - Public Properties

    /// Emoji icon displayed in the animated circle.
    public var emoji: String = "🐾"

    /// Title text displayed below the emoji.
    public var title: String = NSLocalizedString("No Data Yet", comment: "Default empty state title")

    /// Message text displayed below the title.
    public var message: String = NSLocalizedString("Once you add items, they’ll show up here!", comment: "Default empty state message")

    /// Optional label for the action button.
    public var actionLabel: String? = nil

    /// Optional action closure executed when the action button is tapped.
    public var action: (() -> Void)? = nil

    /// Analytics logger for capturing events.
    public var analyticsLogger: EmptyStateAnalyticsLogger = NullEmptyStateAnalyticsLogger()

    // MARK: - Private State

    @State private var animate = false

    @State private var analyticsEvents: [AnalyticsEvent] = []

    // MARK: - Analytics Event Model

    /// Struct representing a logged analytics event with audit context and escalation.
    private struct AnalyticsEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let event: String
        let emoji: String
        let title: String
        let role: String?
        let staffID: String?
        let context: String?
        let escalate: Bool
    }

    // MARK: - Design Tokens (robust fallback)

    private enum Style {
        static let circleSize: CGFloat = AppSpacing.xxxLarge ?? 110
        static let emojiSize: CGFloat = AppFonts.emptyStateEmoji ?? 60
        static let animationDuration: Double = 1.2
        static let scaleRange: ClosedRange<CGFloat> = 0.94...1.08
        static let rotationAngle: Double = 9
        static let offsetRange: ClosedRange<CGFloat> = -7...7
        static let verticalSpacing: CGFloat = AppSpacing.large ?? 18
        static let frameMax: CGFloat = 350
        static let verticalPad: CGFloat = AppSpacing.xLarge ?? 34
        static let topPad: CGFloat = AppSpacing.medium ?? 16
        static let actionTopPad: CGFloat = AppSpacing.small ?? 8
        static let titleFont: Font = AppFonts.title2Bold ?? .title2.bold()
        static let msgFont: Font = AppFonts.body ?? .body
        static let accent: Color = AppColors.accent ?? .accentColor
        static let primary: Color = AppColors.primary ?? .primary
        static let secondary: Color = AppColors.secondary ?? .secondary
        static let bg: Color = AppColors.emptyStateBg ?? Color.accentColor.opacity(0.13)
    }

    // MARK: - Public API

    /// Fetches the last 20 analytics events logged by this view.
    /// - Returns: An array of tuples containing timestamp, event, emoji, and title.
    public func fetchLastAnalyticsEvents() -> [(timestamp: Date, event: String, emoji: String, title: String)] {
        return analyticsEvents.suffix(20).map { ($0.timestamp, $0.event, $0.emoji, $0.title) }
    }

    /// Fetches the last N analytics events logged by this view, including audit context and escalation.
    /// - Parameter count: The maximum number of recent events to fetch.
    /// - Returns: An array of tuples containing timestamp, event, emoji, title, role, staffID, context, and escalate flag.
    public func fetchLastAnalyticsEvents(count: Int) -> [(timestamp: Date, event: String, emoji: String, title: String, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        return analyticsEvents.suffix(count).map {
            ($0.timestamp, $0.event, $0.emoji, $0.title, $0.role, $0.staffID, $0.context, $0.escalate)
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Style.verticalSpacing) {
            ZStack {
                Circle()
                    .fill(Style.bg)
                    .frame(width: Style.circleSize, height: Style.circleSize)
                    .scaleEffect(animate ? Style.scaleRange.upperBound : Style.scaleRange.lowerBound)
                    .animation(.easeInOut(duration: Style.animationDuration).repeatForever(autoreverses: true), value: animate)

                Text(emoji)
                    .font(.system(size: Style.emojiSize))
                    .rotationEffect(.degrees(animate ? Style.rotationAngle : -Style.rotationAngle))
                    .offset(y: animate ? Style.offsetRange.lowerBound : Style.offsetRange.upperBound)
                    .animation(.interpolatingSpring(stiffness: 140, damping: 9).repeatForever(autoreverses: true), value: animate)
                    .accessibilityLabel(Text(String(format: NSLocalizedString("Empty state icon: %@", comment: "Accessibility label for empty state icon"), emoji)))
            }
            .padding(.top, Style.topPad)

            Text(title)
                .font(Style.titleFont)
                .multilineTextAlignment(.center)
                .foregroundColor(Style.primary)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(Style.msgFont)
                .multilineTextAlignment(.center)
                .foregroundColor(Style.secondary)
                .accessibilityLabel(Text(message))

            if let label = actionLabel, let action = action {
                Button(label, action: {
                    Task {
                        let escalate = shouldEscalate(for: label, or: title)
                        await logEvent(eventKey: "action_tapped", emoji: emoji, title: title, escalate: escalate)
                        action()
                    }
                })
                .buttonStyle(PulseButtonStyle(color: Style.accent))
                .padding(.top, Style.actionTopPad)
                .accessibilityLabel(String(format: NSLocalizedString("Button: %@", comment: "Accessibility label for button with label"), label))
            }
        }
        .frame(maxWidth: Style.frameMax)
        .padding(.vertical, Style.verticalPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animate = true
            Task {
                await logEvent(eventKey: "empty_state_appeared", emoji: emoji, title: title, escalate: false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Private Helpers

    /// Determines whether the event should be escalated based on presence of critical keywords.
    /// - Parameters:
    ///   - label: The action label string.
    ///   - title: The title string.
    /// - Returns: True if escalation is required, false otherwise.
    private func shouldEscalate(for label: String, or title: String) -> Bool {
        let keywords = ["Delete", "Remove", "Critical"]
        let combined = (label + title).lowercased()
        for keyword in keywords {
            if combined.contains(keyword.lowercased()) {
                return true
            }
        }
        return false
    }

    /// Logs an analytics event asynchronously and stores it for diagnostics, including audit context and escalation.
    /// - Parameters:
    ///   - eventKey: The event identifier key for localization.
    ///   - emoji: The emoji context.
    ///   - title: The title context.
    ///   - escalate: Flag indicating if the event should be escalated.
    private func logEvent(eventKey: String, emoji: String, title: String, escalate: Bool) async {
        let localizedEvent = NSLocalizedString(eventKey, comment: "Analytics event identifier")
        let localizedTitle = NSLocalizedString(title, comment: "Title associated with analytics event")
        let role = EmptyStateAuditContext.role
        let staffID = EmptyStateAuditContext.staffID
        let context = EmptyStateAuditContext.context
        let newEvent = AnalyticsEvent(timestamp: Date(), event: localizedEvent, emoji: emoji, title: localizedTitle, role: role, staffID: staffID, context: context, escalate: escalate)
        await MainActor.run {
            analyticsEvents.append(newEvent)
            if analyticsEvents.count > 20 {
                analyticsEvents.removeFirst(analyticsEvents.count - 20)
            }
        }
        await analyticsLogger.log(event: localizedEvent, emoji: emoji, title: localizedTitle, role: role, staffID: staffID, context: context, escalate: escalate)
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedEmptyStateView_Previews: PreviewProvider {
    struct SpyLogger: EmptyStateAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, emoji: String, title: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("Analytics: \(event), emoji: \(emoji), title: \(title), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    static var previews: some View {
        Group {
            AnimatedEmptyStateView(
                emoji: "🐩",
                title: NSLocalizedString("No Dogs Added", comment: "Preview title for no dogs added"),
                message: NSLocalizedString("Add a new dog profile to see them listed here.", comment: "Preview message for no dogs added"),
                actionLabel: NSLocalizedString("Add Dog", comment: "Preview action label to add a dog"),
                action: {},
                analyticsLogger: SpyLogger()
            )
            .previewLayout(.sizeThatFits)

            AnimatedEmptyStateView(analyticsLogger: SpyLogger())
                .previewLayout(.sizeThatFits)
        }
        .padding()
        .background(AppColors.emptyStatePreviewBg ?? Color(.systemGroupedBackground))
        .preferredColorScheme(.light)
    }
}
#endif
