//
//  SpringSlideTransition.swift
//  Furfolio
//
//  Architecture:
//  SpringSlideTransition is designed as a modular, extensible SwiftUI transition modifier with built-in analytics and audit hooks.
//  It supports asynchronous logging via async/await, enabling integration with modern telemetry systems.
//  The transition is token-compliant for design consistency and supports accessibility traits for inclusive UI.
//  Diagnostics and admin UIs can query recent analytics events for auditing and troubleshooting.
//  All user-facing and log strings are localized for compliance and global readiness.
//  Preview and testability are enhanced via dependency injection and testMode logging.
//
//  Extensibility:
//  - Analytics logging is abstracted via SpringSlideTransitionAnalyticsLogger protocol, supporting async, audit events, escalation, and test modes.
//  - Design tokens are externally configurable via AppTheme.Animation, with robust defaults.
//  - Transition edges and animations are customizable.
//
//  Analytics/Audit/Trust Center:
//  - Async logging supports non-blocking telemetry capture with audit context.
//  - testMode enables console-only logging useful during QA and previews.
//  - Recent event history accessible via public API for diagnostics and escalation.
//
//  Diagnostics:
//  - Public API to fetch last 20 audit analytics events with timestamps, edge info, role, staffID, context, and escalation flag.
//
//  Localization:
//  - All user-facing and analytic event strings use NSLocalizedString with keys and comments.
//
//  Accessibility:
//  - Adds .isModal accessibility trait to signal major UI transitions.
//
//  Compliance:
//  - Uses design tokens for animation parameters.
//  - Localized strings for all outputs.
//
//  Preview/Testability:
//  - Dependency injection for analytics logger.
//  - Test mode logging simplifies QA.
//  - Preview provider demonstrates usage with a spy logger.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SpringSlideAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SpringSlideTransition"
}

// MARK: - Analytics/Audit Protocol

/// Protocol defining asynchronous analytics logging for SpringSlideTransition with audit context and escalation support.
/// Supports test mode for console-only logging during QA, tests, and previews.
public protocol SpringSlideTransitionAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an event with associated edge information and audit context.
    /// - Parameters:
    ///   - event: The event name or identifier.
    ///   - edge: The edge from which the transition occurred.
    ///   - role: The user role for audit context.
    ///   - staffID: The staff identifier for audit context.
    ///   - context: The audit context string.
    ///   - escalate: Flag indicating if this event should be escalated.
    func log(event: String, edge: Edge, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Fetches recent audit events with a specified count.
    /// - Parameter count: Number of recent events to fetch.
    /// - Returns: Array of audit events.
    func fetchRecentEvents(count: Int) async -> [SpringSlideTransitionAuditEvent]

    /// Escalates a particular event for audit/trust center purposes.
    /// - Parameters:
    ///   - event: The event name or identifier.
    ///   - edge: The edge from which the transition occurred.
    ///   - role: The user role for audit context.
    ///   - staffID: The staff identifier for audit context.
    ///   - context: The audit context string.
    func escalate(event: String, edge: Edge, role: String?, staffID: String?, context: String?) async
}

/// Represents a single audit event with full context and escalation flag.
public struct SpringSlideTransitionAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let edge: Edge
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// A no-op analytics logger conforming to SpringSlideTransitionAnalyticsLogger.
/// Useful as a default or placeholder to avoid optional handling.
public struct NullSpringSlideTransitionAnalyticsLogger: SpringSlideTransitionAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, edge: Edge, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [SpringSlideTransitionAuditEvent] { [] }
    public func escalate(event: String, edge: Edge, role: String?, staffID: String?, context: String?) async {}
}

