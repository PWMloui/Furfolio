//
//  AnimatedEmptyStateView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// An animated placeholder view for empty states in lists or onboarding screens.
/// Provides an animated emoji with optional action and message.
///
/// - Parameters:
///   - emoji: An emoji representing the context (e.g., 🐾 or 📂).
///   - title: Bold title for the empty state.
///   - message: Optional supporting explanation.
///   - actionLabel: Text for an optional call-to-action button.
///   - action: Closure to invoke when button is tapped.
struct AnimatedEmptyStateView: View {
    var emoji: String = "🐾"
    var title: String = "No Data Yet"
    var message: String = "Once you add items, they’ll show up here!"
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    @State private var animate = false

    private enum Constants {
        static let circleSize: CGFloat = 110
        static let emojiSize: CGFloat = 60
        static let animationDuration: Double = 1.2
        static let scaleRange: ClosedRange<CGFloat> = 0.94...1.08
        static let rotationAngle: Double = 9
        static let offsetRange: ClosedRange<CGFloat> = -7...7
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.13))
                    .frame(width: Constants.circleSize, height: Constants.circleSize)
                    .scaleEffect(animate ? Constants.scaleRange.upperBound : Constants.scaleRange.lowerBound)
                    .animation(.easeInOut(duration: Constants.animationDuration).repeatForever(autoreverses: true), value: animate)

                Text(emoji)
                    .font(.system(size: Constants.emojiSize))
                    .rotationEffect(.degrees(animate ? Constants.rotationAngle : -Constants.rotationAngle))
                    .offset(y: animate ? Constants.offsetRange.lowerBound : Constants.offsetRange.upperBound)
                    .animation(.interpolatingSpring(stiffness: 140, damping: 9).repeatForever(autoreverses: true), value: animate)
                    .accessibilityLabel(Text("Empty state icon: \(emoji)"))
            }
            .padding(.top, 16)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if let label = actionLabel, let action = action {
                Button(label, action: action)
                    .buttonStyle(PulseButtonStyle(color: .accentColor))
                    .padding(.top, 8)
                    .accessibilityLabel("Button: \(label)")
            }
        }
        .frame(maxWidth: 350)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animate = true }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct AnimatedEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnimatedEmptyStateView(
                emoji: "🐩",
                title: "No Dogs Added",
                message: "Add a new dog profile to see them listed here.",
                actionLabel: "Add Dog",
                action: {}
            )
            .previewLayout(.sizeThatFits)

            AnimatedEmptyStateView()
                .previewLayout(.sizeThatFits)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(.light)
    }
}
#endif
