// SuccessCheckmarkView.swift

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SuccessCheckmarkAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SuccessCheckmarkView"
}

/**
 `SuccessCheckmarkView` is a highly extensible and accessible animated checkmark view designed for confirming successful user actions such as form submissions or task completions.

 ## Architecture and Extensibility
 This view leverages SwiftUI's declarative paradigm with customizable design tokens for colors, sizes, and animation timings, enabling seamless theming and branding. It supports dependency injection of analytics loggers and completion callbacks, facilitating testing, previewing, and integration with various analytics or audit systems.

 ## Analytics / Audit / Trust Center Hooks
 The view integrates an asynchronous analytics logging protocol, `SuccessCheckmarkAnalyticsLogger`, which supports concurrency and future-proof event tracking. It includes a `testMode` flag for console-only logging during QA, tests, or previews. All analytics events are localized and stored internally with a public API to retrieve the last 20 events for diagnostics or administrative inspection.

 ## Diagnostics and Localization
 User-facing strings and log event messages are fully localized using `NSLocalizedString` with explicit keys and comments to ensure compliance and ease of translation. The view provides detailed accessibility labels and hints, supporting VoiceOver and other assistive technologies.

 ## Accessibility and Compliance
 Accessibility traits and live region updates are applied to ensure the checkmark is announced appropriately. The design follows best practices for visual clarity, animation smoothness, and semantic clarity, supporting compliance with accessibility standards.

 ## Preview and Testability
 The view includes a robust preview provider with a spy logger implementation for live analytics event inspection during development. The modular design and state management facilitate unit testing and UI testing.

 This documentation aims to guide future maintainers in understanding, extending, and integrating `SuccessCheckmarkView` within larger applications, ensuring maintainability, compliance, and observability.
 */

// MARK: - Analytics/Audit Logger Protocol

/// Protocol defining asynchronous analytics logging for `SuccessCheckmarkView` with audit context.
public protocol SuccessCheckmarkAnalyticsLogger {
    /// Indicates whether the logger is running in test mode, enabling console-only logging.
    var testMode: Bool { get set }
    
    /**
     Asynchronously logs an analytics event related to the success checkmark, including audit context.

     - Parameters:
       - event: The event identifier string.
       - color: The color used in the checkmark animation.
       - size: The size of the checkmark.
       - delay: The animation delay before the event.
       - role: The user role from audit context.
       - staffID: The staff ID from audit context.
       - context: The context string from audit context.
       - escalate: Flag indicating if the event should be escalated based on severity.
     */
    func log(event: String, color: Color, size: CGFloat, delay: Double, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

/// A no-operation analytics logger that performs no logging.
public struct NullSuccessCheckmarkAnalyticsLogger: SuccessCheckmarkAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, color: Color, size: CGFloat, delay: Double, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
}

/// A simple analytics logger that logs events to the console when in test mode, including audit context.
public class ConsoleSuccessCheckmarkAnalyticsLogger: SuccessCheckmarkAnalyticsLogger {
    public var testMode: Bool = true
    public init(testMode: Bool = true) {
        self.testMode = testMode
    }
    public func log(event: String, color: Color, size: CGFloat, delay: Double, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event identifier")
            print("CheckmarkAnalytics: \(localizedEvent) color:\(color) size:\(size) delay:\(delay) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
    }
}

/// An internal storage for analytics events for diagnostics or admin UI, including audit context.
fileprivate class AnalyticsEventStore {
    static let shared = AnalyticsEventStore()
    private init() {}
    
    private let maxEvents = 20
    private var events: [AnalyticsEvent] = []
    private let queue = DispatchQueue(label: "com.successcheckmark.analyticsEventStore", attributes: .concurrent)
    
    struct AnalyticsEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let event: String
        let color: Color
        let size: CGFloat
        let delay: Double
        let role: String?
        let staffID: String?
        let context: String?
        let escalate: Bool
    }
    
    /// Adds a new analytics event to the store asynchronously with audit context.
    func add(event: String, color: Color, size: CGFloat, delay: Double, role: String?, staffID: String?, context: String?, escalate: Bool) {
        queue.async(flags: .barrier) {
            let newEvent = AnalyticsEvent(timestamp: Date(), event: event, color: color, size: size, delay: delay, role: role, staffID: staffID, context: context, escalate: escalate)
            self.events.append(newEvent)
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
        }
    }
    
    /// Retrieves the last recorded analytics events including audit context.
    func getLastEvents() -> [AnalyticsEvent] {
        var snapshot: [AnalyticsEvent] = []
        queue.sync {
            snapshot = self.events
        }
        return snapshot
    }
}

/// An animated checkmark view for confirming successful actions like form submissions or tasks.
/// Now analytics/audit–ready, fully tokenized, accessible, and test/preview–injectable.
struct SuccessCheckmarkView: View {
    // MARK: - Design tokens (with robust fallback)
    var circleColor: Color = AppColors.success ?? .green
    var checkColor: Color = AppColors.onSuccess ?? .white
    var size: CGFloat = AppSpacing.checkmarkSize ?? 72
    var lineWidth: CGFloat = AppSpacing.checkmarkStroke ?? 7
    var delay: Double = 0.0

    /// Analytics logger (for business/QA/Trust Center).
    var analyticsLogger: SuccessCheckmarkAnalyticsLogger = NullSuccessCheckmarkAnalyticsLogger()
    /// Optional callback when animation completes.
    var onComplete: (() -> Void)? = nil

    @State private var animateCircle = false
    @State private var animateCheck = false

    private enum Tokens {
        static let circleDuration: Double = AppTheme.Animation.checkmarkCircle ?? 0.38
        static let checkDuration: Double = AppTheme.Animation.checkmarkStroke ?? 0.43
        static let checkDelay: Double = 0.22
        static let shadowOpacity: Double = 0.17
        static let accessibilityLabel: String = NSLocalizedString("SuccessCheckmarkView.accessibilityLabel", value: "Success. Checkmark confirmed.", comment: "Accessibility label for animated checkmark")
        static let accessibilityHint: String = NSLocalizedString("SuccessCheckmarkView.accessibilityHint", value: "Indicates a successful action.", comment: "Accessibility hint for animated checkmark")
        static let eventAppear: String = NSLocalizedString("SuccessCheckmarkView.eventAppear", value: "success_checkmark_appear", comment: "Analytics event for checkmark appearance")
    }
    
    /// Public API to fetch the last 20 analytics events for diagnostics or admin UI, including audit context.
    public static func fetchLastAnalyticsEvents() -> [AnalyticsEventStore.AnalyticsEvent] {
        AnalyticsEventStore.shared.getLastEvents()
    }

    var body: some View {
        ZStack {
            // Circular trim animation
            Circle()
                .trim(from: 0, to: animateCircle ? 1 : 0)
                .stroke(circleColor.opacity(0.7), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .shadow(color: circleColor.opacity(Tokens.shadowOpacity), radius: 10, x: 0, y: 3)
                .animation(.easeOut(duration: Tokens.circleDuration).delay(delay), value: animateCircle)

            // Animated checkmark
            CheckmarkShape()
                .trim(from: 0, to: animateCheck ? 1 : 0)
                .stroke(checkColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.53, height: size * 0.53)
                .offset(y: size * 0.07)
                .animation(.easeOut(duration: Tokens.checkDuration).delay(delay + Tokens.checkDelay), value: animateCheck)
        }
        .onAppear {
            animateCircle = false
            animateCheck = false
            Task {
                await logAppearEvent()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateCircle = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Tokens.checkDelay) {
                animateCheck = true
                // Optionally call completion handler after full animation
                DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.checkDuration) {
                    onComplete?()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(Tokens.accessibilityLabel))
        .accessibilityHint(Text(Tokens.accessibilityHint))
        .accessibilityAddTraits(.isImage)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLiveRegion(.polite)
    }
    
    /// Logs the appearance event asynchronously with localization and stores it for diagnostics including audit context.
    private func logAppearEvent() async {
        let event = Tokens.eventAppear
        let escalate = (circleColor == .red) || (size > 128)
        await analyticsLogger.log(event: event, color: circleColor, size: size, delay: delay, role: SuccessCheckmarkAuditContext.role, staffID: SuccessCheckmarkAuditContext.staffID, context: SuccessCheckmarkAuditContext.context, escalate: escalate)
        AnalyticsEventStore.shared.add(event: event, color: circleColor, size: size, delay: delay, role: SuccessCheckmarkAuditContext.role, staffID: SuccessCheckmarkAuditContext.staffID, context: SuccessCheckmarkAuditContext.context, escalate: escalate)
    }
}

/// Custom shape that draws a stylized checkmark using three anchor points.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.04, y: rect.midY * 1.15)
        let mid = CGPoint(x: rect.midX * 0.9, y: rect.maxY * 0.98)
        let end = CGPoint(x: rect.maxX * 0.98, y: rect.minY + rect.height * 0.20)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct SuccessCheckmarkView_Previews: PreviewProvider {
    /// A spy logger implementation for preview and test diagnostics including audit context.
    class SpyLogger: SuccessCheckmarkAnalyticsLogger {
        var testMode: Bool = true
        func log(event: String, color: Color, size: CGFloat, delay: Double, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event identifier")
            print("CheckmarkAnalytics: \(localizedEvent) color:\(color) size:\(size) delay:\(delay) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
    }
    static var previews: some View {
        VStack(spacing: 40) {
            SuccessCheckmarkView(circleColor: .green, checkColor: .white, size: 84, delay: 0.1, analyticsLogger: SpyLogger())
            SuccessCheckmarkView(circleColor: .blue, checkColor: .yellow, size: 60, analyticsLogger: SpyLogger())
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
