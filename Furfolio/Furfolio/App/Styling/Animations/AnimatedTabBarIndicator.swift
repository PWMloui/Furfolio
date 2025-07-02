//
//  AnimatedTabBarIndicator.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, and robust.
//
//  MARK: - AnimatedTabBarIndicator Architecture and Extensibility
//
//  AnimatedTabBarIndicator is designed as a modular and extensible SwiftUI component for displaying an animated selection indicator within a custom tab bar.
//  Its architecture emphasizes separation of concerns by injecting analytics/audit logging via a protocol, supporting asynchronous logging for modern concurrency patterns.
//  The component leverages environment values for layout direction to support RTL languages, and uses token-based styling for consistent theming and design compliance.
//  Accessibility is integrated with VoiceOver traits and localized labels to ensure compliance with accessibility standards.
//  All user-facing and log event strings are localized via NSLocalizedString to support internationalization and compliance requirements.
//  The component exposes diagnostic APIs to retrieve recent analytics events, facilitating audit, diagnostics, and Trust Center integrations.
//  Preview and testability are enhanced via dependency injection of analytics loggers and a testMode flag for console-only logging in QA or preview environments.
//  This design supports future enhancements such as remote analytics, advanced audit trails, and administrative diagnostics UI.
//
//  Usage:
//  Place AnimatedTabBarIndicator inside a ZStack beneath tab buttons to animate the indicator bar.
//  Inject a custom TabBarIndicatorAnalyticsLogger conforming to the protocol for analytics integration.
//  Access the last 20 logged events via the public API for diagnostics or Trust Center review.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TabBarIndicatorAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedTabBarIndicator"
}

// MARK: - Analytics/Audit Logger Protocol

/// Represents an audit event logged by the tab bar indicator analytics system.
public struct TabBarIndicatorAuditEvent: Identifiable {
    public let id = UUID()
    public let event: String
    public let selectedIndex: Int
    public let tabCount: Int
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let timestamp: Date
}

/// Protocol defining asynchronous analytics/audit logging for the tab bar indicator.
/// Conforming types should implement async logging methods to support concurrency and future analytics pipelines.
public protocol TabBarIndicatorAnalyticsLogger {
    /// Indicates if the logger is running in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an analytics event with the specified parameters.
    /// - Parameters:
    ///   - event: The event name or identifier.
    ///   - selectedIndex: The currently selected tab index.
    ///   - tabCount: The total number of tabs.
    ///   - role: The role of the current user/session for audit context.
    ///   - staffID: The staff ID of the current user/session for audit context.
    ///   - context: Additional context string for the audit event.
    ///   - escalate: Flag indicating if this event should be escalated for high-priority auditing.
    func log(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Retrieves the last 20 logged analytics events for diagnostics or admin UI.
    /// - Returns: An array of audit events.
    func fetchLastEvents() async -> [TabBarIndicatorAuditEvent]

    /// Escalates a specific event for urgent audit or compliance review.
    /// - Parameters:
    ///   - event: The event name or identifier.
    ///   - selectedIndex: The currently selected tab index.
    ///   - tabCount: The total number of tabs.
    ///   - role: The role of the current user/session for audit context.
    ///   - staffID: The staff ID of the current user/session for audit context.
    ///   - context: Additional context string for the audit event.
    func escalate(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?) async
}

/// Default no-op logger implementation for preview, testing, or when no analytics are needed.
public struct NullTabBarIndicatorAnalyticsLogger: TabBarIndicatorAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchLastEvents() async -> [TabBarIndicatorAuditEvent] { [] }
    public func escalate(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?) async {}
}

/// Console logger for QA, testing, and previews with in-memory event storage.
public class ConsoleTabBarIndicatorAnalyticsLogger: TabBarIndicatorAnalyticsLogger {
    public let testMode: Bool = true
    private var eventLog: [TabBarIndicatorAuditEvent] = []
    private let maxEvents = 20
    private let queue = DispatchQueue(label: "ConsoleTabBarIndicatorAnalyticsLogger.queue")

    public init() {}

    /// Logs events asynchronously, storing them in memory and printing to console.
    public func log(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
        let timestamp = Date()
        let logEntry = TabBarIndicatorAuditEvent(
            event: localizedEvent,
            selectedIndex: selectedIndex,
            tabCount: tabCount,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate,
            timestamp: timestamp
        )
        queue.sync {
            if eventLog.count >= maxEvents {
                eventLog.removeFirst()
            }
            eventLog.append(logEntry)
        }
        let escalateStr = escalate ? NSLocalizedString("ESCALATE", comment: "Escalation flag") : NSLocalizedString("Normal", comment: "Normal event flag")
        print("TabBarAnalytics: [\(timestamp)] Event: \(localizedEvent), SelectedIndex: \(selectedIndex), TabCount: \(tabCount), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalateStr)")
    }

    /// Returns the last 20 logged events.
    public func fetchLastEvents() async -> [TabBarIndicatorAuditEvent] {
        return queue.sync { eventLog }
    }

    /// Escalates a specific event for urgent audit or compliance review.
    public func escalate(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?) async {
        await log(event: event, selectedIndex: selectedIndex, tabCount: tabCount, role: role, staffID: staffID, context: context, escalate: true)
    }
}

/// Animated bar indicator for a custom tab bar.
/// Use inside a ZStack beneath tab buttons to show selection.
/// Now with analytics/audit hooks, full token compliance, and advanced accessibility.
struct AnimatedTabBarIndicator: View {
    /// Total number of tabs in the bar.
    var tabCount: Int

