//
//  ShakeAnimationModifier.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, haptic/accessible, modular, preview/testable, robust.
//
//  Architecture & Extensibility:
//  ShakeAnimationModifier is designed as a reusable SwiftUI GeometryEffect that applies a horizontal shake animation.
//  It supports modular customization via design tokens for amplitude and oscillations, and integrates seamlessly with SwiftUI views.
//
//  Analytics/Audit/Trust Center Hooks:
//  The modifier includes an asynchronous analytics logging protocol (ShakeAnimationAnalyticsLogger) that supports audit trails,
//  BI, QA, and Trust Center compliance. It records shake trigger events with relevant parameters, supports escalation of critical events,
//  and exposes recent audit events for diagnostics and administrative UIs.
//
//  Diagnostics & Localization:
//  All user-facing and log event strings are localized using NSLocalizedString for compliance and internationalization.
//  A public API exposes the last 20 analytics events to support diagnostics and administrative UIs.
//
//  Accessibility & Compliance:
//  Accessibility labels, hints, and values are provided and customizable to ensure compliance with accessibility standards.
//  Haptic feedback is optionally triggered on shake events for improved UX.
//
//  Preview & Testability:
//  Includes a Null analytics logger for default usage and a SpyLogger for testing and previewing analytics events.
//  The analytics logger supports a testMode for console-only logging in QA and previews.
//
//  This comprehensive design ensures maintainability, extensibility, and compliance with organizational standards.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ShakeAnimationAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ShakeAnimationModifier"
}

// MARK: - Analytics/Audit Protocol

/// Represents an individual audit event for shake animation analytics.
public struct ShakeAnimationAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let trigger: Int
    public let amplitude: CGFloat
    public let shakes: Int
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol defining asynchronous analytics logging for shake animation events.
/// Supports concurrency, escalation of critical events, and test mode for console-only logging.
public protocol ShakeAnimationAnalyticsLogger {
    /// Indicates whether analytics logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs a shake animation event.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - trigger: The integer trigger value causing the shake.
    ///   - amplitude: The shake amplitude in points.
    ///   - shakes: The number of shake oscillations.
    ///   - role: Role of the current user/session.
    ///   - staffID: Staff ID associated with the current user/session.
    ///   - context: Context string identifying the source or component.
    ///   - escalate: Flag indicating if this event should be escalated for audit/trust center.
    func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Fetch recent audit events asynchronously.
    /// - Parameter count: Number of recent events to fetch.
    /// - Returns: Array of recent audit events.
    func fetchRecentEvents(count: Int) async -> [ShakeAnimationAuditEvent]

    /// Escalate a critical event for audit/trust center purposes.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - trigger: The integer trigger value causing the shake.
    ///   - amplitude: The shake amplitude in points.
    ///   - shakes: The number of shake oscillations.
    ///   - role: Role of the current user/session.
    ///   - staffID: Staff ID associated with the current user/session.
    ///   - context: Context string identifying the source or component.
    func escalate(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?) async
}

/// Default no-op analytics logger.
/// Used when no analytics logging is required.
public struct NullShakeAnimationAnalyticsLogger: ShakeAnimationAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [ShakeAnimationAuditEvent] { [] }
    public func escalate(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - ShakeAnimationModifier

/// A geometry effect for horizontal shake animation with audit-ready analytics, haptics, accessibility, and localization support.
/// Supports asynchronous analytics logging, escalation of critical events, and diagnostics.
/// - Note: Designed for extensibility with design tokens and customizable parameters.
struct ShakeAnimationModifier: GeometryEffect {
    /// Unique value that increments to trigger the shake animation.
    var trigger: Int

    /// Horizontal displacement of the shake (in points). Tokenized, fallback to 12.
    var amplitude: CGFloat = AppSpacing.shakeAmplitude ?? 12

    /// Number of shake oscillations. Tokenized, fallback to 4.
    var shakes: Int = AppTheme.Animation.shakeOscillations ?? 4

    /// Optional analytics logger for BI/QA/Trust Center.
    var analyticsLogger: ShakeAnimationAnalyticsLogger = NullShakeAnimationAnalyticsLogger()

    /// Whether to trigger haptic feedback on shake (iOS only).
    var haptics: Bool = true

    /// Optional accessibility label.
    var accessibilityLabel: String? = nil

    /// Internal storage for last 20 analytics event strings for diagnostics.
    private static var eventHistory: [String] = []

    /// Required by `GeometryEffect` to animate on trigger change.
    var animatableData: CGFloat {
        get { CGFloat(trigger) }
        set { }
    }

    /// Computes the translation transform for the shake effect.
    /// - Parameter size: The size of the view.
    /// - Returns: ProjectionTransform representing the horizontal shake translation.
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(.pi * CGFloat(shakes) * animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }

    // MARK: - Animate on trigger change

    /// Applies the shake effect and handles analytics, haptics, and accessibility.
    /// - Parameter content: The content view to apply the shake effect to.
    /// - Returns: A view with shake animation and related features applied.
    func body(content: Content) -> some View {
        content
            .modifier(self)
            .accessibilityLabel(
                accessibilityLabel != nil
                ? Text(accessibilityLabel!)
                : Text(NSLocalizedString("ShakeAnimation_DefaultAccessibilityLabel",
                                         comment: "Default accessibility label for shake animation")))
            .accessibilityHint(Text(NSLocalizedString("ShakeAnimation_AccessibilityHint",
                                                      comment: "Accessibility hint describing the shake animation effect")))
            .accessibilityValue(Text(trigger % 2 == 0
                                    ? NSLocalizedString("ShakeAnimation_AccessibilityValueStable",
                                                        comment: "Accessibility value indicating stable state")
                                    : NSLocalizedString("ShakeAnimation_AccessibilityValueShaking",
                                                        comment: "Accessibility value indicating shaking state")))
            .onChange(of: trigger) { newValue in
                let escalateEvent = amplitude > 20 || shakes > 7
                Task {
                    await analyticsLogger.log(
                        event: NSLocalizedString("ShakeAnimation_EventTriggered",
                                                 comment: "Analytics event name for shake triggered"),
                        trigger: newValue,
                        amplitude: amplitude,
                        shakes: shakes,
                        role: ShakeAnimationAuditContext.role,
                        staffID: ShakeAnimationAuditContext.staffID,
                        context: ShakeAnimationAuditContext.context,
                        escalate: escalateEvent
                    )
                    ShakeAnimationModifier.storeEvent(
                        event: String(format: NSLocalizedString("ShakeAnimation_EventLogFormat",
                                                               comment: "Formatted log for shake event"),
                                      newValue, amplitude, shakes)
                    )
                    if escalateEvent {
                        await analyticsLogger.escalate(
                            event: NSLocalizedString("ShakeAnimation_EventEscalated",
                                                     comment: "Analytics event name for escalated shake event"),
                            trigger: newValue,
                            amplitude: amplitude,
                            shakes: shakes,
                            role: ShakeAnimationAuditContext.role,
                            staffID: ShakeAnimationAuditContext.staffID,
                            context: ShakeAnimationAuditContext.context
                        )
                    }
                }
                if haptics {
                    ShakeAnimationModifier.triggerHaptic()
                }
            }
    }

    /// Stores an analytics event string in the static event history, maintaining a max of 20 entries.
    /// - Parameter event: The event string to store.
    private static func storeEvent(event: String) {
        DispatchQueue.main.async {
            if eventHistory.count >= 20 {
                eventHistory.removeFirst()
            }
            eventHistory.append(event)
        }
    }

    /// Public API to fetch the last N audit events asynchronously using the configured analytics logger.
    /// - Parameter count: Number of recent audit events to retrieve.
    /// - Returns: Array of audit events.
    public static func fetchLastAuditEvents(count: Int = 20, logger: ShakeAnimationAnalyticsLogger = NullShakeAnimationAnalyticsLogger()) async -> [ShakeAnimationAuditEvent] {
        await logger.fetchRecentEvents(count: count)
    }

    /// Haptic feedback (iOS only, non-blocking).
    static func triggerHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Apply a horizontal shake animation with design tokens, audit-ready analytics, haptics, accessibility, and localization.
    /// - Parameters:
    ///   - trigger: Increment to trigger the animation.
    ///   - amplitude: The shake distance (tokenized, fallback to 12).
    ///   - shakes: Number of oscillations (tokenized, fallback to 4).
    ///   - haptics: Whether to trigger haptic feedback (default: true).
    ///   - analyticsLogger: Protocol-based logger for BI/QA/Trust Center (default: Null).
    ///   - accessibilityLabel: Custom accessibility label.
    /// - Returns: A view with shake animation applied.
    func shake(
        trigger: Int,
        amplitude: CGFloat = AppSpacing.shakeAmplitude ?? 12,
        shakes: Int = AppTheme.Animation.shakeOscillations ?? 4,
        haptics: Bool = true,
        analyticsLogger: ShakeAnimationAnalyticsLogger = NullShakeAnimationAnalyticsLogger(),
        accessibilityLabel: String? = nil
    ) -> some View {
        self.modifier(
            ShakeAnimationModifier(
                trigger: trigger,
                amplitude: amplitude,
                shakes: shakes,
                analyticsLogger: analyticsLogger,
                haptics: haptics,
                accessibilityLabel: accessibilityLabel
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ShakeAnimationModifier_Previews: PreviewProvider {
    /// Spy logger for preview/testing that logs asynchronously and supports test mode.
    struct SpyLogger: ShakeAnimationAnalyticsLogger {
        let testMode: Bool = true
        private var events: [ShakeAnimationAuditEvent] = []

        func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            if testMode {
                print("[ShakeAnalytics] \(event) trigger:\(trigger) amp:\(amplitude) shakes:\(shakes) escalate:\(escalate) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil")")
            }
            // Simulate async logging delay if needed
            await Task.yield()
        }

        func fetchRecentEvents(count: Int) async -> [ShakeAnimationAuditEvent] {
            // Return empty for preview
            []
        }

        func escalate(event: String, trigger: Int, amplitude: CGFloat, shakes: Int, role: String?, staffID: String?, context: String?) async {
            if testMode {
                print("[ShakeAnalytics][Escalate] \(event) trigger:\(trigger) amp:\(amplitude) shakes:\(shakes) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil")")
            }
            await Task.yield()
        }
    }
    struct PreviewWrapper: View {
        @State private var trigger = 0

        var body: some View {
            VStack(spacing: 30) {
                Button(NSLocalizedString("ShakeAnimation_ButtonTitle",
                                         comment: "Button title to trigger shake animation")) {
                    trigger += 1
                }

                Text(NSLocalizedString("ShakeAnimation_PreviewText",
                                       comment: "Text to demonstrate shake animation"))
                    .font(.headline)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                    .shake(
                        trigger: trigger,
                        analyticsLogger: SpyLogger(),
                        accessibilityLabel: NSLocalizedString("ShakeAnimation_PreviewAccessibilityLabel",
                                                              comment: "Accessibility label for shaking orange box in preview")
                    )
                    .accessibilityHint(NSLocalizedString("ShakeAnimation_PreviewAccessibilityHint",
                                                         comment: "Accessibility hint for preview shaking box"))
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif
