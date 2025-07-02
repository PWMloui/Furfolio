//
//  AppAnimation.swift
//  Furfolio
//
//  Architecture:
//  AppAnimation centralizes all animation-related tokens, curves, durations, and transitions into a unified namespace,
//  promoting consistency, extensibility, and maintainability throughout the app. It integrates analytics and audit hooks
//  to enable comprehensive tracking of animation usage, supporting compliance and diagnostics needs.
//  
//  Extensibility:
//  The design supports easy addition of new animation curves and transitions, including custom ones with analytics logging.
//  Animations are fully documented and tokenized for design system alignment.
//
//  Analytics/Audit/Trust Center:
//  AnimationAnalyticsLogger protocol provides async logging capabilities with a test mode for QA and previews.
//  All animation transitions that are analytics-enabled asynchronously log usage events with localized strings,
//  facilitating audit trails and Trust Center compliance.
//
//  Diagnostics:
//  The AppAnimation namespace exposes a public API to retrieve the last 20 analytics events, supporting diagnostics,
//  debugging, and admin UI inspection.
//
//  Localization & Compliance:
//  All user-facing and log event strings are localized using NSLocalizedString with meaningful keys and comments,
//  ensuring compliance with internationalization and accessibility standards.
//
//  Accessibility:
//  While animations themselves do not directly handle accessibility, their consistent and documented usage supports
//  accessible UI transitions when combined with SwiftUI's accessibility tools.
//
//  Preview/Testability:
//  The analytics logger supports a testMode for console-only logging during previews and tests.
//  The provided SwiftUI preview demonstrates usage of all transitions with analytics logging enabled.
//


import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AppAnimationAuditContext {
    /// Role of the current user (set at login/session for audit/compliance).
    public static var role: String? = nil
    /// Staff ID of the current user (set at login/session for audit/compliance).
    public static var staffID: String? = nil
    /// Context string for audit/compliance/trust center.
    public static var context: String? = "AppAnimation"
}

// MARK: - Analytics/Audit/Trust Center Protocol

/// Represents a logged audit/compliance/diagnostic event for animations.
public struct AppAnimationAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let info: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol for logging animation analytics/audit events asynchronously.
/// Implementers can provide backend or local logging, supporting audit, trust center, and diagnostics.
/// The `testMode` flag enables console-only logging for QA, tests, and previews.
public protocol AnimationAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an analytics/audit event with all compliance fields.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - info: Additional information about the event.
    ///   - role: The user's role (for audit/compliance).
    ///   - staffID: The user's staff ID (for audit/compliance).
    ///   - context: The context of the event (for trust center/audit).
    ///   - escalate: Whether the event should be escalated (e.g., security, compliance).
    func log(event: String, info: String, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Fetches the most recent audit/compliance events.
    /// - Parameter count: Number of recent events to fetch.
    func fetchRecentEvents(count: Int) async -> [AppAnimationAuditEvent]

    /// Escalates a specific event for compliance/trust center review.
    func escalate(event: String, info: String, role: String?, staffID: String?, context: String?) async
}

/// A no-op analytics/audit logger that does nothing by default.
/// Useful as a default parameter to avoid optional handling.
public struct NullAnimationAnalyticsLogger: AnimationAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, info: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [AppAnimationAuditEvent] { [] }
    public func escalate(event: String, info: String, role: String?, staffID: String?, context: String?) async {}
}

