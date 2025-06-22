//
//  PulseButtonStyle.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A button style that applies a pulsing animation when pressed, optionally with shadow and haptic feedback.
struct PulseButtonStyle: ButtonStyle {
    /// Main color used for ring and shadow.
    var color: Color = .accentColor
    /// Scale applied when pressed.
    var scale: CGFloat = 1.09
    /// Shadow color applied during pulse.
    var shadowColor: Color = .accentColor.opacity(0.19)
    /// Shadow blur radius.
    var shadowRadius: CGFloat = 9
    /// Animation duration for scale/shadow.
    var pulseDuration: Double = 0.21
    /// Whether to show shadow effect.
    var useShadow: Bool = true

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
    }
}
// MARK: - Preview
#if DEBUG
struct PulseButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            Button("Pulse Action") { }
                .buttonStyle(PulseButtonStyle(color: .pink))
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
            .buttonStyle(PulseButtonStyle(color: .green, scale: 1.12, shadowColor: .green.opacity(0.22)))
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
