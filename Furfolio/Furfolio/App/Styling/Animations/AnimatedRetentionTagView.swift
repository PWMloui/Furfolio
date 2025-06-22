
//  AnimatedRetentionTagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced for clarity, accessibility, and extensibility.
//

import SwiftUI

/// Animated badge for representing customer retention status.
struct AnimatedRetentionTagView: View {

    /// Enum describing retention states with appearance metadata.
    enum RetentionStatus {
        /// Client has not returned in a while — risk of churn.
        case retentionRisk
        /// Returning client — healthy engagement.
        case returning
        /// VIP client — highly loyal and active.

        case vip

        var label: String {
            switch self {
            case .retentionRisk: return "Retention Risk"
            case .returning: return "Returning"
            case .vip: return "VIP"
            }
        }

        var color: Color {
            switch self {
            case .retentionRisk: return .orange
            case .returning: return .green
            case .vip: return .purple
            }
        }

        var systemImage: String {
            switch self {
            case .retentionRisk: return "exclamationmark.triangle.fill"
            case .returning: return "arrow.triangle.2.circlepath"
            case .vip: return "star.fill"
            }
        }

        var emoji: String {
            switch self {
            case .retentionRisk: return "⚠️"
            case .returning: return "🔁"
            case .vip: return "💎"
            }
        }
    }

    /// Retention status to display.
    var status: RetentionStatus

    /// If true, show emoji instead of SF Symbol.
    var useEmoji: Bool = false

    /// If true, pulse animation is active.
    var pulse: Bool = true

    @State private var animateIn: Bool = false
    @State private var pulseAnim: Bool = false

    private enum Constants {
        static let baseScale: CGFloat = 0.8
        static let pulseScale: CGFloat = 1.1
        static let appearDuration: Double = 0.4
        static let pulseDuration: Double = 1.0
    }

    var body: some View {
        HStack(spacing: 6) {
            if useEmoji {
                Text(status.emoji)
                    .font(.system(size: 17))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: status.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
            }

            Text(status.label)
                .font(.caption)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(animateIn ? 0.93 : 0.68))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .scaleEffect(scaleFactor)
        .shadow(color: status.color.opacity(0.25), radius: animateIn ? 5 : 1, x: 0, y: 2)
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: Constants.appearDuration, dampingFraction: 0.72)) {
                animateIn = true
            }
            if pulse {
                withAnimation(Animation.easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true)) {
                    pulseAnim = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(status.label) tag"))
        .accessibilityHint("Indicates customer loyalty status")
    }

    private var scaleFactor: CGFloat {
        guard animateIn else { return Constants.baseScale }
        return pulse && pulseAnim ? Constants.pulseScale : 1.0
    }
}

#if DEBUG
struct AnimatedRetentionTagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 28) {
            AnimatedRetentionTagView(status: .retentionRisk)
            AnimatedRetentionTagView(status: .returning, useEmoji: true, pulse: false)
            AnimatedRetentionTagView(status: .vip, pulse: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
