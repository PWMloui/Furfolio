//
//  DashboardMilestoneAnimation.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, accessible, preview/testable, enterprise-grade.
//
//  MARK: - DashboardMilestoneAnimation Architecture and Features
//
//  DashboardMilestoneAnimation is a SwiftUI View designed to visually celebrate user milestones such as revenue goals, appointment streaks, and loyalty achievements. Its architecture emphasizes modularity, extensibility, and compliance with enterprise requirements.
//
//  Key Features:
//  - **Extensibility:** Supports customizable emoji, label, color, subtitle, and confetti effects.
//  - **Analytics/Audit/Trust Center Hooks:** Integrates with an async/await-ready analytics logger protocol that supports test mode logging and stores recent events with audit context for diagnostics, audit, and compliance purposes.
//  - **Diagnostics:** Provides a public API to retrieve the last 20 logged analytics events including audit metadata for admin UI or debugging.
//  - **Localization:** All user-facing and log event strings are wrapped in NSLocalizedString with descriptive keys and comments to facilitate comprehensive localization and compliance.
//  - **Accessibility:** Implements accessibility labels, hints, and traits to ensure usability for all users.
//  - **Compliance:** Designed with audit trails, token compliance, and enterprise-grade logging in mind, including escalation flags based on criticality keywords.
//  - **Preview/Testability:** Includes a preview provider with a test-mode analytics logger to enable safe and observable testing.
//
//  This design ensures that future maintainers can easily extend functionality, integrate with analytics systems, and maintain compliance with enterprise standards.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct MilestoneAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DashboardMilestoneAnimation"
}

// MARK: - Analytics/Audit Logger Protocol

/// Struct representing a logged milestone analytics event with audit and escalation metadata.
public struct MilestoneAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let event: String
    public let emoji: String
    public let label: String
    public let subtitle: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let timestamp: Date
}

/// Protocol defining an asynchronous analytics logger for milestone events.
/// Supports test mode for console-only logging and stores recent events with audit context for diagnostics and compliance.
public protocol MilestoneAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously, including audit context and escalation flag.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - emoji: The associated emoji string.
    ///   - label: The label describing the milestone.
    ///   - subtitle: An optional subtitle providing additional context.
    ///   - role: The user role from audit context.
    ///   - staffID: The staff identifier from audit context.
    ///   - context: The context string from audit context.
    ///   - escalate: Flag indicating if the event should be escalated due to criticality.
    func log(event: String, emoji: String, label: String, subtitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    
    /// Retrieves the last 20 logged analytics events with audit metadata for diagnostics or admin UI.
    /// - Returns: An array of MilestoneAnalyticsEvent instances.
    func lastLoggedEvents() async -> [MilestoneAnalyticsEvent]
}

/// A no-op analytics logger implementation that performs no logging.
public struct NullMilestoneAnalyticsLogger: MilestoneAnalyticsLogger {
    public let testMode: Bool = false
    
    public init() {}
    
    public func log(event: String, emoji: String, label: String, subtitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        // No operation
    }
    
    public func lastLoggedEvents() async -> [MilestoneAnalyticsEvent] {
        return []
    }
}

/// A simple analytics logger that logs to the console in test mode and stores recent events with audit metadata.
public class ConsoleMilestoneAnalyticsLogger: MilestoneAnalyticsLogger, ObservableObject {
    public let testMode: Bool
    
    /// Thread-safe storage for recent events.
    private let maxEvents = 20
    private var eventStorage: [MilestoneAnalyticsEvent] = []
    private let storageQueue = DispatchQueue(label: "com.furfolio.consoleMilestoneAnalyticsLogger.storageQueue", attributes: .concurrent)
    
