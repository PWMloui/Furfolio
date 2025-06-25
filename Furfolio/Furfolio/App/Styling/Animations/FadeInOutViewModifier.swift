//
//  FadeInOutViewModifier.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, accessible, modular, preview/testable, and robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol FadeInOutAnalyticsLogger {
    func log(event: String, isVisible: Bool, label: String?)
}
public struct NullFadeInOutAnalyticsLogger: FadeInOutAnalyticsLogger {
    public init() {}
    public func log(event: String, isVisible: Bool, label: String?) {}
}

// MARK: - FadeInOutViewModifier

/// A view modifier that applies a fade-in/out transition based on a Boolean binding.
/// Use for simple appear/disappear animations with optional delays, analytics logging, and tokenized curves/durations.
struct FadeInOutViewModifier: ViewModifier {
    @Binding var isVisible: Bool

    /// Duration of the fade animation (tokenized).
    var fadeDuration: Double = AppAnimation.Durations.standard
    /// Optional delay before fade in (tokenized).
    var fadeInDelay: Double = 0.0
    /// Optional delay before fade out (tokenized).
    var fadeOutDelay: Double = 0.0
    /// Optional animation curve (tokenized).
    var curve: Animation = AppAnimation.Curves.easeInOut
    /// Optional accessibility label.
    var accessibilityLabel: String? = nil
    /// Optional analytics logger (preview/test/enterprise/QA).
    var analyticsLogger: FadeInOutAnalyticsLogger = NullFadeInOutAnalyticsLogger()

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
            .accessibilityLabel(accessibilityLabel != nil ? Text(accessibilityLabel!) : nil)
            .onChange(of: isVisible) { newValue in
                analyticsLogger.log(event: "fadeInOut_changed", isVisible: newValue, label: accessibilityLabel)
            }
            .onAppear {
                analyticsLogger.log(event: "fadeInOut_appear", isVisible: isVisible, label: accessibilityLabel)
            }
    }
}

extension View {
    /// Applies a fade-in/out animation based on a Boolean binding, with tokenized defaults and analytics.
    func fadeInOut(
        isVisible: Binding<Bool>,
        fadeDuration: Double = AppAnimation.Durations.standard,
        fadeInDelay: Double = 0.0,
        fadeOutDelay: Double = 0.0,
        curve: Animation = AppAnimation.Curves.easeInOut,
        accessibilityLabel: String? = nil,
        analyticsLogger: FadeInOutAnalyticsLogger = NullFadeInOutAnalyticsLogger()
    ) -> some View {
        self.modifier(FadeInOutViewModifier(
            isVisible: isVisible,
            fadeDuration: fadeDuration,
            fadeInDelay: fadeInDelay,
            fadeOutDelay: fadeOutDelay,
            curve: curve,
            accessibilityLabel: accessibilityLabel,
            analyticsLogger: analyticsLogger
        ))
    }
}

// MARK: - Preview

#if DEBUG
struct FadeInOutViewModifier_Previews: PreviewProvider {
    struct SpyLogger: FadeInOutAnalyticsLogger {
        func log(event: String, isVisible: Bool, label: String?) {
            print("[FadeInOutAnalytics] \(event): \(isVisible ? "Visible" : "Hidden") \(label ?? "")")
        }
    }
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
                    .fadeInOut(
                        isVisible: $show,
                        accessibilityLabel: "Green Box",
                        analyticsLogger: SpyLogger()
                    )

                Text("Example 2 - Delayed Fade")
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                    .fadeInOut(
                        isVisible: $show,
                        fadeDuration: 0.6,
                        fadeInDelay: 0.2,
                        accessibilityLabel: "Blue Box",
                        analyticsLogger: SpyLogger()
                    )
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