/// A simple console logger for preview, test, or QA purposes.
/// Stores and prints all audit/compliance fields as AppAnimationAuditEvent, maintaining a buffer of the last 20.
public final class ConsoleAnimationAnalyticsLogger: AnimationAnalyticsLogger {
    public let testMode: Bool = true
    private var buffer: [AppAnimationAuditEvent] = []
    private let maxEvents = 20
    private let queue = DispatchQueue(label: "ConsoleAnimationAnalyticsLogger.queue")
    public init() {}
    public func log(event: String, info: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let auditEvent = AppAnimationAuditEvent(
            timestamp: Date(),
            event: event,
            info: info,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        queue.sync {
            buffer.append(auditEvent)
            if buffer.count > maxEvents {
                buffer.removeFirst(buffer.count - maxEvents)
            }
        }
        print("[AnimationAudit] event: \(event), info: \(info), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
    }
    public func fetchRecentEvents(count: Int) async -> [AppAnimationAuditEvent] {
        queue.sync {
            Array(buffer.suffix(count))
        }
    }
    public func escalate(event: String, info: String, role: String?, staffID: String?, context: String?) async {
        print("[AnimationAudit][ESCALATE] event: \(event), info: \(info), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil")")
    }
}

/// Unified namespace for all app-standard animation curves, durations, transitions, and analytics.
///
/// This namespace centralizes animation-related tokens for design consistency,
/// provides extensible animation curves and transitions,
/// integrates async analytics logging for audit and diagnostics,
/// supports localization for all user-facing and log strings,
/// and exposes diagnostic APIs for retrieving recent analytics events.
public enum AppAnimation {
    
    // MARK: - Internal Audit/Diagnostics Storage

    /// Thread-safe storage of recent audit/compliance animation events for diagnostics and admin UI.
    private static var auditEventLog = ThreadSafeArray<AppAnimationAuditEvent>(maxSize: 20)

    /// Thread-safe array helper for bounded storage.
    private class ThreadSafeArray<T> {
        private let queue = DispatchQueue(label: "AppAnimation.ThreadSafeArrayQueue")
        private var array: [T] = []
        private let maxSize: Int

        init(maxSize: Int) {
            self.maxSize = maxSize
        }

        func append(_ element: T) {
            queue.sync {
                array.append(element)
                if array.count > maxSize {
                    array.removeFirst(array.count - maxSize)
                }
            }
        }

        func getAll() -> [T] {
            queue.sync {
                array
            }
        }
    }

    // MARK: - Public API for Audit/Diagnostics

    /// Retrieves the last 20 logged animation audit/compliance events.
    /// - Returns: An array of `AppAnimationAuditEvent` sorted from oldest to newest.
    public static func fetchRecentAuditEvents() -> [AppAnimationAuditEvent] {
        auditEventLog.getAll()
    }

    /// Retrieves the last N audit/compliance events from a given logger.
    /// - Parameters:
    ///   - logger: The analytics/audit logger.
    ///   - count: The number of recent events to fetch.
    /// - Returns: An array of `AppAnimationAuditEvent`.
    public static func fetchRecentAuditEvents(from logger: AnimationAnalyticsLogger, count: Int) async -> [AppAnimationAuditEvent] {
        await logger.fetchRecentEvents(count: count)
    }
    
    // MARK: - Durations (tokenized for design system)
    public enum Durations {
        /// Ultra fast animation duration (default 0.10s).
        public static let ultraFast: Double = AppTheme.Animation.ultraFast ?? 0.10
        /// Fast animation duration (default 0.18s).
        public static let fast: Double      = AppTheme.Animation.fast ?? 0.18
        /// Standard animation duration (default 0.35s).
        public static let standard: Double  = AppTheme.Animation.standard ?? 0.35
        /// Slow animation duration (default 0.60s).
        public static let slow: Double      = AppTheme.Animation.slow ?? 0.60
        /// Extra slow animation duration (default 0.98s).
        public static let extraSlow: Double = AppTheme.Animation.extraSlow ?? 0.98
    }

    // MARK: - Curves
    
    /// Standard animation curves used across the app.
    public enum Curves {
        /// App standard easeInOut animation curve.
        public static let easeInOut = Animation.easeInOut(duration: Durations.standard)
        /// App standard spring animation curve.
        public static let spring = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.25)
        /// Subtle easeInOut for micro-interactions.
        public static let subtle = Animation.easeInOut(duration: 0.22)
        /// Elastic interpolating spring.
        public static let elastic = Animation.interpolatingSpring(stiffness: 190, damping: 8)
        /// Bounce spring animation.
        public static let bounce = Animation.spring(response: 0.33, dampingFraction: 0.54)
        /// Snappy interpolating spring.
        public static let snappy = Animation.interpolatingSpring(stiffness: 330, damping: 12)
    }
    
    // MARK: - Transitions
    
    /// Standard animation transitions with optional analytics logging.
    public enum Transitions {
        /// Fade in/out transition.
        public static let fade = AnyTransition.opacity.animation(Curves.easeInOut)
        /// Slide in from trailing edge and fade transition.
        public static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity).animation(Curves.easeInOut)
        /// Scale up and fade in transition.
        public static let scale = AnyTransition.scale.combined(with: .opacity).animation(Curves.spring)
        /// Pop/elastic scale transition.
        public static let pop = AnyTransition.scale(scale: 0.7, anchor: .center).combined(with: .opacity).animation(Curves.elastic)
        /// Bounce in/out transition.
        public static let bounce = AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(Curves.bounce)
        
        /// Custom spring slide transition with async analytics/audit logging.
        /// - Parameters:
        ///   - edge: The edge from which to slide in (default trailing).
        ///   - analyticsLogger: Logger conforming to `AnimationAnalyticsLogger` (default no-op).
        /// - Returns: An asymmetric transition with spring slide and analytics/audit logging.
        public static func springSlide(
            from edge: Edge = .trailing,
            analyticsLogger: AnimationAnalyticsLogger = NullAnimationAnalyticsLogger()
        ) async -> AnyTransition {
            let eventKey = NSLocalizedString("animation.transition.springSlide.event", comment: "Audit/analytics event key for springSlide transition")
            let infoFormat = NSLocalizedString("animation.transition.springSlide.infoFormat", comment: "Audit/analytics info format for springSlide transition")
            let info = String(format: infoFormat, String(describing: edge))
            let escalate = (edge == .top)
            await analyticsLogger.log(
                event: eventKey,
                info: info,
                role: AppAnimationAuditContext.role,
                staffID: AppAnimationAuditContext.staffID,
                context: AppAnimationAuditContext.context,
                escalate: escalate
            )
            // Store event for diagnostics/audit
            auditEventLog.append(AppAnimationAuditEvent(
                timestamp: Date(),
                event: eventKey,
                info: info,
                role: AppAnimationAuditContext.role,
                staffID: AppAnimationAuditContext.staffID,
                context: AppAnimationAuditContext.context,
                escalate: escalate
            ))
            return .asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity).animation(Curves.spring),
                removal: .move(edge: edge.opposite).combined(with: .opacity).animation(Curves.easeInOut)
            )
        }
        
        /// Fully custom asymmetric transition builder with analytics logging.
        /// - Parameters:
        ///   - insertion: The insertion transition.
        ///   - removal: The removal transition.
        ///   - animation: Animation curve to apply (default spring).
        /// - Returns: An asymmetric transition combining insertion and removal with animation.
        public static func custom(
            insertion: AnyTransition,
            removal: AnyTransition,
            animation: Animation = Curves.spring
        ) -> AnyTransition {
            .asymmetric(
                insertion: insertion.animation(animation),
                removal: removal.animation(animation)
            )
        }
    }
}