    /// Currently selected tab index.
    var selectedIndex: Int

    /// Color of the indicator bar.
    var color: Color = AppColors.accent ?? .accentColor

    /// Height of the indicator line.
    var height: CGFloat = AppSpacing.tabBarIndicatorHeight ?? 4

    /// Corner radius for the indicator bar.
    var cornerRadius: CGFloat = AppRadius.small ?? 2.5

    /// Padding inside each tab cell.
    var padding: CGFloat = AppSpacing.medium ?? 14

    /// Alignment position for the indicator (.top or .bottom)
    var alignment: VerticalAlignment = .bottom

    /// Analytics/audit logger (DI for preview/test/enterprise)
    var analyticsLogger: TabBarIndicatorAnalyticsLogger = NullTabBarIndicatorAnalyticsLogger()

    /// Layout direction (LTR or RTL)
    @Environment(\.layoutDirection) private var layoutDirection

    private enum Tokens {
        static let animation: Animation = .spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12)
        static let offsetYPadding: CGFloat = AppSpacing.xsmall ?? 2
    }

    /// The body of the view displaying the animated indicator.
    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(max(tabCount, 1))
            let safeIndex = min(max(selectedIndex, 0), tabCount-1)
            let xOffset = CGFloat(layoutDirection == .leftToRight ? safeIndex : (tabCount - 1 - safeIndex)) * tabWidth + padding / 2
            let yOffset = alignment == .top ? Tokens.offsetYPadding : geo.size.height - height - Tokens.offsetYPadding

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
                .frame(width: tabWidth - padding, height: height)
                .offset(x: xOffset, y: yOffset)
                .animation(Tokens.animation, value: safeIndex)
                .accessibilityElement()
                .accessibilityLabel(Text(NSLocalizedString("Selected tab indicator", comment: "Accessibility label for the selected tab indicator")))
                .accessibilityValue(Text(String(format: NSLocalizedString("Tab %d of %d selected", comment: "Accessibility value describing selected tab index and total tabs"), safeIndex + 1, tabCount)))
                .accessibilityAddTraits(.isSelected)
                .task {
                    let escalateFlag = (safeIndex == 0 && tabCount > 2)
                    await analyticsLogger.log(
                        event: NSLocalizedString("indicator_appear", comment: "Analytics event when indicator appears"),
                        selectedIndex: safeIndex,
                        tabCount: tabCount,
                        role: TabBarIndicatorAuditContext.role,
                        staffID: TabBarIndicatorAuditContext.staffID,
                        context: TabBarIndicatorAuditContext.context,
                        escalate: escalateFlag
                    )
                }
                .onChange(of: safeIndex) { newValue in
                    Task {
                        let escalateFlag = (newValue == 0 && tabCount > 2)
                        await analyticsLogger.log(
                            event: NSLocalizedString("indicator_changed", comment: "Analytics event when indicator selection changes"),
                            selectedIndex: newValue,
                            tabCount: tabCount,
                            role: TabBarIndicatorAuditContext.role,
                            staffID: TabBarIndicatorAuditContext.staffID,
                            context: TabBarIndicatorAuditContext.context,
                            escalate: escalateFlag
                        )
                    }
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("Tab bar indicator", comment: "Accessibility label for the tab bar indicator container")))
    }

    // MARK: - Public API

    /// Asynchronously fetches the last 20 analytics audit events logged by the indicator.
    /// - Returns: An array of audit events for diagnostics, compliance, or Trust Center review.
    public func fetchLastAnalyticsEvents() async -> [TabBarIndicatorAuditEvent] {
        await analyticsLogger.fetchLastEvents()
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedTabBarIndicator_Previews: PreviewProvider {
    /// Spy logger for preview/testing that prints logs to console and stores audit events.
    class SpyLogger: TabBarIndicatorAnalyticsLogger {
        public let testMode: Bool = true
        private var events: [TabBarIndicatorAuditEvent] = []
        private let maxEvents = 20
        private let queue = DispatchQueue(label: "SpyLogger.queue")

        func log(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
            let timestamp = Date()
            let logEntry = TabBarIndicatorAuditEvent(
                event: localizedEvent,
                selectedIndex: selectedIndex,
                tabCount: tabCount,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate,
                timestamp: timestamp
            )
            queue.sync {
                if events.count >= maxEvents {
                    events.removeFirst()
                }
                events.append(logEntry)
            }
            let escalateStr = escalate ? NSLocalizedString("ESCALATE", comment: "Escalation flag") : NSLocalizedString("Normal", comment: "Normal event flag")
            print("TabBarAnalytics: [\(timestamp)] Event: \(localizedEvent), SelectedIndex: \(selectedIndex), TabCount: \(tabCount), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalateStr)")
        }

        func fetchLastEvents() async -> [TabBarIndicatorAuditEvent] {
            return queue.sync { events }
        }

        func escalate(event: String, selectedIndex: Int, tabCount: Int, role: String?, staffID: String?, context: String?) async {
            await log(event: event, selectedIndex: selectedIndex, tabCount: tabCount, role: role, staffID: staffID, context: context, escalate: true)
        }
    }

    static var previews: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.11)
                AnimatedTabBarIndicator(
                    tabCount: 4,
                    selectedIndex: 1,
                    color: .blue,
                    analyticsLogger: SpyLogger()
                )
            }
            .frame(height: 56)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