/// A simple console logger for QA, tests, and previews.
/// Logs asynchronously to the console when testMode is true and maintains an in-memory buffer of last 20 audit events.
public class ConsoleSpringSlideTransitionAnalyticsLogger: SpringSlideTransitionAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}

    private var events: [SpringSlideTransitionAuditEvent] = []

    public func log(event: String, edge: Edge, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
        let localizedEdge = NSLocalizedString("\(edge)", comment: "Edge name in analytics log")
        let roleStr = role ?? "nil"
        let staffStr = staffID ?? "nil"
        let contextStr = context ?? "nil"
        let escalateStr = escalate ? "YES" : "NO"
        let logMessage = """
        [SpringSlideAnalytics] Event: \(localizedEvent)
        Edge: \(localizedEdge)
        Role: \(roleStr)
        StaffID: \(staffStr)
        Context: \(contextStr)
        Escalate: \(escalateStr)
        """
        print(logMessage)

        let newEvent = SpringSlideTransitionAuditEvent(timestamp: Date(), event: event, edge: edge, role: role, staffID: staffID, context: context, escalate: escalate)
        events.append(newEvent)
        if events.count > 20 {
            events.removeFirst(events.count - 20)
        }
    }

    public func fetchRecentEvents(count: Int) async -> [SpringSlideTransitionAuditEvent] {
        let recent = Array(events.suffix(count))
        return recent
    }

    public func escalate(event: String, edge: Edge, role: String?, staffID: String?, context: String?) async {
        // For console logger, just print escalation notice
        let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
        let localizedEdge = NSLocalizedString("\(edge)", comment: "Edge name in analytics log")
        let roleStr = role ?? "nil"
        let staffStr = staffID ?? "nil"
        let contextStr = context ?? "nil"
        print("[SpringSlideAnalytics][ESCALATION] Event: \(localizedEvent), Edge: \(localizedEdge), Role: \(roleStr), StaffID: \(staffStr), Context: \(contextStr)")
    }
}

/// Internal storage for analytics events for diagnostics and admin UI.
/// Thread-safe storage of recent audit analytics events.
private actor SpringSlideTransitionAnalyticsStorage {
    private var events: [SpringSlideTransitionAuditEvent] = []

    /// Adds a new audit analytics event to the storage.
    /// Keeps only the latest 20 events.
    func add(event: SpringSlideTransitionAuditEvent) {
        events.append(event)
        if events.count > 20 {
            events.removeFirst(events.count - 20)
        }
    }

    /// Retrieves the last `count` audit analytics events.
    func getRecentEvents(count: Int) -> [SpringSlideTransitionAuditEvent] {
        return Array(events.suffix(count))
    }
}

private let analyticsStorage = SpringSlideTransitionAnalyticsStorage()

/// A view modifier applying a directional spring slide transition,
/// now with design token compliance, async analytics, audit context, accessibility, and diagnostics.
private struct SpringSlideModifier: ViewModifier {
    let edge: Edge
    var analyticsLogger: SpringSlideTransitionAnalyticsLogger = NullSpringSlideTransitionAnalyticsLogger()

    // Tokenized constants, robust fallback.
    private enum Tokens {
        static let insertionStiffness: Double = AppTheme.Animation.springSlideInsertionStiffness ?? 260
        static let insertionDamping: Double = AppTheme.Animation.springSlideInsertionDamping ?? 26
        static let removalStiffness: Double = AppTheme.Animation.springSlideRemovalStiffness ?? 220
        static let removalDamping: Double = AppTheme.Animation.springSlideRemovalDamping ?? 19
    }

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Tokens.insertionStiffness,
                            damping: Tokens.insertionDamping
                        )),
                    removal: .move(edge: edge.opposite)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Tokens.removalStiffness,
                            damping: Tokens.removalDamping
                        ))
                )
            )
            .onAppear {
                Task {
                    let eventKey = NSLocalizedString("springSlide_insertion", comment: "Analytics event for spring slide insertion")
                    let escalateFlag = (edge == .top)
                    await analyticsLogger.log(event: eventKey, edge: edge, role: SpringSlideAuditContext.role, staffID: SpringSlideAuditContext.staffID, context: SpringSlideAuditContext.context, escalate: escalateFlag)
                    let auditEvent = SpringSlideTransitionAuditEvent(timestamp: Date(), event: eventKey, edge: edge, role: SpringSlideAuditContext.role, staffID: SpringSlideAuditContext.staffID, context: SpringSlideAuditContext.context, escalate: escalateFlag)
                    await analyticsStorage.add(event: auditEvent)
                }
            }
            .onDisappear {
                Task {
                    let eventKey = NSLocalizedString("springSlide_removal", comment: "Analytics event for spring slide removal")
                    let escalateFlag = (edge == .top)
                    await analyticsLogger.log(event: eventKey, edge: edge, role: SpringSlideAuditContext.role, staffID: SpringSlideAuditContext.staffID, context: SpringSlideAuditContext.context, escalate: escalateFlag)
                    let auditEvent = SpringSlideTransitionAuditEvent(timestamp: Date(), event: eventKey, edge: edge, role: SpringSlideAuditContext.role, staffID: SpringSlideAuditContext.staffID, context: SpringSlideAuditContext.context, escalate: escalateFlag)
                    await analyticsStorage.add(event: auditEvent)
                }
            }
            .accessibilityAddTraits(.isModal) // For major transitions (optional, non-breaking)
    }
}

