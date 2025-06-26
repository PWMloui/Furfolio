//
//  FurfolioApp.swift
//  Furfolio
//
//  Enhanced: token-compliant, analytics/audit/Trust Center–ready, brand/role-injectable, preview/test–injectable.
//

import SwiftUI
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol FurfolioAppAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullFurfolioAppAnalyticsLogger: FurfolioAppAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - FurfolioApp (Entry Point, DI, Lifecycle, Analytics, Unified Navigation)

@main
struct FurfolioApp: App {
    // Dependency container holds global state, managers, and SwiftData
    @StateObject private var dependencies = DependencyContainer.shared

    // AppDelegate for notifications & lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Analytics logger (injectable for QA/Trust Center/print)
    static var analyticsLogger: FurfolioAppAnalyticsLogger = NullFurfolioAppAnalyticsLogger()

    var body: some Scene {
        WindowGroup {
            Group {
                if dependencies.appState.showOnboarding {
                    // Show onboarding flow if user has not completed onboarding
                    OnboardingView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .onAppear {
                            Self.analyticsLogger.log(event: "show_onboarding", info: nil)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Onboarding View")
                } else if !dependencies.appState.isAuthenticated {
                    // Show login/authentication view if user is not authenticated
                    LoginView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .onAppear {
                            Self.analyticsLogger.log(event: "show_login", info: nil)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Login View")
                } else {
                    // After authentication, show main content with unified root on all platforms
                    ContentView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                        .onAppear {
                            Self.analyticsLogger.log(event: "show_main_content", info: nil)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Main Content View")
                    // Future: Add platform-specific root view enhancements here (e.g., iPad/Mac business dashboards)
                }
            }
        }
        // Apply model container modifier once at top level
        .modelContainer(dependencies.modelContainer)
    }
}
