//
//  TransitionManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A centralized manager for Furfolio's custom transitions and navigation flows.
/// Supports advanced transitions, modal presentation, and state-driven view swapping.
@MainActor
final class TransitionManager: ObservableObject {
    static let shared = TransitionManager()

    // Track current view state for navigation (optional: replace with enum for multi-screen apps)
    @Published var activeScreen: Screen = .dashboard

    // Custom presentation modifiers
    @Published var showModal: Bool = false
    @Published var modalContent: AnyView? = nil
    @Published var transitionType: TransitionType = .springSlide

    enum Screen {
        case dashboard, onboarding, ownerDetail, appointmentDetail, settings
        // Add more cases as your app grows
    }

    /// Defines supported transitions used in Furfolio's navigation and modal presentations.
    enum TransitionType: CustomStringConvertible {
        /// Slide transition with spring animation (default).
        case springSlide

        /// Opacity-based fade in/out.
        case fadeInOut

        /// Scales in and out from center.
        case scale

        /// A fully custom transition provided at runtime.
        case custom(AnyTransition)

        /// The SwiftUI transition to apply.
        var transition: AnyTransition {
            switch self {
            case .springSlide:
                return .springSlide(edge: .trailing)
            case .fadeInOut:
                return .opacity
            case .scale:
                return .scale
            case .custom(let t):
                return t
            }
        }

        /// The associated animation for the transition.
        var animation: Animation {
            switch self {
            case .springSlide:
                return .spring(response: 0.45, dampingFraction: 0.78)
            case .fadeInOut:
                return .easeInOut(duration: 0.3)
            case .scale:
                return .easeInOut(duration: 0.35)
            case .custom:
                return .default
            }
        }

        /// Debug description.
        var description: String {
            switch self {
            case .springSlide: return "springSlide"
            case .fadeInOut: return "fadeInOut"
            case .scale: return "scale"
            case .custom: return "custom"
            }
        }
    }

    private init() {}

    /// Presents a modal with the specified view and transition type.
    func presentModal<Content: View>(@ViewBuilder content: () -> Content, transition: TransitionType = .springSlide) {
        self.modalContent = AnyView(content())
        self.transitionType = transition
        self.showModal = true
    }

    /// Dismisses any currently presented modal.
    func dismissModal() {
        self.showModal = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { // match with transition
            self.modalContent = nil
        }
    }

    /// Switch the active app screen with an optional transition.
    func switchScreen(to screen: Screen, with transition: TransitionType = .springSlide) {
        withAnimation {
            self.transitionType = transition
            self.activeScreen = screen
        }
    }
}

// MARK: - Example SwiftUI usage

struct RootAppView: View {
    @StateObject var tm = TransitionManager.shared

    var body: some View {
        ZStack {
            switch tm.activeScreen {
            case .dashboard:
                DashboardView()
                    .transition(tm.transitionType.transition)
            case .onboarding:
                OnboardingView()
                    .transition(tm.transitionType.transition)
            case .ownerDetail:
                OwnerProfileView()
                    .transition(tm.transitionType.transition)
            case .appointmentDetail:
                AppointmentDetailView()
                    .transition(tm.transitionType.transition)
            case .settings:
                SettingsView()
                    .transition(tm.transitionType.transition)
            }
        }
        .overlay(
            Group {
                if tm.showModal, let modal = tm.modalContent {
                    modal
                        .transition(tm.transitionType.transition)
                        .zIndex(99)
                        .onTapGesture { tm.dismissModal() } // Tap outside to dismiss (optional)
                }
            }
        )
        .animation(.easeInOut(duration: 0.41), value: tm.showModal)
        .animation(.easeInOut(duration: 0.41), value: tm.activeScreen)
    }
}
