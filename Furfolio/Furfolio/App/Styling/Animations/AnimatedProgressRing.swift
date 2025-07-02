//
//  AnimatedProgressRing.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, business/enterprise-ready.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ProgressRingAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedProgressRing"
}

/**
 `AnimatedProgressRing` is a highly configurable, animated circular progress ring designed for use in KPIs, dashboards, loyalty programs, and enterprise-grade applications.

 ### Architecture & Extensibility
 - Built with SwiftUI for declarative UI and easy integration.
 - Modular design enables customization of colors, sizes, animations, and icons.
 - Uses robust token fallback patterns for consistent styling across apps.

 ### Analytics, Audit, and Trust Center Hooks
 - Integrates with an async/await-ready `ProgressRingAnalyticsLogger` protocol for event logging.
 - Supports a test mode for console-only logging in QA, testing, and preview environments.
 - Provides a public API to retrieve the last 20 analytics events for diagnostics or admin UI.

 ### Diagnostics & Compliance
 - All user-facing and logging strings are localized using `NSLocalizedString` to support internationalization and compliance.
 - Includes detailed accessibility labels and supports VoiceOver.
 - Designed with audit-readiness and business compliance in mind.

 ### Preview & Testability
 - Includes SwiftUI previews with a spy logger for testing analytics events.
 - Supports animation toggling and percentage display control for flexible testing.

 This component is intended for maintainers and future developers to easily extend, localize, and integrate into enterprise applications with audit and compliance requirements.
 */

// MARK: - Analytics/Audit Logger Protocol

/// Represents an analytics event record with audit fields.
public struct ProgressRingAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let event: String
    public let percent: Double
    public let label: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let timestamp: Date
}

/// Protocol defining asynchronous analytics logging for the progress ring.
public protocol ProgressRingAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - event: The event name.
    ///   - percent: The progress percent (0.0 to 1.0).
    ///   - label: Optional label associated with the ring.
    ///   - role: User role for audit context.
    ///   - staffID: Staff identifier for audit context.
    ///   - context: Additional context string.
    ///   - escalate: Whether to escalate this event for compliance.
    func log(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Fetches recent analytics events asynchronously.
    /// - Parameter count: Number of recent events to fetch.
    /// - Returns: Array of `ProgressRingAnalyticsEvent`.
    func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent]

    /// Escalates a specific event asynchronously for compliance or alerting.
    func escalate(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?) async
}

/// A no-op analytics logger that does nothing.
/// Useful as a default to avoid optional handling.
public struct NullProgressRingAnalyticsLogger: ProgressRingAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}

    public func log(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {}

    public func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent] {
        return []
    }

    public func escalate(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?) async {}
}

/// A simple analytics logger that prints events to the console when testMode is true.
public class ConsoleProgressRingAnalyticsLogger: ProgressRingAnalyticsLogger {
    public let testMode: Bool

    /// Stores the last 20 logged events for diagnostics.
    public private(set) var recentEvents: [ProgressRingAnalyticsEvent] = []

    public init(testMode: Bool = true) {
        self.testMode = testMode
    }

    /// Logs the event asynchronously and stores it in recentEvents.
    public func log(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let localizedEvent = NSLocalizedString(event, comment: "Analytics event name")
        let localizedLabel = label != nil ? NSLocalizedString(label!, comment: "Progress ring label") : nil
        let analyticsEvent = ProgressRingAnalyticsEvent(event: localizedEvent, percent: percent, label: localizedLabel, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date())

        // Append to recent events (keep max 20)
        DispatchQueue.main.async {
            self.recentEvents.append(analyticsEvent)
            if self.recentEvents.count > 20 {
                self.recentEvents.removeFirst(self.recentEvents.count - 20)
            }
        }

        if testMode {
            let labelStr = localizedLabel ?? "-"
            let roleStr = role ?? "-"
            let staffStr = staffID ?? "-"
            let contextStr = context ?? "-"
            let escalateStr = escalate ? "ESCL" : "NOESCL"
            print("RingAnalytics: \(localizedEvent) \(Int(percent * 100))% \(labelStr) Role:\(roleStr) StaffID:\(staffStr) Context:\(contextStr) Escalate:\(escalateStr)")
        }
        // Future: send to remote analytics service asynchronously here.
    }

    public func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent] {
        return Array(recentEvents.suffix(count))
    }

    public func escalate(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?) async {
        // Implementation for escalation (e.g., send alert or log to compliance system)
        if testMode {
            let labelStr = label ?? "-"
            let roleStr = role ?? "-"
            let staffStr = staffID ?? "-"
            let contextStr = context ?? "-"
            print("RingAnalytics ESCALATE: \(event) \(Int(percent * 100))% \(labelStr) Role:\(roleStr) StaffID:\(staffStr) Context:\(contextStr)")
        }
    }
}

