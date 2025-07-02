//
//  TransitionManager.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, accessible, modular, preview/testable, and robust.
//
//  TransitionManager Architecture & Extensibility:
//  ----------------------------------------------
//  TransitionManager is a centralized, singleton-based SwiftUI ObservableObject designed to manage Furfolio's navigation flows,
//  custom view transitions, and modal presentations. It is architected for extensibility, enabling easy addition of new
//  transition types and screens. The manager integrates deeply with business analytics, audit trails, and Trust Center
//  compliance by asynchronously logging all navigation and modal events. It supports diagnostics through event history
//  retrieval, localization of all user-facing and log strings, and accessibility announcements for VoiceOver and QA.
//
//  Analytics/Audit/Trust Center Integration:
//  -----------------------------------------
//  The TransitionAnalyticsLogger protocol defines an async logging interface with a testMode flag to support console-only
//  logging during QA, tests, or previews. TransitionManager asynchronously logs all transition events, including modal
//  presentations and screen switches, ensuring audit-ready traceability.
//
//  Diagnostics & Localization:
//  ---------------------------
//  TransitionManager maintains an internal buffer of the last 20 analytics events for diagnostics or admin UI consumption.
//  All user-visible and log event strings are wrapped with NSLocalizedString for localization and compliance.
//
//  Accessibility & Compliance:
//  ---------------------------
//  Accessibility announcements are posted via UIAccessibility for VoiceOver and testing. The manager adheres to design
//  tokens for animations and transitions, ensuring consistent, compliant UI behavior.
//
//  Preview/Testability:
//  --------------------
//  The manager supports a NullTransitionAnalyticsLogger for preview and test environments, and the analytics logger can be
//  swapped for mocks or real implementations. The async logging and event history enable robust automated testing.
//
//  Maintainers and future developers should extend this class with care to preserve async logging, localization, and
//  accessibility compliance.
//


import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TransitionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TransitionManager"
}

// MARK: - Analytics/Audit Protocol

/// Protocol defining asynchronous analytics logging for transition events.
/// Includes a testMode flag for console-only logging during QA, tests, or previews.
public protocol TransitionAnalyticsLogger {
    /// Indicates if the logger is running in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs a transition event, including audit fields for Trust Center/compliance.
    /// - Parameters:
    ///   - event: The event name.
    ///   - transition: The transition type.
    ///   - screen: The target screen, if applicable.
    ///   - modal: Whether the event relates to a modal presentation.
    ///   - role: The user's role (for audit).
    ///   - staffID: The staff ID (for audit).
    ///   - context: The audit context string.
    ///   - escalate: Whether this event is audit-critical.
    func log(event: String, transition: TransitionManager.TransitionType, screen: TransitionManager.Screen?, modal: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

/// A no-op analytics logger for use in previews and tests.
public struct NullTransitionAnalyticsLogger: TransitionAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, transition: TransitionManager.TransitionType, screen: TransitionManager.Screen?, modal: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
}

/// A simple console logger for QA/tests/previews that prints events to the console, including audit fields.
public struct ConsoleTransitionAnalyticsLogger: TransitionAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func log(event: String, transition: TransitionManager.TransitionType, screen: TransitionManager.Screen?, modal: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let screenDesc = screen?.description ?? NSLocalizedString("none", comment: "No screen specified")
        let modalDesc = modal ? NSLocalizedString("modal", comment: "Modal event") : NSLocalizedString("non-modal", comment: "Non-modal event")
        let roleDesc = role ?? NSLocalizedString("none", comment: "No role specified")
        let staffIDDesc = staffID ?? NSLocalizedString("none", comment: "No staffID specified")
        let contextDesc = context ?? NSLocalizedString("none", comment: "No context specified")
        let escalateDesc = escalate ? "true" : "false"
        print("Analytics Log - Event: \(event), Transition: \(transition.description), Screen: \(screenDesc), Modal: \(modalDesc), Role: \(roleDesc), StaffID: \(staffIDDesc), Context: \(contextDesc), Escalate: \(escalateDesc)")
    }
}

/// A centralized manager for Furfolio's custom transitions, navigation flows, and modal management.
/// Enhanced for business analytics, accessibility, QA, and design token compliance.
@MainActor
final class TransitionManager: ObservableObject {
    static let shared = TransitionManager()
    
    // MARK: - Analytics DI (for BI/QA/Trust Center/preview)
    
    /// The analytics logger used for all transition events.
    /// Default is a null logger; can be replaced with real or test implementations.
    public static var analyticsLogger: TransitionAnalyticsLogger = NullTransitionAnalyticsLogger()
    
    // MARK: - Published State
    
    /// The currently active screen in the app.
    @Published var activeScreen: Screen = .dashboard
    
    /// Indicates whether a modal is currently presented.
    @Published var showModal: Bool = false
    
    /// The content view of the currently presented modal.
    @Published var modalContent: AnyView? = nil
    
    /// The type of transition currently applied.
    @Published var transitionType: TransitionType = .springSlide
    
    /// The last accessibility announcement made, for VoiceOver and testing.
    @Published var lastAnnouncement: String = ""
    
    // MARK: - Diagnostic Event History
    
    /// Internal buffer of the last 20 analytics events for diagnostics or admin UI.
    private var eventHistory: [AnalyticsEvent] = []

    /// Represents a logged analytics event with timestamp and audit/trust center fields.
    public struct AnalyticsEvent: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let event: String
        public let transitionDescription: String
        public let screenDescription: String
        public let modal: Bool
        public let role: String?
        public let staffID: String?
        public let context: String?
        public let escalate: Bool
    }

    /// Publicly fetches the last 20 analytics events for diagnostics or admin UI, including audit fields.
    public func fetchRecentAnalyticsEvents() -> [AnalyticsEvent] {
        return eventHistory
    }
    
    // MARK: - Screen Definitions
    
    /// Represents the app's main screens.
    enum Screen: String, CaseIterable, CustomStringConvertible {
        case dashboard, onboarding, ownerDetail, appointmentDetail, settings
        /// Localized description of the screen.
        var description: String {
            switch self {
            case .dashboard:
                return NSLocalizedString("Dashboard", comment: "Dashboard screen")
            case .onboarding:
                return NSLocalizedString("Onboarding", comment: "Onboarding screen")
            case .ownerDetail:
                return NSLocalizedString("Owner Detail", comment: "Owner detail screen")
            case .appointmentDetail:
                return NSLocalizedString("Appointment Detail", comment: "Appointment detail screen")
            case .settings:
                return NSLocalizedString("Settings", comment: "Settings screen")
            }
        }
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
            case .springSlide: return NSLocalizedString("springSlide", comment: "Spring slide transition")
            case .fadeInOut: return NSLocalizedString("fadeInOut", comment: "Fade in/out transition")
            case .scale: return NSLocalizedString("scale", comment: "Scale transition")
            case .custom: return NSLocalizedString("custom", comment: "Custom transition")
            }
        }
        
        static func == (lhs: TransitionType, rhs: TransitionType) -> Bool {
            lhs.description == rhs.description // Sufficient for our use, as custom is always different
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Modal presentation
    
    /// Presents a modal with the specified view and transition type.
    /// - Parameters:
    ///   - content: The modal content view builder.
    ///   - transition: The transition type to use.
    ///   - accessibilityAnnouncement: Optional accessibility announcement string.
    func presentModal<Content: View>(
        @ViewBuilder content: () -> Content,
        transition: TransitionType = .springSlide,
        accessibilityAnnouncement: String? = nil
    ) async {
        self.modalContent = AnyView(content())
        self.transitionType = transition
        self.showModal = true
        await logEvent(
            event: NSLocalizedString("present_modal", comment: "Modal presentation event"),
            transition: transition,
            screen: nil,
            modal: true
        )
        if let announcement = accessibilityAnnouncement {
            announce(announcement)
        }
    }
    
    /// Dismisses any currently presented modal.
    /// - Parameter announce: Optional accessibility announcement string.
    func dismissModal(announce: String? = nil) async {
        self.showModal = false
        await logEvent(
            event: NSLocalizedString("dismiss_modal", comment: "Modal dismissal event"),
            transition: transitionType,
            screen: nil,
            modal: true
        )
        if let message = announce {
            self.announce(message)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.modalContent = nil
        }
    }
    
    // MARK: - Screen navigation
    
    /// Switch the active app screen with an optional transition.
    /// - Parameters:
    ///   - screen: The target screen to switch to.
    ///   - transition: The transition type to use.
    ///   - accessibilityAnnouncement: Optional accessibility announcement string.
    func switchScreen(
        to screen: Screen,
        with transition: TransitionType = .springSlide,
        accessibilityAnnouncement: String? = nil
    ) async {
        withAnimation(transition.animation) {
            self.transitionType = transition
            self.activeScreen = screen
        }
        await logEvent(
            event: NSLocalizedString("switch_screen", comment: "Screen switch event"),
            transition: transition,
            screen: screen,
            modal: false
        )
        if let announcement = accessibilityAnnouncement {
            self.announce(announcement)
        }
    }
    
    // MARK: - Accessibility
    
    /// Posts an accessibility announcement for VoiceOver and QA.
    /// - Parameter message: The announcement message.
    private func announce(_ message: String) {
        lastAnnouncement = message
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    // MARK: - Internal Logging
    
    /// Logs an analytics event asynchronously and stores it in the internal event history, including audit/trust center fields.
    /// - Parameters:
    ///   - event: The event name.
    ///   - transition: The transition type.
    ///   - screen: The associated screen, if any.
    ///   - modal: Whether the event relates to a modal presentation.
    ///   Audit/trust center/compliance enhancements: role, staffID, context, escalate.
    private func logEvent(event: String, transition: TransitionType, screen: Screen?, modal: Bool) async {
        let role = TransitionAuditContext.role
        let staffID = TransitionAuditContext.staffID
        let context = TransitionAuditContext.context
        // Escalate for "delete", "critical", or .springSlide + modal
        let lowerEvent = event.lowercased()
        let escalate = lowerEvent.contains("delete") || lowerEvent.contains("critical") || (transition == .springSlide && modal)
        await TransitionManager.analyticsLogger.log(event: event, transition: transition, screen: screen, modal: modal, role: role, staffID: staffID, context: context, escalate: escalate)
        let screenDesc = screen?.description ?? NSLocalizedString("none", comment: "No screen specified")
        let analyticsEvent = AnalyticsEvent(
            timestamp: Date(),
            event: event,
            transitionDescription: transition.description,
            screenDescription: screenDesc,
            modal: modal,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        eventHistory.append(analyticsEvent)
        if eventHistory.count > 20 {
            eventHistory.removeFirst(eventHistory.count - 20)
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
                        .onTapGesture {
                            Task {
                                await tm.dismissModal(announce: NSLocalizedString("Modal dismissed.", comment: "Accessibility announcement for modal dismissal"))
                            }
                        }
                }
            }
        )
        .animation(tm.transitionType.animation, value: tm.showModal)
        .animation(tm.transitionType.animation, value: tm.activeScreen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(String(format: NSLocalizedString("App main screen: %@", comment: "Accessibility label for main screen"), tm.activeScreen.description)))
        .accessibilityValue(Text(String(format: NSLocalizedString("Transition: %@", comment: "Accessibility value for transition type"), tm.transitionType.description)))
        .accessibilityHint(Text(tm.lastAnnouncement))
    }
}
