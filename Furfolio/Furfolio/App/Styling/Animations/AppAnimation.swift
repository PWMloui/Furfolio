//
//  AppAnimation.swift
//  Furfolio
//
//  Enhanced: All animation, curve, and transition tokens centralized, analytics/audit-ready, preview/test-injectable, extensible, and fully documented.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol AnimationAnalyticsLogger {
    func log(event: String, info: String)
}
public struct NullAnimationAnalyticsLogger: AnimationAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String) {}
}

/// Unified namespace for all app-standard animation curves, durations, and transitions.
public enum AppAnimation {

    // MARK: - Durations (tokenized for design system)
    public enum Durations {
        public static let ultraFast: Double = AppTheme.Animation.ultraFast ?? 0.10
        public static let fast: Double      = AppTheme.Animation.fast ?? 0.18
        public static let standard: Double  = AppTheme.Animation.standard ?? 0.35
        public static let slow: Double      = AppTheme.Animation.slow ?? 0.60
        public static let extraSlow: Double = AppTheme.Animation.extraSlow ?? 0.98
    }

    // MARK: - Curves
    public enum Curves {
        /// App standard easeInOut
        public static let easeInOut = Animation.easeInOut(duration: Durations.standard)
        /// App standard spring
        public static let spring = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.25)
        /// Subtle, snappy, or bouncy for advanced micro-interactions
        public static let subtle = Animation.easeInOut(duration: 0.22)
        public static let elastic = Animation.interpolatingSpring(stiffness: 190, damping: 8)
        public static let bounce = Animation.spring(response: 0.33, dampingFraction: 0.54)
        public static let snappy = Animation.interpolatingSpring(stiffness: 330, damping: 12)
    }
    
    // MARK: - Transitions
    public enum Transitions {
        /// Fade in/out
        public static let fade = AnyTransition.opacity.animation(Curves.easeInOut)
        /// Slide in from trailing edge and fade
        public static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity).animation(Curves.easeInOut)
        /// Scale up and fade in
        public static let scale = AnyTransition.scale.combined(with: .opacity).animation(Curves.spring)
        /// Pop/elastic scale
        public static let pop = AnyTransition.scale(scale: 0.7, anchor: .center).combined(with: .opacity).animation(Curves.elastic)
        /// Bounce in/out
        public static let bounce = AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(Curves.bounce)
        /// Custom spring slide (with analytics logging)
        public static func springSlide(
            from edge: Edge = .trailing,
            analyticsLogger: AnimationAnalyticsLogger = NullAnimationAnalyticsLogger()
        ) -> AnyTransition {
            analyticsLogger.log(event: "transition_used", info: "springSlide from \(edge)")
            return .asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity).animation(Curves.spring),
                removal: .move(edge: edge.opposite).combined(with: .opacity).animation(Curves.easeInOut)
            )
        }
        /// Fully custom transition builder for future extension
        public static func custom(
            insertion: AnyTransition,
            removal: AnyTransition,
            animation: Animation = Curves.spring
        ) -> AnyTransition {
            .asymmetric(
                insertion: insertion.animation(animation),
                removal: removal.animation(animation)
            )
        }
    }
}

// MARK: - Private Helpers

private extension Edge {
    /// Returns the opposite edge, used for asymmetric removal transitions.
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}


// MARK: - Preview

#if DEBUG
struct AppAnimation_Previews: PreviewProvider {
    struct PreviewLogger: AnimationAnalyticsLogger {
        func log(event: String, info: String) {
            print("[AnimationAnalytics] \(event): \(info)")
        }
    }
    struct PreviewWrapper: View {
        @State private var showFade = false
        @State private var showSlide = false
        @State private var showScale = false
        @State private var showPop = false
        @State private var showBounce = false

        let analyticsLogger = PreviewLogger()

        var body: some View {
            VStack(spacing: 24) {
                Button("Toggle Fade") { showFade.toggle() }
                if showFade {
                    Text("Fade In & Out")
                        .padding()
                        .background(AppTheme.Colors.success.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.fade)
                }

                Button("Toggle Slide") { showSlide.toggle() }
                if showSlide {
                    Text("Slides In & Out")
                        .padding()
                        .background(AppTheme.Colors.primary.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.slide)
                }

                Button("Toggle Scale") { showScale.toggle() }
                if showScale {
                    Text("Scales In & Out")
                        .padding()
                        .background(AppTheme.Colors.warning.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.scale)
                }

                Button("Toggle Pop") { showPop.toggle() }
                if showPop {
                    Text("Pop/Elastic Transition")
                        .padding()
                        .background(AppTheme.Colors.loyaltyYellow.opacity(0.18))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.pop)
                }

                Button("Toggle Bounce") { showBounce.toggle() }
                if showBounce {
                    Text("Bounce In/Out")
                        .padding()
                        .background(AppTheme.Colors.milestoneBlue.opacity(0.18))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.bounce)
                }
            }
            .animation(AppAnimation.Curves.spring, value: showFade)
            .animation(AppAnimation.Curves.spring, value: showSlide)
            .animation(AppAnimation.Curves.spring, value: showScale)
            .animation(AppAnimation.Curves.elastic, value: showPop)
            .animation(AppAnimation.Curves.bounce, value: showBounce)
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
