//
//  FurfolioApp.swift
//  Furfolio
//
//  FurfolioApp serves as the primary entry point and dependency injection container for the Furfolio application.
//  Now with role/staff/context audit, escalation protocol, trust center/BI readiness, and extensible analytics hooks.
//

import SwiftUI
import SwiftData

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Escalation)

public protocol FurfolioAppAnalyticsLogger {
    /// Indicates whether the logger is operating in test mode (console-only).
    var testMode: Bool { get set }
    /// Asynchronously logs an event with optional info and context.
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async
    /// Escalates a critical event for trust center/compliance/audit review.
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}

// No-op analytics logger for default or disabled analytics scenarios.
public struct NullFurfolioAppAnalyticsLogger: FurfolioAppAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - Global Audit Context (Set at login/session)
public struct FurfolioAppAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "FurfolioApp"
}

// MARK: - FurfolioApp (Entry Point, DI, Lifecycle, Analytics, Unified Navigation)

@main
struct FurfolioApp: App {
    // Shared dependency container
    @StateObject private var dependencies = DependencyContainer.shared
    // AppDelegate adaptor for notifications/lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Static analytics logger, injectable for QA/Trust Center/print-based logging
    public static var analyticsLogger: FurfolioAppAnalyticsLogger = NullFurfolioAppAnalyticsLogger()

    // Audit context (set at login/session)
    public static var currentRole: String? { FurfolioAppAuditContext.role }
    public static var currentStaffID: String? { FurfolioAppAuditContext.staffID }
    public static var currentContext: String? { FurfolioAppAuditContext.context }

    // Thread-safe storage of recent analytics events for diagnostics/admin UI
    private static var recentAnalyticsEvents: [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] = []
    private static let maxRecentEvents = 20
    private static let recentEventsQueue = DispatchQueue(label: "FurfolioApp.analyticsEventsQueue")

    /// Fetch last 20 analytics events with audit context (thread-safe)
    public static func fetchRecentAnalyticsEvents() -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] {
        var eventsCopy: [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] = []
        recentEventsQueue.sync {
            eventsCopy = recentAnalyticsEvents
        }
        return eventsCopy
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if dependencies.appState.showOnboarding {
                    OnboardingView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .task {
                            await logEventAsync(
                                event: NSLocalizedString("show_onboarding", comment: "Analytics event for displaying onboarding flow"),
                                info: nil
                            )
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(NSLocalizedString("Onboarding View", comment: "Accessibility label for onboarding view"))
                } else if !dependencies.appState.isAuthenticated {
                    LoginView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .task {
                            await logEventAsync(
                                event: NSLocalizedString("show_login", comment: "Analytics event for displaying login view"),
                                info: nil
                            )
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(NSLocalizedString("Login View", comment: "Accessibility label for login view"))
                } else {
                    ContentView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .task {
                            await logEventAsync(
                                event: NSLocalizedString("show_main_content", comment: "Analytics event for displaying main content view"),
                                info: nil
                            )
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(NSLocalizedString("Main Content View", comment: "Accessibility label for main content view"))
                    // Future: Add platform-specific root view enhancements here (e.g., iPad/Mac business dashboards)
                }
            }
        }
        .modelContainer(dependencies.modelContainer)
    }
    
    /// Logs analytics/audit events with audit context, supporting escalation for critical events.
    /// - Parameters:
    ///   - event: The event identifier string.
    ///   - info: Optional supplementary information about the event.
    ///   - escalate: True if the event should be escalated for trust center/audit review.
    private func logEventAsync(event: String, info: String?, escalate: Bool = false) async {
        let role = Self.currentRole
        let staffID = Self.currentStaffID
        let ctx = Self.currentContext
        let timestamp = Date()
        if escalate {
            await Self.analyticsLogger.escalate(event: event, info: info, role: role, staffID: staffID, context: ctx)
        } else {
            await Self.analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: ctx)
        }
        Self.recentEventsQueue.async {
            if Self.recentAnalyticsEvents.count >= Self.maxRecentEvents {
                Self.recentAnalyticsEvents.removeFirst()
            }
            Self.recentAnalyticsEvents.append((event: event, info: info, role: role, staffID: staffID, context: ctx, escalate: escalate, date: timestamp))
        }
    }
}