/// A configurable animated circular progress ring used for KPIs, dashboards, or loyalty programs.
struct AnimatedProgressRing: View {
    /// Progress as a percentage (0.0 to 1.0).
    var percent: Double

    /// Optional label shown below the ring.
    var label: String? = nil

    /// Optional SF Symbol shown inside the ring.
    var icon: String? = nil

    /// Color of the progress ring and text/icon.
    var color: Color = AppColors.accent ?? .accentColor

    /// Size of the ring view (width/height).
    var size: CGFloat = AppSpacing.progressRingSize ?? 86

    /// Width of the circular stroke line.
    var ringWidth: CGFloat = AppSpacing.progressRingStroke ?? 14

    /// Background ring color.
    var backgroundColor: Color = AppColors.progressRingBackground ?? Color(.systemGray5)

    /// Whether the ring should animate from 0 to the target percent.
    var animate: Bool = true

    /// Whether to display the percentage value in the center.
    var showPercentText: Bool = true

    /// Analytics logger for business/compliance/test dashboards.
    var analyticsLogger: ProgressRingAnalyticsLogger = NullProgressRingAnalyticsLogger()

    @State private var animatedPercent: Double = 0.0

    // MARK: - Tokens (robust fallback)
    private enum Tokens {
        static let animationDuration: Double = 1.1
        static let iconOffset: CGFloat = AppSpacing.iconOffset ?? 22
        static let cornerRadius: CGFloat = AppRadius.medium ?? 16
        static let shadowRadius: CGFloat = 6
        static let vSpacing: CGFloat = AppSpacing.medium ?? 10
        static let hPadding: CGFloat = AppSpacing.small ?? 8
        static let labelFont: Font = AppFonts.footnote ?? .footnote
        static let percentFont: Font = AppFonts.progressRingPercent ?? .system(size: 24, weight: .bold, design: .rounded)
        static let iconFont: Font = AppFonts.progressRingIcon ?? .system(size: 18, weight: .bold)
        static let background: Color = AppColors.progressRingContainerBg ?? Color(.systemBackground).opacity(0.97)
        static let shadowColor: Color = .black.opacity(0.06)
        static let labelColor: Color = AppColors.secondary ?? .secondary
    }

    var body: some View {
        VStack(spacing: Tokens.vSpacing) {
            ZStack {
                // Base circle
                Circle()
                    .stroke(backgroundColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

                // Progress arc
                Circle()
                    .trim(from: 0, to: animate ? animatedPercent : percent)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: Tokens.animationDuration), value: animatedPercent)

                // Center: % and/or icon
                VStack(spacing: 2) {
                    if showPercentText {
                        Text("\(Int((animate ? animatedPercent : percent) * 100))%")
                            .font(Tokens.percentFont)
                            .foregroundColor(color)
                            .minimumScaleFactor(0.8)
                            .accessibilityLabel(Text(String(format: NSLocalizedString("%d percent", comment: "Accessibility label for progress percent"), Int((animate ? animatedPercent : percent) * 100))))
                    }
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(Tokens.iconFont)
                            .foregroundColor(color.opacity(0.75))
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: size, height: size)
            .task {
                await handleAppear()
            }
            .onChange(of: percent) { newValue in
                Task {
                    await handlePercentChange(newValue)
                }
            }

            if let label = label {
                Text(NSLocalizedString(label, comment: "Progress ring label"))
                    .font(Tokens.labelFont)
                    .foregroundColor(Tokens.labelColor)
                    .accessibilityLabel(Text(NSLocalizedString(label, comment: "Accessibility label for progress ring label")))
            }
        }
        .padding(Tokens.hPadding)
        .background(
            RoundedRectangle(cornerRadius: Tokens.cornerRadius)
                .fill(Tokens.background)
                .shadow(color: Tokens.shadowColor, radius: Tokens.shadowRadius, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text(String(format: NSLocalizedString("%d percent complete", comment: "Accessibility value for progress ring completion"), Int(percent * 100))))
    }

    /// Accessibility label for the ring, localized.
    private var accessibilityLabel: Text {
        if let label = label {
            return Text(NSLocalizedString(label, comment: "Accessibility label for progress ring"))
        } else {
            return Text(NSLocalizedString("Progress Ring", comment: "Default accessibility label for progress ring"))
        }
    }

    /// Handles view appearance and triggers analytics logging.
    private func handleAppear() async {
        startAnimation()
        await analyticsLogger.log(
            event: NSLocalizedString("appear", comment: "Analytics event when ring appears"),
            percent: percent,
            label: label,
            role: ProgressRingAuditContext.role,
            staffID: ProgressRingAuditContext.staffID,
            context: ProgressRingAuditContext.context,
            escalate: shouldEscalate(label: label)
        )
    }

    /// Handles changes in the percent value and triggers analytics logging.
    /// - Parameter newValue: The new progress percent.
    private func handlePercentChange(_ newValue: Double) async {
        startAnimation()
        await analyticsLogger.log(
            event: NSLocalizedString("percent_changed", comment: "Analytics event when percent changes"),
            percent: newValue,
            label: label,
            role: ProgressRingAuditContext.role,
            staffID: ProgressRingAuditContext.staffID,
            context: ProgressRingAuditContext.context,
            escalate: shouldEscalate(label: label)
        )
    }

    /// Starts the ring animation if enabled.
    private func startAnimation() {
        if animate {
            withAnimation(.easeOut(duration: Tokens.animationDuration)) {
                animatedPercent = percent
            }
        } else {
            animatedPercent = percent
        }
    }

    /// Determines if the event should be escalated based on label content.
    private func shouldEscalate(label: String?) -> Bool {
        guard let label = label else { return false }
        let lowerLabel = label.lowercased()
        return lowerLabel.contains("critical") || lowerLabel.contains("warning") || lowerLabel.contains("risk")
    }
}

// MARK: - Public API for Diagnostics

extension AnimatedProgressRing {
    /**
     Retrieves the last 20 analytics events logged by the provided analytics logger, if supported.

     - Parameter logger: The analytics logger instance.
     - Returns: An array of `ProgressRingAnalyticsEvent` representing recent events, or nil if unavailable.
     */
    public static func recentAnalyticsEvents(from logger: ProgressRingAnalyticsLogger) async -> [ProgressRingAnalyticsEvent]? {
        let events = await logger.fetchRecentEvents(count: 20)
        return events.isEmpty ? nil : events
    }

    /**
     Retrieves the last N analytics events logged by the provided analytics logger, if supported.

     - Parameters:
       - logger: The analytics logger instance.
       - count: Number of recent events to fetch.
     - Returns: An array of `ProgressRingAnalyticsEvent` representing recent events, or nil if unavailable.
     */
    public static func fetchRecentAnalyticsEvents(from logger: ProgressRingAnalyticsLogger, count: Int) async -> [ProgressRingAnalyticsEvent]? {
        let events = await logger.fetchRecentEvents(count: count)
        return events.isEmpty ? nil : events
    }
}

#if DEBUG
struct AnimatedProgressRing_Previews: PreviewProvider {
    /// Spy logger for preview/testing that prints logs to console and supports audit fields.
    class SpyLogger: ProgressRingAnalyticsLogger {
        let testMode: Bool = true

        func log(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let labelStr = label ?? "-"
            let roleStr = role ?? "-"
            let staffStr = staffID ?? "-"
            let contextStr = context ?? "-"
            let escalateStr = escalate ? "ESCL" : "NOESCL"
            print("RingAnalytics (Spy): \(event) \(Int(percent * 100))% \(labelStr) Role:\(roleStr) StaffID:\(staffStr) Context:\(contextStr) Escalate:\(escalateStr)")
        }

        func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent] {
            return []
        }

        func escalate(event: String, percent: Double, label: String?, role: String?, staffID: String?, context: String?) async {
            print("RingAnalytics ESCALATE (Spy): \(event) \(Int(percent * 100))% \(label ?? "-") Role:\(role ?? "-") StaffID:\(staffID ?? "-") Context:\(context ?? "-")")
        }
    }
    static var previews: some View {
        VStack(spacing: 28) {
            AnimatedProgressRing(percent: 0.83, label: NSLocalizedString("Loyalty", comment: "Preview label"), icon: "star.fill", color: .yellow, analyticsLogger: SpyLogger())
            AnimatedProgressRing(percent: 0.51, label: NSLocalizedString("Revenue Goal", comment: "Preview label"), icon: "dollarsign.circle.fill", color: .green, analyticsLogger: SpyLogger())
            AnimatedProgressRing(percent: 0.34, label: NSLocalizedString("Retention", comment: "Preview label"), icon: "heart.fill", color: .pink, showPercentText: false, analyticsLogger: SpyLogger())
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
