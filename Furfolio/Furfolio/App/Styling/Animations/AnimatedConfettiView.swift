//
//  AnimatedConfettiView.swift
//  Furfolio
//
//  Enhanced: Role/staff/context audit, escalation-ready, token-compliant, modular, accessible, preview/testable, enterprise-ready.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)

public struct ConfettiAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedConfettiView"
}

// MARK: - Audit/Analytics Logger Protocol

public protocol ConfettiAnalyticsLogger {
    var testMode: Bool { get }
    func log(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func fetchRecentEvents(count: Int) async -> [ConfettiAnalyticsEvent]
    func escalate(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?) async
}

// MARK: - Default Loggers

public struct NullConfettiAnalyticsLogger: ConfettiAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [ConfettiAnalyticsEvent] { [] }
    public func escalate(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?) async {}
}

public final class InMemoryConfettiAnalyticsLogger: ConfettiAnalyticsLogger {
    public let testMode: Bool
    private let maxEvents = 20
    private var events: [ConfettiAnalyticsEvent] = []
    private let queue = DispatchQueue(label: "InMemoryConfettiAnalyticsLogger.queue", attributes: .concurrent)

    public init(testMode: Bool = false) { self.testMode = testMode }

    public func log(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let auditEvent = ConfettiAnalyticsEvent(
            event: event, emoji: emoji, count: count,
            role: role, staffID: staffID, context: context,
            escalate: escalate, timestamp: Date()
        )
        queue.async(flags: .barrier) {
            if self.events.count >= self.maxEvents { self.events.removeFirst() }
            self.events.append(auditEvent)
        }
        if testMode {
            print("[ConfettiAnalytics] \(event), emoji: \(emoji ?? "-"), count: \(count), [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
    }
    public func fetchRecentEvents(count: Int) async -> [ConfettiAnalyticsEvent] {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: Array(self.events.suffix(count))) }
        }
    }
    public func escalate(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?) async {
        await log(event: event, emoji: emoji, count: count, role: role, staffID: staffID, context: context, escalate: true)
    }
}

// MARK: - Analytics Event Struct

public struct ConfettiAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let emoji: String?
    public let count: Int
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

// MARK: - AnimatedConfettiView

struct AnimatedConfettiView: View {
    @Binding var trigger: Bool
    var duration: Double = 2.5
    var confettiCount: Int = 28
    var emojis: [String] = [
        NSLocalizedString("emoji_party_popper", comment: "Party popper emoji"),
        NSLocalizedString("emoji_confetti_ball", comment: "Confetti ball emoji"),
        NSLocalizedString("emoji_sparkles", comment: "Sparkles emoji"),
        NSLocalizedString("emoji_party_face", comment: "Party face emoji"),
        NSLocalizedString("emoji_birthday_cake", comment: "Birthday cake emoji"),
        NSLocalizedString("emoji_dog_face", comment: "Dog face emoji")
    ]
    var colors: [Color] = [
        AppColors.loyaltyYellow ?? .yellow,
        AppColors.success ?? .green,
        AppColors.retentionOrange ?? .orange,
        AppColors.pink ?? .pink,
        AppColors.milestoneBlue ?? .blue,
        AppColors.customPurple ?? .purple
    ]
    var analyticsLogger: ConfettiAnalyticsLogger = NullConfettiAnalyticsLogger()

