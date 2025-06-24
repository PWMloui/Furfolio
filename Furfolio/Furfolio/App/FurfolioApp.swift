//
//  FurfolioApp.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import SwiftData

// MARK: - FurfolioApp (Entry Point, Dependency Injection, Unified Navigation)

// The main entry point of the Furfolio application.
//
// FurfolioApp manages dependency injection, application lifecycle,
// onboarding flow, authentication state, and provides a unified root navigation
// container across all supported platforms using ContentView as the canonical root view.
// AdaptiveRootView is deprecated and retained only for legacy reference.
// This struct ensures consistent environment setup and model context propagation
// throughout the app's UI hierarchy.
@main
struct FurfolioApp: App {
    // Dependency container holds global state, managers, and SwiftData
    @StateObject private var dependencies = DependencyContainer.shared

    // AppDelegate for notifications & lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Group {
                if dependencies.appState.showOnboarding {
                    // Show onboarding flow if user has not completed onboarding
                    OnboardingView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                } else if !dependencies.appState.isAuthenticated {
                    // Show login/authentication view if user is not authenticated
                    LoginView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                } else {
                    // After authentication, show main content with unified root on all platforms
                    ContentView()
                        .environmentObject(dependencies.appState)
                        .environment(\.modelContext, dependencies.modelContainer.mainContext)
                    // Future: Add platform-specific root view enhancements here (e.g., iPad/Mac business dashboards)
                }
            }
        }
        // Apply model container modifier once at top level
        .modelContainer(dependencies.modelContainer)
    }
}
