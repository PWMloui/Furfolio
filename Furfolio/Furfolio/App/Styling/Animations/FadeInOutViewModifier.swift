//
//  FadeInOutViewModifier.swift
//  Furfolio


import SwiftUI

/// A view modifier that applies a fade-in/out transition based on a Boolean binding.
/// Use for simple appear/disappear animations with optional delays.
struct FadeInOutViewModifier: ViewModifier {
    @Binding var isVisible: Bool

    /// Duration of the fade animation.
    var fadeDuration: Double = 0.38
    /// Optional delay before fade in.
    var fadeInDelay: Double = 0.0
    /// Optional delay before fade out.
    var fadeOutDelay: Double = 0.0
    /// Optional animation curve (default: easeInOut).
    var curve: Animation = .easeInOut

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(
                curve
                    .speed(1.0)
                    .delay(isVisible ? fadeInDelay : fadeOutDelay)
                    .duration(fadeDuration),
                value: isVisible
            )
            .accessibilityHidden(!isVisible)
    }
}

extension View {
    /// Applies a fade-in/out animation based on a Boolean binding.
    func fadeInOut(
        isVisible: Binding<Bool>,
        fadeDuration: Double = 0.38,
        fadeInDelay: Double = 0.0,
        fadeOutDelay: Double = 0.0,
        curve: Animation = .easeInOut
    ) -> some View {
        self.modifier(FadeInOutViewModifier(
            isVisible: isVisible,
            fadeDuration: fadeDuration,
            fadeInDelay: fadeInDelay,
            fadeOutDelay: fadeOutDelay,
            curve: curve
        ))
    }
}
// MARK: - Preview
#if DEBUG
struct FadeInOutViewModifier_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var show = false
        var body: some View {
            VStack(spacing: 30) {
                Button(show ? "Hide" : "Show") {
                    withAnimation { show.toggle() }
                }

                Text("Example 1")
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(10)
                    .fadeInOut(isVisible: $show)

                Text("Example 2 - Delayed Fade")
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                    .fadeInOut(isVisible: $show, fadeDuration: 0.6, fadeInDelay: 0.2)
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
