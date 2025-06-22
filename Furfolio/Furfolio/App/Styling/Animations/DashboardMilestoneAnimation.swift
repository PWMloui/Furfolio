//
//  DashboardMilestoneAnimation.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Animated badge for milestone celebration.
/// Use for revenue goals, appointment streaks, loyalty rewards, etc.
struct DashboardMilestoneAnimation: View {
    /// Bind to the triggering logic (e.g. achievedGoal = true).
    @Binding var trigger: Bool

    /// Emoji representing the milestone (decorative only).
    var emoji: String = "🏆"

    /// Primary label (e.g. \"Milestone!\").
    var label: String = "Milestone!"

    /// Badge color theme.
    var color: Color = .yellow

    /// Optional subtitle (e.g. \"You hit $10K!\").
    var subtitle: String? = nil

    /// Whether to show animated confetti.
    var showConfetti: Bool = true

    @State private var animate: Bool = false
    @State private var shine: Bool = false

    private enum Constants {
        static let appearDelay: Double = 0.05
        static let shineStartDelay: Double = 0.38
        static let shineDuration: Double = 0.66
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
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 38))
                    .scaleEffect(animate ? 1.13 : 0.88)
                    .shadow(color: color.opacity(0.21), radius: 6, x: 0, y: 4)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.headline.bold())
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
                                .mask(Text(label).font(.headline.bold()))
                                .animation(.linear(duration: Constants.shineDuration), value: shine)
                            : nil
                        )

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(color.opacity(0.11))
                    .shadow(color: color.opacity(0.19), radius: animate ? 16 : 7, x: 0, y: 2)
            )
            .scaleEffect(animate ? 1.0 : 0.8)
            .opacity(animate ? 1.0 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label). \(subtitle ?? "")")
            .onAppear {
                if trigger {
                    animateBadge()
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    animateBadge()
                }
            }
        }
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: animate)
    }

    /// Triggers the milestone badge and shine animation.
    private func animateBadge() {
        animate = false
        shine = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.appearDelay) {
            withAnimation {
                animate = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.shineStartDelay) {
                shine = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.shineDuration) {
                    shine = false
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardMilestoneAnimation_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 36) {
                Button("Trigger Milestone") {
                    show.toggle()
                }
                DashboardMilestoneAnimation(
                    trigger: $show,
                    emoji: "💸",
                    label: "Revenue Goal!",
                    color: .green,
                    subtitle: "You hit $10K this month!",
                    showConfetti: true
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