    /// Initializes the logger.
    /// - Parameter testMode: If true, logs to console; otherwise, no console output.
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    /// Logs an analytics event asynchronously with audit context and escalation flag.
    public func log(event: String, emoji: String, label: String, subtitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let newEvent = MilestoneAnalyticsEvent(
            event: event,
            emoji: emoji,
            label: label,
            subtitle: subtitle,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate,
            timestamp: Date()
        )
        // Store event thread-safely
        storageQueue.async(flags: .barrier) {
            self.eventStorage.append(newEvent)
            if self.eventStorage.count > self.maxEvents {
                self.eventStorage.removeFirst(self.eventStorage.count - self.maxEvents)
            }
        }
        
        if testMode {
            let subtitleText = subtitle ?? ""
            print("MilestoneAnalytics: \(event), \(emoji) \(label) \(subtitleText) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
        
        // Placeholder for real async analytics integration
        // e.g., await analyticsService.sendEvent(...)
    }
    
    /// Retrieves the last 20 logged analytics events with audit metadata.
    public func lastLoggedEvents() async -> [MilestoneAnalyticsEvent] {
        await withCheckedContinuation { continuation in
            storageQueue.async {
                continuation.resume(returning: self.eventStorage)
            }
        }
    }
}

/// Animated badge for milestone celebration (revenue goals, appointment streaks, loyalty, etc).
struct DashboardMilestoneAnimation: View {
    @Binding var trigger: Bool
    var emoji: String = "🏆"
    var label: String = NSLocalizedString("Milestone", comment: "Default milestone label")
    var color: Color = AppColors.milestoneYellow ?? .yellow
    var subtitle: String? = nil
    var showConfetti: Bool = true
    var analyticsLogger: MilestoneAnalyticsLogger = NullMilestoneAnalyticsLogger()
    
    @State private var animate: Bool = false
    @State private var shine: Bool = false
    
    private enum Tokens {
        static let appearDelay: Double = 0.05
        static let shineStartDelay: Double = 0.38
        static let shineDuration: Double = 0.66
        static let hPad: CGFloat = AppSpacing.xLarge ?? 28
        static let vPad: CGFloat = AppSpacing.medium ?? 18
        static let badgeFont: Font = AppFonts.headlineBold ?? .headline.bold()
        static let subtitleFont: Font = AppFonts.subheadline ?? .subheadline
        static let emojiFont: Font = AppFonts.milestoneEmoji ?? .system(size: 38)
        static let badgeBgOpacity: Double = 0.11
        static let badgeShadowOpacity: Double = 0.19
        static let emojiShadowOpacity: Double = 0.21
        static let shadowRadiusActive: CGFloat = 16
        static let shadowRadiusInactive: CGFloat = 7
        static let capsuleRadius: CGFloat = AppRadius.large ?? 36
        static let spacing: CGFloat = AppSpacing.large ?? 12
        static let subtitleSpacing: CGFloat = 2
        static let scaleActive: CGFloat = 1.0
        static let scaleInactive: CGFloat = 0.8
        static let emojiScaleActive: CGFloat = 1.13
        static let emojiScaleInactive: CGFloat = 0.88
    }
    
    var body: some View {
        ZStack {
            // Confetti overlay if enabled
            if showConfetti && trigger {
                AnimatedConfettiView(trigger: $trigger, colors: [color, .orange, .yellow])
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            
            // Main animated badge
            HStack(spacing: Tokens.spacing) {
                Text(emoji)
                    .font(Tokens.emojiFont)
                    .scaleEffect(animate ? Tokens.emojiScaleActive : Tokens.emojiScaleInactive)
                    .shadow(color: color.opacity(Tokens.emojiShadowOpacity), radius: 6, x: 0, y: 4)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: Tokens.subtitleSpacing) {
                    Text(label)
                        .font(Tokens.badgeFont)
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.24), radius: animate ? 4 : 1, x: 0, y: 1)
                        .overlay(
                            shine ?
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.97), color.opacity(0.3)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .blendMode(.screen)
                                .mask(Text(label).font(Tokens.badgeFont))
                                .animation(.linear(duration: Tokens.shineDuration), value: shine)
                            : nil
                        )
                        .accessibilityAddTraits(.isHeader)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Tokens.subtitleFont)
                            .foregroundColor(AppColors.textSecondary ?? .secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .padding(.horizontal, Tokens.hPad)
            .padding(.vertical, Tokens.vPad)
            .background(
                Capsule()
                    .fill(color.opacity(Tokens.badgeBgOpacity))
                    .shadow(color: color.opacity(Tokens.badgeShadowOpacity), radius: animate ? Tokens.shadowRadiusActive : Tokens.shadowRadiusInactive, x: 0, y: 2)
            )
            .scaleEffect(animate ? Tokens.scaleActive : Tokens.scaleInactive)
            .opacity(animate ? 1.0 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                Text(label) + (subtitle != nil ? Text(". \(subtitle!)") : Text(""))
            )
            .accessibilityHint(
                Text(
                    NSLocalizedString(
                        "Milestone achieved: \(label)\(subtitle != nil ? ". \(subtitle!)" : "")",
                        comment: "Accessibility hint for milestone achievement badge"
                    )
                )
            )
            .onAppear {
                if trigger {
                    Task {
                        await animateBadge()
                    }
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    Task {
                        await animateBadge()
                    }
                }
            }
        }
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: animate)
    }
    
    /// Determines if the label or subtitle contains critical keywords for escalation.
    private func shouldEscalate(label: String, subtitle: String?) -> Bool {
        let keywords = ["critical", "risk", "warning"]
        let combined = (label + " " + (subtitle ?? "")).lowercased()
        return keywords.contains(where: combined.contains)
    }
    
    /// Triggers the milestone badge and shine animation, and logs analytics asynchronously with audit context and escalation.
    private func animateBadge() async {
        animate = false
        shine = false
        try? await Task.sleep(nanoseconds: UInt64(Tokens.appearDelay * 1_000_000_000))
        await MainActor.run {
            withAnimation {
                animate = true
            }
        }
        let escalateFlag = shouldEscalate(label: label, subtitle: subtitle)
        await analyticsLogger.log(
            event: NSLocalizedString("milestone_appeared", comment: "Event when milestone badge appears"),
            emoji: emoji,
            label: label,
            subtitle: subtitle,
            role: MilestoneAuditContext.role,
            staffID: MilestoneAuditContext.staffID,
            context: MilestoneAuditContext.context,
            escalate: escalateFlag
        )
        
        try? await Task.sleep(nanoseconds: UInt64(Tokens.shineStartDelay * 1_000_000_000))
        await MainActor.run {
            shine = true
        }
        await analyticsLogger.log(
            event: NSLocalizedString("milestone_shine", comment: "Event when milestone shine animation starts"),
            emoji: emoji,
            label: label,
            subtitle: subtitle,
            role: MilestoneAuditContext.role,
            staffID: MilestoneAuditContext.staffID,
            context: MilestoneAuditContext.context,
            escalate: escalateFlag
        )
        
        try? await Task.sleep(nanoseconds: UInt64(Tokens.shineDuration * 1_000_000_000))
        await MainActor.run {
            shine = false
        }
        await analyticsLogger.log(
            event: NSLocalizedString("milestone_shine_end", comment: "Event when milestone shine animation ends"),
            emoji: emoji,
            label: label,
            subtitle: subtitle,
            role: MilestoneAuditContext.role,
            staffID: MilestoneAuditContext.staffID,
            context: MilestoneAuditContext.context,
            escalate: escalateFlag
        )
    }
    
    /// Public API to fetch the last 20 analytics events logged by the analyticsLogger including audit metadata.
    /// - Returns: An array of MilestoneAnalyticsEvent instances.
    public func fetchRecentAnalyticsEvents() async -> [MilestoneAnalyticsEvent] {
        return await analyticsLogger.lastLoggedEvents()
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardMilestoneAnimation_Previews: PreviewProvider {
    /// Spy logger to capture and print analytics events during preview/testing with audit context.
    class SpyLogger: MilestoneAnalyticsLogger {
        public let testMode: Bool = true
        private var events: [MilestoneAnalyticsEvent] = []
        private let lock = NSLock()
        
        func log(event: String, emoji: String, label: String, subtitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            lock.lock()
            let newEvent = MilestoneAnalyticsEvent(
                event: event,
                emoji: emoji,
                label: label,
                subtitle: subtitle,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate,
                timestamp: Date()
            )
            events.append(newEvent)
            if testMode {
                print("MilestoneAnalytics: \(event), \(emoji) \(label) \(subtitle ?? "") role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
            }
            lock.unlock()
        }
        
        func lastLoggedEvents() async -> [MilestoneAnalyticsEvent] {
            lock.lock()
            let copy = events
            lock.unlock()
            return copy
        }
    }
    
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 36) {
                Button(NSLocalizedString("Trigger Milestone", comment: "Button title to trigger milestone animation")) { show.toggle() }
                DashboardMilestoneAnimation(
                    trigger: $show,
                    emoji: "💸",
                    label: NSLocalizedString("Revenue Goal!", comment: "Milestone label for revenue goal"),
                    color: .green,
                    subtitle: NSLocalizedString("You hit $10K this month!", comment: "Milestone subtitle for revenue goal"),
                    showConfetti: true,
                    analyticsLogger: SpyLogger()
                )
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
            .background(Color(.systemGroupedBackground))
    }
}
#endif
