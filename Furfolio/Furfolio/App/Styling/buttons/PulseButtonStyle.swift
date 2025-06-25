//
//  PulseButtonStyle.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, accessible, preview/testable, business/QA robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol PulseButtonAnalyticsLogger {
    func log(event: String, color: Color, pressed: Bool)
}
public struct NullPulseButtonAnalyticsLogger: PulseButtonAnalyticsLogger {
    public init() {}
    public func log(event: String, color: Color, pressed: Bool) {}
}

// MARK: - PulseButtonStyle

/// A button style that applies a pulsing animation when pressed, with shadow, haptics, audit/analytics, and token-based theming.
struct PulseButtonStyle: ButtonStyle {
    // MARK: - Theming Tokens (safe fallback)
    var color: Color = AppColors.accent ?? .accentColor
    var scale: CGFloat = AppSpacing.pulseButtonScale ?? 1.09
    var shadowColor: Color = (AppColors.accent ?? .accentColor).opacity(0.19)
    var shadowRadius: CGFloat = AppRadius.buttonShadow ?? 9
    var pulseDuration: Double = AppTheme.Animation.pulse ?? 0.21
    var useShadow: Bool = true
    var haptics: Bool = true
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil

    // Analytics logger for QA/BI/Trust Center
    var analyticsLogger: PulseButtonAnalyticsLogger = NullPulseButtonAnalyticsLogger()

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .scaleEffect(isPressed ? scale : 1.0)
            .shadow(
                color: isPressed && useShadow ? shadowColor : .clear,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
            .animation(.easeOut(duration: pulseDuration), value: isPressed)
            .overlay(
                Circle()
                    .stroke(color.opacity(isPressed ? 0.28 : 0.0), lineWidth: isPressed ? 5 : 0)
                    .scaleEffect(isPressed ? 1.35 : 0.5)
                    .opacity(isPressed ? 0.9 : 0)
                    .animation(.easeOut(duration: 0.26), value: isPressed)
                    .accessibilityHidden(true) // Decorative only
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel != nil ? Text(accessibilityLabel!) : nil)
            .accessibilityHint(accessibilityHint != nil ? Text(accessibilityHint!) : nil)
            .onChange(of: isPressed) { pressed in
                if pressed && haptics {
                    PulseButtonStyle.triggerHaptic()
                }
                analyticsLogger.log(event: pressed ? "pulse_pressed" : "pulse_released", color: color, pressed: pressed)
            }
    }

    // MARK: - Haptic Feedback
    private static func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct PulseButtonStyle_Previews: PreviewProvider {
    struct SpyLogger: PulseButtonAnalyticsLogger {
        func log(event: String, color: Color, pressed: Bool) {
            print("PulseAnalytics: \(event) color:\(color) pressed:\(pressed)")
        }
    }
    static var previews: some View {
        VStack(spacing: 32) {
            Button("Pulse Action") { }
                .buttonStyle(
                    PulseButtonStyle(
                        color: .pink,
                        accessibilityLabel: "Pulse Action",
                        accessibilityHint: "Tap to perform a pink pulse action",
                        analyticsLogger: SpyLogger()
                    )
                )
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(Color.pink.opacity(0.12))
                .cornerRadius(13)

            Button {
            } label: {
                Label("Confirm", systemImage: "checkmark.seal.fill")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(
                PulseButtonStyle(
                    color: .green,
                    scale: 1.12,
                    shadowColor: .green.opacity(0.22),
                    analyticsLogger: SpyLogger()
                )
            )
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