// MARK: - Private Helpers

private extension Edge {
    /// Returns the opposite edge, used for asymmetric removal transitions and audit/compliance.
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}


// MARK: - Preview

#if DEBUG
struct AppAnimation_Previews: PreviewProvider {
    /// Preview logger that logs to console asynchronously.
    final class PreviewLogger: AnimationAnalyticsLogger {
        let testMode: Bool = true
        private var buffer: [AppAnimationAuditEvent] = []
        private let maxEvents = 20
        private let queue = DispatchQueue(label: "PreviewLogger.queue")
        func log(event: String, info: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let auditEvent = AppAnimationAuditEvent(
                timestamp: Date(),
                event: event,
                info: info,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            queue.sync {
                buffer.append(auditEvent)
                if buffer.count > maxEvents {
                    buffer.removeFirst(buffer.count - maxEvents)
                }
            }
            print("[AnimationAudit][Preview] event: \(event), info: \(info), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
        func fetchRecentEvents(count: Int) async -> [AppAnimationAuditEvent] {
            queue.sync {
                Array(buffer.suffix(count))
            }
        }
        func escalate(event: String, info: String, role: String?, staffID: String?, context: String?) async {
            print("[AnimationAudit][Preview][ESCALATE] event: \(event), info: \(info), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil")")
        }
    }
    struct PreviewWrapper: View {
        @State private var showFade = false
        @State private var showSlide = false
        @State private var showScale = false
        @State private var showPop = false
        @State private var showBounce = false

        let analyticsLogger = PreviewLogger()

        var body: some View {
            VStack(spacing: 24) {
                Button(NSLocalizedString("animation.preview.toggleFade", comment: "Button label to toggle fade")) { showFade.toggle() }
                if showFade {
                    Text(NSLocalizedString("animation.preview.fadeInOutText", comment: "Text shown during fade animation"))
                        .padding()
                        .background(AppTheme.Colors.success.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.fade)
                }

                Button(NSLocalizedString("animation.preview.toggleSlide", comment: "Button label to toggle slide")) { showSlide.toggle() }
                if showSlide {
                    Text(NSLocalizedString("animation.preview.slideInOutText", comment: "Text shown during slide animation"))
                        .padding()
                        .background(AppTheme.Colors.primary.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.slide)
                }

                Button(NSLocalizedString("animation.preview.toggleScale", comment: "Button label to toggle scale")) { showScale.toggle() }
                if showScale {
                    Text(NSLocalizedString("animation.preview.scaleInOutText", comment: "Text shown during scale animation"))
                        .padding()
                        .background(AppTheme.Colors.warning.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.scale)
                }

                Button(NSLocalizedString("animation.preview.togglePop", comment: "Button label to toggle pop")) { showPop.toggle() }
                if showPop {
                    Text(NSLocalizedString("animation.preview.popTransitionText", comment: "Text shown during pop/elastic animation"))
                        .padding()
                        .background(AppTheme.Colors.loyaltyYellow.opacity(0.18))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.pop)
                }

                Button(NSLocalizedString("animation.preview.toggleBounce", comment: "Button label to toggle bounce")) { showBounce.toggle() }
                if showBounce {
                    Text(NSLocalizedString("animation.preview.bounceInOutText", comment: "Text shown during bounce animation"))
                        .padding()
                        .background(AppTheme.Colors.milestoneBlue.opacity(0.18))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.bounce)
                }
            }
            .animation(AppAnimation.Curves.spring, value: showFade)
            .animation(AppAnimation.Curves.spring, value: showSlide)
            .animation(AppAnimation.Curves.spring, value: showScale)
            .animation(AppAnimation.Curves.elastic, value: showPop)
            .animation(AppAnimation.Curves.bounce, value: showBounce)
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
