//
//  TransitionManager.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, accessible, modular, preview/testable, and robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol TransitionAnalyticsLogger {
    func log(event: String, transition: TransitionManager.TransitionType, screen: TransitionManager.Screen?, modal: Bool)
}
public struct NullTransitionAnalyticsLogger: TransitionAnalyticsLogger {
    public init() {}
    public func log(event: String, transition: TransitionManager.TransitionType, screen: TransitionManager.Screen?, modal: Bool) {}
}

/// A centralized manager for Furfolio's custom transitions, navigation flows, and modal management.
/// Enhanced for business analytics, accessibility, QA, and design token compliance.
@MainActor
final class TransitionManager: ObservableObject {
    static let shared = TransitionManager()
    
    // MARK: - Analytics DI (for BI/QA/Trust Center/preview)
    public static var analyticsLogger: TransitionAnalyticsLogger = NullTransitionAnalyticsLogger()
    
    // Track current view state for navigation
    @Published var activeScreen: Screen = .dashboard
    
    // Custom presentation modifiers
    @Published var showModal: Bool = false
    @Published var modalContent: AnyView? = nil
    @Published var transitionType: TransitionType = .springSlide
    
    // Accessibility: Last announced screen/modal (for voiceOver and testing)
    @Published var lastAnnouncement: String = ""
    
    enum Screen: String, CaseIterable, CustomStringConvertible {
        case dashboard, onboarding, ownerDetail, appointmentDetail, settings
        var description: String { rawValue }
    }
    
    /// Defines supported transitions used in Furfolio's navigation and modal presentations.
    enum TransitionType: CustomStringConvertible, Equatable {
        /// Slide transition with spring animation (default).
        case springSlide
        /// Opacity-based fade in/out.
        case fadeInOut
        /// Scales in and out from center.
        case scale
        /// A fully custom transition provided at runtime.
        case custom(AnyTransition, Animation)
        
        /// The SwiftUI transition to apply.
        var transition: AnyTransition {
            switch self {
            case .springSlide:
                return .springSlide(edge: .trailing, analyticsLogger: TransitionManager.analyticsLogger)
            case .fadeInOut:
                return .opacity
            case .scale:
                return .scale
            case .custom(let t, _):
                return t
            }
        }
        
        /// The associated animation for the transition.
        var animation: Animation {
            switch self {
            case .springSlide:
                return .interpolatingSpring(
                    stiffness: AppTheme.Animation.springSlideInsertionStiffness ?? 260,
                    damping: AppTheme.Animation.springSlideInsertionDamping ?? 26
                )
            case .fadeInOut:
                return .easeInOut(duration: AppTheme.Animation.fast ?? 0.18)
            case .scale:
                return .easeInOut(duration: AppTheme.Animation.standard ?? 0.35)
            case .custom(_, let anim):
                return anim
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
        
        static func == (lhs: TransitionType, rhs: TransitionType) -> Bool {
            lhs.description == rhs.description // Sufficient for our use, as custom is always different
        }
    }
    
    private init() {}
    
    // MARK: - Modal presentation
    
    /// Presents a modal with the specified view and transition type.
    func presentModal<Content: View>(
        @ViewBuilder content: () -> Content,
        transition: TransitionType = .springSlide,
        accessibilityAnnouncement: String? = nil
    ) {
        self.modalContent = AnyView(content())
        self.transitionType = transition
        self.showModal = true
        TransitionManager.analyticsLogger.log(event: "present_modal", transition: transition, screen: nil, modal: true)
        if let announcement = accessibilityAnnouncement {
            announce(announcement)
        }
    }
    
    /// Dismisses any currently presented modal.
    func dismissModal(announce: String? = nil) {
        self.showModal = false
        TransitionManager.analyticsLogger.log(event: "dismiss_modal", transition: transitionType, screen: nil, modal: true)
        if let message = announce {
            self.announce(message)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.modalContent = nil
        }
    }
    
    // MARK: - Screen navigation
    
    /// Switch the active app screen with an optional transition.
    func switchScreen(
        to screen: Screen,
        with transition: TransitionType = .springSlide,
        accessibilityAnnouncement: String? = nil
    ) {
        withAnimation(transition.animation) {
            self.transitionType = transition
            self.activeScreen = screen
            TransitionManager.analyticsLogger.log(event: "switch_screen", transition: transition, screen: screen, modal: false)
            if let announcement = accessibilityAnnouncement {
                self.announce(announcement)
            }
        }
    }
    
    /// Announce for accessibility (VoiceOver/QA). Can be observed in tests or for user guidance.
    private func announce(_ message: String) {
        lastAnnouncement = message
        UIAccessibility.post(notification: .announcement, argument: message)
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
                        .onTapGesture { tm.dismissModal(announce: NSLocalizedString("Modal dismissed.", comment: "")) }
                }
            }
        )
        .animation(tm.transitionType.animation, value: tm.showModal)
        .animation(tm.transitionType.animation, value: tm.activeScreen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("App main screen: \(tm.activeScreen.description)"))
        .accessibilityValue(Text("Transition: \(tm.transitionType.description)"))
        .accessibilityHint(Text(tm.lastAnnouncement))
    }
}
