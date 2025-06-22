//
//  AnimationUtils.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Centralized animation utilities for Furfolio UI/UX.
enum AnimationUtils {

    // MARK: - Timing Durations
    enum Duration {
        /// Very fast animations (e.g. taps)
        static let quick: Double = 0.18
        /// Standard fade/slide
        static let regular: Double = 0.35
        /// Slow transitions for focus or detail
        static let slow: Double = 0.8
        /// Shimmer effect cycle
        static let shimmer: Double = 1.3
    }

    // MARK: - Standard Animations
    enum Style {
        /// Spring animation for natural movement
        static let spring = Animation.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.3)
        /// Fast ease-in animation
        static let quickEaseIn = Animation.easeIn(duration: Duration.quick)
        /// Regular ease-in-out fade
        static let fade = Animation.easeInOut(duration: Duration.regular)
        /// Long fade animation
        static let slowFade = Animation.easeInOut(duration: Duration.slow)
        /// Pulsing repeating animation (used in badges, alerts)
        static let pulse = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        /// Linear shimmer loop
        static let shimmer = Animation.linear(duration: Duration.shimmer).repeatForever(autoreverses: false)
    }

    // MARK: - Transitions
    enum Transition {
        /// Slide up with fade for incoming views
        static var slideUp: AnyTransition {
            .move(edge: .bottom).combined(with: .opacity)
        }

        /// Pop in with scale + fade
        static var pop: AnyTransition {
            .scale.combined(with: .opacity)
        }

        /// Repeating shimmer placeholder
        static var shimmer: AnyTransition {
            .opacity.animation(Style.shimmer)
        }
    }

    // MARK: - Shimmer Effect
    struct ShimmerView: View {
        @State private var phase: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.23),
                        Color.gray.opacity(0.42),
                        Color.gray.opacity(0.23)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.15)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: phase * geo.size.width)
                )
                .onAppear {
                    withAnimation(Style.shimmer) {
                        phase = 1
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}
// MARK: - Preview

#if DEBUG
struct AnimationUtilsPreview: View {
    @State private var showSlide = false
    @State private var showPop = false

    var body: some View {
        VStack(spacing: 32) {
            Button("Toggle SlideUp") {
                withAnimation(AnimationUtils.Style.spring) { showSlide.toggle() }
            }

            if showSlide {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.blue)
                    .frame(width: 120, height: 44)
                    .transition(AnimationUtils.Transition.slideUp)
            }

            Button("Toggle Pop") {
                withAnimation(AnimationUtils.Style.fade) { showPop.toggle() }
            }

            if showPop {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.purple)
                    .frame(width: 120, height: 44)
                    .transition(AnimationUtils.Transition.pop)
            }

            VStack {
                Text("Shimmer Loading")
                    .font(.headline)
                AnimationUtils.ShimmerView()
                    .frame(width: 180, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding()
    }
}

#Preview {
    AnimationUtilsPreview()
}
#endif
