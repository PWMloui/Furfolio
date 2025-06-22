//
//  AnimatedBadgeView.swift
//  Furfolio

import SwiftUI

/// A reusable, animated badge component used to visually highlight tags, achievements, or alerts.
struct AnimatedBadgeView: View {

    /// The primary label shown inside the badge.
    var label: String

    /// An optional SF Symbol shown before the label.
    var systemImage: String? = nil

    /// An optional emoji shown before the label.
    var emoji: String? = nil

    /// Background color of the badge.
    var color: Color = .blue

    /// Whether the badge should pulse to draw attention.
    var pulse: Bool = false

    @State private var animateIn: Bool = false
    @State private var pulseAnim: Bool = false

    private enum Constants {
        static let baseScale: CGFloat = 0.8
        static let pulseScale: CGFloat = 1.08
        static let appearDuration: Double = 0.4
        static let pulseDuration: Double = 0.9
    }

    var body: some View {
        HStack(spacing: 5) {
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 17))
                    .accessibilityHidden(true)
            }

            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
            }

            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(animateIn ? 0.93 : 0.68))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .scaleEffect(scaleFactor)
        .shadow(color: color.opacity(0.24), radius: animateIn ? 4 : 1, x: 0, y: 1)
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: Constants.appearDuration, dampingFraction: 0.7)) {
                animateIn = true
            }
            if pulse {
                withAnimation(.easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true)) {
                    pulseAnim = true
                }
            }
        }
        .accessibilityLabel(Text(fullAccessibilityLabel))
    }

    private var scaleFactor: CGFloat {
        guard animateIn else { return Constants.baseScale }
        return pulse && pulseAnim ? Constants.pulseScale : 1.0
    }

    private var fullAccessibilityLabel: String {
        var components: [String] = []
        if let emoji = emoji {
            components.append(emoji)
        }
        if let icon = systemImage {
            components.append(icon)
        }
        components.append(label)
        return components.joined(separator: " ")
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 28) {
            AnimatedBadgeView(label: "Loyalty", systemImage: "star.fill", color: .yellow, pulse: true)
            AnimatedBadgeView(label: "Birthday", emoji: "🎂", color: .pink)
            AnimatedBadgeView(label: "Top Spender", systemImage: "dollarsign.circle.fill", color: .green)
            AnimatedBadgeView(label: "Risk", systemImage: "exclamationmark.triangle.fill", color: .orange, pulse: true)
            AnimatedBadgeView(label: "New", emoji: "✨", color: .purple)
        }
        .padding()
        .background(Color(.systemBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
