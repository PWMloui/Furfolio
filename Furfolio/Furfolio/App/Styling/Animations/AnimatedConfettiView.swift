//
//  AnimatedConfettiView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Animated confetti overlay for celebration events.
/// Usage: `.overlay(AnimatedConfettiView(trigger: $isCelebrating))`
struct AnimatedConfettiView: View {
    @Binding var trigger: Bool
    var duration: Double = 2.5
    var confettiCount: Int = 28
    var emojis: [String] = ["🎉", "🎊", "✨", "🥳", "🎂", "🐶"]
    var colors: [Color] = [.yellow, .green, .orange, .pink, .blue, .purple]

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
            }
        }
    }

    private func launchConfetti() {
        particles = (0..<confettiCount).map { _ in
            ConfettiParticle(
                id: UUID(),
                angle: Double.random(in: 0...360),
                velocity: Double.random(in: 120...220),
                spin: Double.random(in: -1.8...1.8),
                color: colors.randomElement() ?? .yellow,
                emoji: emojis.randomElement()!,
                startTime: Date()
            )
        }
    }

    private func scheduleClearConfetti() {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: 0.65)) {
                particles.removeAll()
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

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(particle.startTime)
            let (dx, dy) = trajectory(time: t)
            let angle = Angle.degrees(particle.angle)
            let x = cos(angle.radians) * dx
            let y = -sin(angle.radians) * dx + dy

            Text(particle.emoji)
                .font(.system(size: 34))
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
                    AnimatedConfettiView(trigger: $show)
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
