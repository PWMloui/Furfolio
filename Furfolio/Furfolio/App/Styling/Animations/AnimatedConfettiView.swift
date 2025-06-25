//
//  AnimatedConfettiView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, enterprise-ready.
//

import SwiftUI

// MARK: - Audit/Analytics Logger Protocol

public protocol ConfettiAnalyticsLogger {
    func log(event: String, emoji: String?, count: Int)
}
public struct NullConfettiAnalyticsLogger: ConfettiAnalyticsLogger {
    public init() {}
    public func log(event: String, emoji: String?, count: Int) {}
}

/// Animated confetti overlay for celebration events.
/// Usage: `.overlay(AnimatedConfettiView(trigger: $isCelebrating))`
struct AnimatedConfettiView: View {
    @Binding var trigger: Bool
    var duration: Double = 2.5
    var confettiCount: Int = 28
    var emojis: [String] = ["🎉", "🎊", "✨", "🥳", "🎂", "🐶"]
    var colors: [Color] = [
        AppColors.loyaltyYellow ?? .yellow,
        AppColors.success ?? .green,
        AppColors.retentionOrange ?? .orange,
        AppColors.pink ?? .pink,
        AppColors.milestoneBlue ?? .blue,
        AppColors.customPurple ?? .purple
    ]
    var analyticsLogger: ConfettiAnalyticsLogger = NullConfettiAnalyticsLogger()

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
                launchConfetti()
                scheduleClearConfetti()
                analyticsLogger.log(event: "confetti_launched", emoji: nil, count: confettiCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Confetti animation overlay"))
        .accessibilityHint(Text("Celebratory confetti for achievements and milestones"))
    }

    private func launchConfetti() {
        particles = (0..<confettiCount).map { _ in
            let emoji = emojis.randomElement() ?? "🎉"
            analyticsLogger.log(event: "confetti_particle_created", emoji: emoji, count: 1)
            return ConfettiParticle(
                id: UUID(),
                angle: Double.random(in: 0...360),
                velocity: Double.random(in: 120...220),
                spin: Double.random(in: -1.8...1.8),
                color: colors.randomElement() ?? .yellow,
                emoji: emoji,
                startTime: Date()
            )
        }
    }

    private func scheduleClearConfetti() {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: 0.65)) {
                particles.removeAll()
                analyticsLogger.log(event: "confetti_cleared", emoji: nil, count: 0)
            }
        }
    }
}

// MARK: - Confetti Particle Model

private struct ConfettiParticle: Identifiable {
    let id: UUID
    let angle: Double      // Launch angle (deg)
    let velocity: Double   // Initial velocity (pt/s)
    let spin: Double       // Spin speed (rad/s)
    let color: Color
    let emoji: String
    let startTime: Date
}

// MARK: - Particle View

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    @State private var time: Double = 0.0

    // Gravity and drag constants for "real" effect
    private let gravity: Double = 330
    private let drag: Double = 0.16

    // Design tokens for size and animation
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

    /// Calculates the position of the confetti at time t (basic physics with gravity & drag).
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
        func log(event: String, emoji: String?, count: Int) {
            print("Analytics: \(event), emoji: \(emoji ?? "-"), count: \(count)")
        }
    }
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 24) {
                Button("Trigger Confetti") { show.toggle() }
                    .font(.title2.bold())
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue.opacity(0.13))
                        .frame(height: 260)
                        .overlay(Text("Achievement! 🎉").font(.largeTitle))
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
