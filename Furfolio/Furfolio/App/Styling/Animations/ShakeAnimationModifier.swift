//
//  ShakeAnimationModifier.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Refactored for clarity, accessibility, and future extension.
//

import SwiftUI

/// A geometry effect that applies a horizontal shake animation to a view.
/// Use `.modifier(ShakeAnimationModifier(trigger:))` or `.shake(trigger:)`.
struct ShakeAnimationModifier: GeometryEffect {
    /// Unique value that increments to trigger the shake animation.
    var trigger: Int

    /// Horizontal displacement of the shake (in points).
    var amplitude: CGFloat = 12

    /// Number of shake oscillations.
    var shakes: Int = 4

    /// Required by `GeometryEffect` to animate on trigger change.
    var animatableData: CGFloat {
        get { CGFloat(trigger) }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(.pi * CGFloat(shakes) * animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    /// Convenience method for applying shake animation.
    /// - Parameters:
    ///   - trigger: Increment this value to trigger the animation.
    ///   - amplitude: The distance the view moves during shake.
    ///   - shakes: The number of oscillations.
    func shake(trigger: Int, amplitude: CGFloat = 12, shakes: Int = 4) -> some View {
        self.modifier(ShakeAnimationModifier(trigger: trigger, amplitude: amplitude, shakes: shakes))
    }
}

// MARK: - Preview

#if DEBUG
struct ShakeAnimationModifier_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var trigger = 0

        var body: some View {
            VStack(spacing: 30) {
                Button("Shake!") {
                    trigger += 1
                    // Future: Add haptic feedback
                }

                Text("Shake Me!")
                    .font(.headline)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                    .shake(trigger: trigger)
                    .accessibilityHint("Shakes when triggered")
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif
