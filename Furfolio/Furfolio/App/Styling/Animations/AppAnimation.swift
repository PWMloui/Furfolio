//
//  AppAnimation.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: This file unifies and replaces AnimationConfig.swift and AnimationUtils.swift,
//  creating a single source of truth for all animation and transition values in the app.
//

import SwiftUI

/// A centralized namespace for all standard animation curves, durations, and transitions used throughout Furfolio.
public enum AppAnimation {

    // MARK: - Durations
    
    /// A collection of standard animation durations.
    public enum Durations {
        public static let fast: Double      = 0.18
        public static let standard: Double  = 0.35
        public static let slow: Double      = 0.60
    }

    // MARK: - Curves
    
    /// A collection of standard animation curves.
    public enum Curves {
        public static let easeInOut = Animation.easeInOut(duration: Durations.standard)
        public static let spring = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.25)
        public static let subtle = Animation.easeInOut(duration: 0.22)
    }
    
    // MARK: - Transitions

    /// A collection of standard view transitions.
    public enum Transitions {
        /// A simple fade-in/out transition.
        public static let fade = AnyTransition.opacity.animation(Curves.easeInOut)
        
        /// A transition that slides in from the trailing edge and fades.
        public static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity).animation(Curves.easeInOut)
        
        /// A transition that scales up and fades in.
        public static let scale = AnyTransition.scale.combined(with: .opacity).animation(Curves.spring)
        
        /// A custom slide transition with a spring effect that can be applied from any edge.
        public static func springSlide(from edge: Edge = .trailing) -> AnyTransition {
            .asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity).animation(Curves.spring),
                removal: .move(edge: edge.opposite).combined(with: .opacity).animation(Curves.easeInOut)
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
    struct PreviewWrapper: View {
        @State private var showFade = false
        @State private var showSlide = false
        @State private var showScale = false

        var body: some View {
            VStack(spacing: 20) {
                
                // --- Fade Transition ---
                Button("Toggle Fade Transition") { showFade.toggle() }
                if showFade {
                    Text("Fades In & Out")
                        .padding()
                        .background(AppTheme.Colors.success.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.fade)
                }
                
                // --- Slide Transition ---
                Button("Toggle Slide Transition") { showSlide.toggle() }
                if showSlide {
                    Text("Slides In & Out")
                        .padding()
                        .background(AppTheme.Colors.primary.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.slide)
                }
                
                // --- Scale Transition ---
                Button("Toggle Scale Transition") { showScale.toggle() }
                if showScale {
                    Text("Scales In & Out")
                        .padding()
                        .background(AppTheme.Colors.warning.opacity(0.2))
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .transition(AppAnimation.Transitions.scale)
                }
            }
            .animation(AppAnimation.Curves.spring, value: showFade)
            .animation(AppAnimation.Curves.spring, value: showSlide)
            .animation(AppAnimation.Curves.spring, value: showScale)
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
