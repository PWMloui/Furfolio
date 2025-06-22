//
//  AnimationConfig.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//  Refactored for clarity, maintainability, and accessibility.
//

import SwiftUI

/// A centralized collection of standard animation durations and curves used across Furfolio.
enum AppAnimation {

    // MARK: - Timing Durations
    enum Duration {
        /// Very fast: use for small UI tweaks.
        static let fast: Double = 0.18
        /// Default timing for most transitions.
        static let standard: Double = 0.35
        /// Slow transitions for modal/context changes.
        static let slow: Double = 0.60
        /// Extra-slow animations for dramatic or attention-grabbing effects.
        static let extraSlow: Double = 1.00
    }

    // MARK: - Easing Animations
    enum Curve {
        /// Ease in with standard duration.
        static let easeIn = Animation.easeIn(duration: Duration.standard)
        /// Ease out with standard duration.
        static let easeOut = Animation.easeOut(duration: Duration.standard)
        /// Ease in/out with standard duration.
        static let easeInOut = Animation.easeInOut(duration: Duration.standard)
        /// Linear curve with standard duration.
        static let linear = Animation.linear(duration: Duration.standard)
        /// Spring animation tuned for natural transitions.
        static let spring = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.25)
        /// Bouncy interpolating spring for celebration or highlight effects.
        static let bounce = Animation.interpolatingSpring(stiffness: 220, damping: 15)
        /// Quick ease-in for short interactions (renamed from 'dash').
        static let quickEaseIn = Animation.easeIn(duration: Duration.fast)
        /// Subtle animation for hinting UI changes.
        static let subtle = Animation.easeInOut(duration: 0.22)
    }

    // MARK: - Custom Transitions
    enum Transition {
        /// Fade transition using easeInOut.
        static let fade = AnyTransition.opacity.animation(Curve.easeInOut)
        /// Slide from trailing edge + fade.
        static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity).animation(Curve.easeInOut)
        /// Scale in/out + fade.
        static let scale = AnyTransition.scale.combined(with: .opacity).animation(Curve.easeInOut)
    }
}

// MARK: - View Convenience Extensions

extension View {
    /// Apply a fade-in/out transition using the app default.
    func appFadeTransition() -> some View {
        self.transition(AppAnimation.Transition.fade)
    }

    /// Apply a slide-in from the right edge transition.
    func appSlideTransition() -> some View {
        self.transition(AppAnimation.Transition.slide)
    }

    /// Apply a scale and fade transition.
    func appScaleTransition() -> some View {
        self.transition(AppAnimation.Transition.scale)
    }
}