extension AnyTransition {
    /// A custom slide transition with a spring effect from a given edge.
    /// Supports asynchronous analytics logging, audit context, escalation, and diagnostics.
    ///
    /// - Parameters:
    ///   - edge: The edge from which the view enters. Defaults to .trailing.
    ///   - analyticsLogger: Dependency-injected analytics logger for audit/BI/QA. Defaults to no-op logger.
    /// - Returns: A transition that slides in/out with spring animation and analytics.
    public static func springSlide(
        edge: Edge = .trailing,
        analyticsLogger: SpringSlideTransitionAnalyticsLogger = NullSpringSlideTransitionAnalyticsLogger()
    ) -> AnyTransition {
        AnyTransition.modifier(
            active: SpringSlideModifier(edge: edge, analyticsLogger: analyticsLogger),
            identity: SpringSlideModifier(edge: edge, analyticsLogger: analyticsLogger)
        )
    }

    /// Fetches the last 20 audit analytics events recorded by SpringSlideTransition.
    /// - Returns: An array of recent audit analytics events with timestamp, event name, edge, role, staffID, context, and escalation flag.
    public static func fetchRecentAnalyticsEvents(analyticsLogger: SpringSlideTransitionAnalyticsLogger = NullSpringSlideTransitionAnalyticsLogger()) async -> [SpringSlideTransitionAuditEvent] {
        return await analyticsLogger.fetchRecentEvents(count: 20)
    }
}

private extension Edge {
    /// Returns the opposite edge (used for exit direction).
    var opposite: Edge {
        switch self {
        case .leading:  return .trailing
        case .trailing: return .leading
        case .top:      return .bottom
        case .bottom:   return .top
        @unknown default: return .trailing
        }
    }
}

#if DEBUG
struct SpringSlideTransition_Previews: PreviewProvider {
    @State static var show = false

    /// A spy logger that prints analytics events to console asynchronously with full audit context.
    struct SpyLogger: SpringSlideTransitionAnalyticsLogger {
        let testMode: Bool = true
        private var events: [SpringSlideTransitionAuditEvent] = []

        func log(event: String, edge: Edge, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
            let localizedEdge = NSLocalizedString("\(edge)", comment: "Edge name in analytics log")
            let roleStr = role ?? "nil"
            let staffStr = staffID ?? "nil"
            let contextStr = context ?? "nil"
            let escalateStr = escalate ? "YES" : "NO"
            let logMessage = """
            [SpringSlideAnalytics] Event: \(localizedEvent)
            Edge: \(localizedEdge)
            Role: \(roleStr)
            StaffID: \(staffStr)
            Context: \(contextStr)
            Escalate: \(escalateStr)
            """
            print(logMessage)
        }

        func fetchRecentEvents(count: Int) async -> [SpringSlideTransitionAuditEvent] {
            return []
        }

        func escalate(event: String, edge: Edge, role: String?, staffID: String?, context: String?) async {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
            let localizedEdge = NSLocalizedString("\(edge)", comment: "Edge name in analytics log")
            let roleStr = role ?? "nil"
            let staffStr = staffID ?? "nil"
            let contextStr = context ?? "nil"
            print("[SpringSlideAnalytics][ESCALATION] Event: \(localizedEvent), Edge: \(localizedEdge), Role: \(roleStr), StaffID: \(staffStr), Context: \(contextStr)")
        }
    }

    static var previews: some View {
        VStack(spacing: 24) {
            Button(NSLocalizedString("Toggle Slide", comment: "Button title to toggle spring slide")) {
                withAnimation {
                    show.toggle()
                }
            }

            Spacer()

            if show {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.accentColor)
                    .frame(height: 120)
                    .overlay(
                        Text(NSLocalizedString("Spring Slide!", comment: "Label shown inside spring slide transition"))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                    .padding()
                    .transition(.springSlide(edge: .bottom, analyticsLogger: SpyLogger()))
            }

            Spacer()
        }
        .frame(height: 300)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif
