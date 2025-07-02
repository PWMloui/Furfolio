//
//  FadeInOutViewModifier.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, accessible, modular, preview/testable, and robust.
//
//  Architecture & Extensibility:
//  FadeInOutViewModifier is designed as a modular SwiftUI ViewModifier that enables smooth fade-in/out animations
//  with tokenized animation parameters for consistency across the app. It supports extensibility via customizable
//  animation curves, delays, and durations.
//
//  Analytics/Audit/Trust Center Integration:
//  The modifier integrates with an asynchronous analytics logger protocol, allowing for audit-ready tracking of
//  visibility changes and appearances. It supports a test mode for console-only logging in QA, tests, and previews.
//
//  Diagnostics & Localization:
//  All user-facing strings and analytics event keys are localized using NSLocalizedString to ensure compliance and
//  ease of translation. The modifier exposes a public API to retrieve the last 20 analytics events for diagnostics,
//  admin UI, or Trust Center review.
//
//  Accessibility & Compliance:
//  Accessibility labels and visibility states are managed to ensure compliance with accessibility standards,
//  hiding content appropriately and providing descriptive labels.
//
//  Preview & Testability:
//  Includes preview providers with spy loggers to facilitate UI testing and analytics verification in development.
//
//  Maintainers should ensure that any extensions or modifications retain these principles for consistency and compliance.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct FadeInOutAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "FadeInOutViewModifier"
}

// MARK: - Analytics/Audit Protocol

/// Struct representing an audit event for FadeInOutViewModifier.
/// Contains detailed context for compliance and trust center review.
public struct FadeInOutAuditEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let isVisible: Bool
    public let label: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol defining asynchronous analytics logging for FadeInOutViewModifier.
/// Conforms to concurrency best practices and supports test mode for console-only logging.
public protocol FadeInOutAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    /// Asynchronously logs an event with visibility state, optional label, and audit context.
    /// - Parameters:
    ///   - event: The event key string.
    ///   - isVisible: Current visibility state.
    ///   - label: Optional accessibility label or context.
    ///   - role: Optional user role for audit context.
    ///   - staffID: Optional staff identifier for audit context.
    ///   - context: Optional context string for audit logging.
    ///   - escalate: Flag indicating if the event should be escalated for risk/critical tracking.
    func log(event: String, isVisible: Bool, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    /// Retrieves the last 20 logged audit events for diagnostics or admin UI.
    /// - Returns: An array of audit event structs.
    func fetchRecentEvents() async -> [FadeInOutAuditEvent]
}

/// A no-op analytics logger implementation for default usage.
/// Supports testMode flag for console-only logging in QA/tests/previews.
public struct NullFadeInOutAnalyticsLogger: FadeInOutAnalyticsLogger {
    public let testMode: Bool
    
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    public func log(event: String, isVisible: Bool, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            let eventString = NSLocalizedString(event, comment: "Analytics event key")
            let visibilityString = isVisible
                ? NSLocalizedString("Visible", comment: "Visibility state for analytics")
                : NSLocalizedString("Hidden", comment: "Visibility state for analytics")
            let labelString = label ?? ""
            print("[FadeInOutAnalytics] \(eventString): \(visibilityString) \(labelString) Role:\(role ?? "N/A") StaffID:\(staffID ?? "N/A") Context:\(context ?? "N/A") Escalate:\(escalate)")
        }
        // No-op for production
    }
    
    public func fetchRecentEvents() async -> [FadeInOutAuditEvent] {
        return []
    }
}

// MARK: - FadeInOutViewModifier

/// A view modifier that applies a fade-in/out transition based on a Boolean binding.
/// Use for simple appear/disappear animations with optional delays, audit-compliant analytics logging, and tokenized curves/durations.
///
/// Supports asynchronous analytics logging, localization, accessibility compliance,
/// and diagnostics via recent audit event retrieval.
///
/// - Note: All user-facing strings and analytics event keys are localized.
/// - SeeAlso: FadeInOutAnalyticsLogger
struct FadeInOutViewModifier: ViewModifier {
    @Binding var isVisible: Bool
    
    /// Duration of the fade animation (tokenized).
    var fadeDuration: Double = AppAnimation.Durations.standard
    /// Optional delay before fade in (tokenized).
    var fadeInDelay: Double = 0.0
    /// Optional delay before fade out (tokenized).
    var fadeOutDelay: Double = 0.0
    /// Optional animation curve (tokenized).
    var curve: Animation = AppAnimation.Curves.easeInOut
    /// Optional accessibility label.
    var accessibilityLabel: String? = nil
    /// Optional analytics logger (preview/test/enterprise/QA).
    var analyticsLogger: FadeInOutAnalyticsLogger = NullFadeInOutAnalyticsLogger()
    
    /// Internal storage of recent analytics audit events for diagnostics.
    @State private var recentEvents: [FadeInOutAuditEvent] = []
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(
                curve
                    .speed(1.0)
                    .delay(isVisible ? fadeInDelay : fadeOutDelay)
                    .duration(fadeDuration),
                value: isVisible
            )
            .accessibilityHidden(!isVisible)
            .accessibilityLabel(accessibilityLabel != nil ? Text(accessibilityLabel!) : nil)
            .task(id: isVisible) { // Use .task for async onChange equivalent
                await logVisibilityChange(isVisible)
            }
            .onAppear {
                Task {
                    await logAppear()
                }
            }
    }
    
    /// Determines if the event should be escalated based on label content.
    /// Escalate if label contains "Critical", "Risk", or "Warning" (case-insensitive).
    private func shouldEscalate(label: String?) -> Bool {
        guard let label = label?.lowercased() else { return false }
        return label.contains("critical") || label.contains("risk") || label.contains("warning")
    }
    
    /// Asynchronously logs visibility change event and updates recent events.
    /// - Parameter newValue: The new visibility state.
    private func logVisibilityChange(_ newValue: Bool) async {
        let eventKey = NSLocalizedString("fadeInOut_changed", comment: "Analytics event key for visibility change")
        let escalateFlag = shouldEscalate(label: accessibilityLabel)
        await analyticsLogger.log(
            event: eventKey,
            isVisible: newValue,
            label: accessibilityLabel,
            role: FadeInOutAuditContext.role,
            staffID: FadeInOutAuditContext.staffID,
            context: FadeInOutAuditContext.context,
            escalate: escalateFlag
        )
        await updateRecentEvents(eventKey: eventKey, isVisible: newValue, escalate: escalateFlag)
    }
    
    /// Asynchronously logs appear event and updates recent events.
    private func logAppear() async {
        let eventKey = NSLocalizedString("fadeInOut_appear", comment: "Analytics event key for view appear")
        let escalateFlag = shouldEscalate(label: accessibilityLabel)
        await analyticsLogger.log(
            event: eventKey,
            isVisible: isVisible,
            label: accessibilityLabel,
            role: FadeInOutAuditContext.role,
            staffID: FadeInOutAuditContext.staffID,
            context: FadeInOutAuditContext.context,
            escalate: escalateFlag
        )
        await updateRecentEvents(eventKey: eventKey, isVisible: isVisible, escalate: escalateFlag)
    }
    
    /// Updates the internal recent audit events list for diagnostics.
    /// - Parameters:
    ///   - eventKey: The event key string.
    ///   - isVisible: The visibility state.
    ///   - escalate: The escalate flag for audit event.
    private func updateRecentEvents(eventKey: String, isVisible: Bool, escalate: Bool) async {
        let event = FadeInOutAuditEvent(
            timestamp: Date(),
            event: eventKey,
            isVisible: isVisible,
            label: accessibilityLabel,
            role: FadeInOutAuditContext.role,
            staffID: FadeInOutAuditContext.staffID,
            context: FadeInOutAuditContext.context,
            escalate: escalate
        )
        await MainActor.run {
            recentEvents.append(event)
            if recentEvents.count > 20 {
                recentEvents.removeFirst(recentEvents.count - 20)
            }
        }
    }
    
    /// Public API: Fetches the last 20 analytics audit events for diagnostics or admin UI.
    /// - Returns: An array of localized audit event structs.
    public func fetchRecentEvents() async -> [FadeInOutAuditEvent] {
        return await analyticsLogger.fetchRecentEvents()
    }
}

extension View {
    /// Applies a fade-in/out animation based on a Boolean binding, with tokenized defaults and audit-compliant analytics.
    ///
    /// - Parameters:
    ///   - isVisible: Binding to control visibility state.
    ///   - fadeDuration: Duration of fade animation (default tokenized).
    ///   - fadeInDelay: Optional delay before fade in.
    ///   - fadeOutDelay: Optional delay before fade out.
    ///   - curve: Animation curve to use.
    ///   - accessibilityLabel: Optional accessibility label for the view.
    ///   - analyticsLogger: Analytics logger instance for audit and diagnostics.
    /// - Returns: A view modified with fade-in/out animation and audit-ready analytics.
    func fadeInOut(
        isVisible: Binding<Bool>,
        fadeDuration: Double = AppAnimation.Durations.standard,
        fadeInDelay: Double = 0.0,
        fadeOutDelay: Double = 0.0,
        curve: Animation = AppAnimation.Curves.easeInOut,
        accessibilityLabel: String? = nil,
        analyticsLogger: FadeInOutAnalyticsLogger = NullFadeInOutAnalyticsLogger()
    ) -> some View {
        self.modifier(FadeInOutViewModifier(
            isVisible: isVisible,
            fadeDuration: fadeDuration,
            fadeInDelay: fadeInDelay,
            fadeOutDelay: fadeOutDelay,
            curve: curve,
            accessibilityLabel: accessibilityLabel,
            analyticsLogger: analyticsLogger
        ))
    }
}

// MARK: - Preview

#if DEBUG
struct FadeInOutViewModifier_Previews: PreviewProvider {
    /// Spy logger implementation for preview/testing that logs to console.
    struct SpyLogger: FadeInOutAnalyticsLogger {
        public let testMode: Bool = true
        
        func log(event: String, isVisible: Bool, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let eventString = NSLocalizedString(event, comment: "Analytics event key")
            let visibilityString = isVisible
                ? NSLocalizedString("Visible", comment: "Visibility state for analytics")
                : NSLocalizedString("Hidden", comment: "Visibility state for analytics")
            let labelString = label ?? ""
            print("[FadeInOutAnalytics] \(eventString): \(visibilityString) \(labelString) Role:\(role ?? "N/A") StaffID:\(staffID ?? "N/A") Context:\(context ?? "N/A") Escalate:\(escalate)")
        }
        
        func fetchRecentEvents() async -> [FadeInOutAuditEvent] {
            []
        }
    }
    
    struct PreviewWrapper: View {
        @State private var show = false
        
        var body: some View {
            VStack(spacing: 30) {
                Button(show ? NSLocalizedString("Hide", comment: "Button title to hide content") : NSLocalizedString("Show", comment: "Button title to show content")) {
                    withAnimation { show.toggle() }
                }
                
                Text(NSLocalizedString("Example 1", comment: "Example label 1"))
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(10)
                    .fadeInOut(
                        isVisible: $show,
                        accessibilityLabel: NSLocalizedString("Green Box", comment: "Accessibility label for green box"),
                        analyticsLogger: SpyLogger()
                    )
                
                Text(NSLocalizedString("Example 2 - Delayed Fade", comment: "Example label 2 with delayed fade"))
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                    .fadeInOut(
                        isVisible: $show,
                        fadeDuration: 0.6,
                        fadeInDelay: 0.2,
                        accessibilityLabel: NSLocalizedString("Blue Box", comment: "Accessibility label for blue box"),
                        analyticsLogger: SpyLogger()
                    )
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif
