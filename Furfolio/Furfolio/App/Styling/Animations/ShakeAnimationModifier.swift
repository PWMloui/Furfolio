//
//  ShakeAnimationModifier.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, haptic/accessible, modular, preview/testable, robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol ShakeAnimationAnalyticsLogger {
    func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int)
}
public struct NullShakeAnimationAnalyticsLogger: ShakeAnimationAnalyticsLogger {
    public init() {}
    public func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int) {}
}

// MARK: - ShakeAnimationModifier

/// A geometry effect for horizontal shake animation with analytics/haptics/accessibility support.
struct ShakeAnimationModifier: GeometryEffect {
    /// Unique value that increments to trigger the shake animation.
    var trigger: Int

    /// Horizontal displacement of the shake (in points). Tokenized, fallback to 12.
    var amplitude: CGFloat = AppSpacing.shakeAmplitude ?? 12

    /// Number of shake oscillations. Tokenized, fallback to 4.
    var shakes: Int = AppTheme.Animation.shakeOscillations ?? 4

    /// Optional analytics logger for BI/QA/Trust Center.
    var analyticsLogger: ShakeAnimationAnalyticsLogger = NullShakeAnimationAnalyticsLogger()

    /// Whether to trigger haptic feedback on shake (iOS only).
    var haptics: Bool = true

    /// Optional accessibility label.
    var accessibilityLabel: String? = nil

    /// Required by `GeometryEffect` to animate on trigger change.
    var animatableData: CGFloat {
        get { CGFloat(trigger) }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(.pi * CGFloat(shakes) * animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }

    // MARK: - Animate on trigger change
    func body(content: Content) -> some View {
        content
            .modifier(self)
            .accessibilityLabel(accessibilityLabel != nil ? Text(accessibilityLabel!) : Text("Shake animation"))
            .accessibilityHint(Text("This view shakes to indicate invalid input or error"))
            .accessibilityValue(Text(trigger % 2 == 0 ? "Stable" : "Shaking"))
            .onChange(of: trigger) { newValue in
                analyticsLogger.log(event: "shake_triggered", trigger: newValue, amplitude: amplitude, shakes: shakes)
                if haptics {
                    ShakeAnimationModifier.triggerHaptic()
                }
            }
    }

    /// Haptic feedback (iOS only, non-blocking)
    static func triggerHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Apply a horizontal shake animation with design tokens, analytics, haptics, and accessibility.
    /// - Parameters:
    ///   - trigger: Increment to trigger the animation.
    ///   - amplitude: The shake distance (tokenized, fallback to 12).
    ///   - shakes: Number of oscillations (tokenized, fallback to 4).
    ///   - haptics: Whether to trigger haptic feedback (default: true).
    ///   - analyticsLogger: Protocol-based logger for BI/QA (default: Null).
    ///   - accessibilityLabel: Custom accessibility label.
    func shake(
        trigger: Int,
        amplitude: CGFloat = AppSpacing.shakeAmplitude ?? 12,
        shakes: Int = AppTheme.Animation.shakeOscillations ?? 4,
        haptics: Bool = true,
        analyticsLogger: ShakeAnimationAnalyticsLogger = NullShakeAnimationAnalyticsLogger(),
        accessibilityLabel: String? = nil
    ) -> some View {
        self.modifier(
            ShakeAnimationModifier(
                trigger: trigger,
                amplitude: amplitude,
                shakes: shakes,
                analyticsLogger: analyticsLogger,
                haptics: haptics,
                accessibilityLabel: accessibilityLabel
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ShakeAnimationModifier_Previews: PreviewProvider {
    struct SpyLogger: ShakeAnimationAnalyticsLogger {
        func log(event: String, trigger: Int, amplitude: CGFloat, shakes: Int) {
            print("[ShakeAnalytics] \(event) trigger:\(trigger) amp:\(amplitude) shakes:\(shakes)")
        }
    }
    struct PreviewWrapper: View {
        @State private var trigger = 0

        var body: some View {
            VStack(spacing: 30) {
                Button("Shake!") {
                    trigger += 1
                }

                Text("Shake Me!")
                    .font(.headline)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                    .shake(
                        trigger: trigger,
                        analyticsLogger: SpyLogger(),
                        accessibilityLabel: "Shaking orange box"
                    )
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