    @State private var analyticsEvents: [ConfettiAnalyticsEvent] = []
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ConfettiParticleView(particle: particle)
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            if newValue {
                Task {
                    await launchConfetti()
                    scheduleClearConfetti()
                    await logEvent(
                        NSLocalizedString("event_confetti_launched", comment: "Confetti launched event"),
                        emoji: nil,
                        count: confettiCount,
                        escalate: false
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(NSLocalizedString("accessibility_confetti_label", comment: "Confetti animation overlay")))
        .accessibilityHint(Text(NSLocalizedString("accessibility_confetti_hint", comment: "Celebratory confetti for achievements and milestones")))
    }

    public func getLastAnalyticsEvents() -> [ConfettiAnalyticsEvent] {
        analyticsEvents
    }

    @MainActor
    private func launchConfetti() async {
        var newParticles: [ConfettiParticle] = []
        for _ in 0..<confettiCount {
            let emoji = emojis.randomElement() ?? NSLocalizedString("emoji_party_popper", comment: "Party popper emoji")
            await logEvent(
                NSLocalizedString("event_confetti_particle_created", comment: "Confetti particle created event"),
                emoji: emoji,
                count: 1,
                escalate: false
            )
            let particle = ConfettiParticle(
                id: UUID(),
                angle: Double.random(in: 0...360),
                velocity: Double.random(in: 120...220),
                spin: Double.random(in: -1.8...1.8),
                color: colors.randomElement() ?? .yellow,
                emoji: emoji,
                startTime: Date()
            )
            newParticles.append(particle)
        }
        particles = newParticles
    }

    private func scheduleClearConfetti() {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: 0.65)) {
                particles.removeAll()
            }
            Task {
                await logEvent(
                    NSLocalizedString("event_confetti_cleared", comment: "Confetti cleared event"),
                    emoji: nil,
                    count: 0,
                    escalate: false
                )
            }
        }
    }

    @MainActor
    private func logEvent(_ event: String, emoji: String?, count: Int, escalate: Bool) async {
        let role = ConfettiAuditContext.role
        let staffID = ConfettiAuditContext.staffID
        let context = ConfettiAuditContext.context
        await analyticsLogger.log(event: event, emoji: emoji, count: count, role: role, staffID: staffID, context: context, escalate: escalate)
        let newEvent = ConfettiAnalyticsEvent(
            timestamp: Date(),
            event: event,
            emoji: emoji,
            count: count,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        analyticsEvents.append(newEvent)
        if analyticsEvents.count > 20 {
            analyticsEvents.removeFirst(analyticsEvents.count - 20)
        }
    }
}

// MARK: - Confetti Particle Model

private struct ConfettiParticle: Identifiable {
    let id: UUID
    let angle: Double
    let velocity: Double
    let spin: Double
    let color: Color
    let emoji: String
    let startTime: Date
}

// MARK: - Particle View

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    @State private var time: Double = 0.0

    private let gravity: Double = 330
    private let drag: Double = 0.16
    private let fontSize: CGFloat = AppFonts.confettiSize ?? 34

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(particle.startTime)
            let (dx, dy) = trajectory(time: t)
            let angle = Angle.degrees(particle.angle)
            let x = cos(angle.radians) * dx
            let y = -sin(angle.radians) * dx + dy

            Text(particle.emoji)
                .font(.system(size: fontSize))
                .scaleEffect(1.0 - CGFloat(min(t / 2.5, 0.5)))
                .rotationEffect(.radians(particle.spin * t))
                .foregroundColor(particle.color)
                .opacity(t < 2.5 ? 1.0 : 0)
                .position(x: UIScreen.main.bounds.width/2 + CGFloat(x),
                          y: 90 + CGFloat(y))
        }
    }

    private func trajectory(time t: TimeInterval) -> (Double, Double) {
        let vx = particle.velocity * cos(particle.angle * .pi / 180)
        let vy = particle.velocity * sin(particle.angle * .pi / 180)
        let x = vx * t * exp(-drag * t)
        let y = vy * t - 0.5 * gravity * t * t
        return (x, y)
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedConfettiView_Previews: PreviewProvider {
    struct SpyLogger: ConfettiAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("Analytics: \(event), emoji: \(emoji ?? "-"), count: \(count), [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
        func fetchRecentEvents(count: Int) async -> [ConfettiAnalyticsEvent] { [] }
        func escalate(event: String, emoji: String?, count: Int, role: String?, staffID: String?, context: String?) async {
            await log(event: event, emoji: emoji, count: count, role: role, staffID: staffID, context: context, escalate: true)
        }
    }
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 24) {
                Button(NSLocalizedString("button_trigger_confetti", comment: "Trigger Confetti button label")) { show.toggle() }
                    .font(.title2.bold())
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue.opacity(0.13))
                        .frame(height: 260)
                        .overlay(Text(NSLocalizedString("label_achievement", comment: "Achievement label with emoji")).font(.largeTitle))
                    AnimatedConfettiView(trigger: $show, analyticsLogger: SpyLogger())
                }
                .frame(height: 260)
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
