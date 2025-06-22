//
//  AppState.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - AppState (Global App State, Roles, Trust Center, Navigation, Feature Flags)

/**
 Global app state for Furfolio, designed as a single source of truth for the entire app.

 This class manages:
 - Multi-user support and user roles with permissions
 - Trust Center and security settings including data encryption and audit logging
 - Feature flags enabling or disabling experimental or optional features
 - Onboarding progress and flow control
 - Navigation state including deep linking and tab selection
 - Error reporting and alert presentation
 - App versioning for UI display and diagnostic purposes
 - Business profile data such as owner and business name

 This state is intended to be injected as an @EnvironmentObject throughout the SwiftUI app,
 enabling reactive updates and centralized state management.
 */
@MainActor
final class AppState: ObservableObject {
    // MARK: - Multi-User & Roles

    /**
     Defines user roles within the app and their permissions.

     - owner: Full access including managing business settings and Trust Center.
     - assistant: Limited access, typically operational tasks without administrative privileges.
     */
    enum UserRole {
        case owner, assistant
    }
    @Published var currentUserRole: UserRole = .owner  // Drives UI access control and feature availability based on role
    // TODO: Integrate multi-user settings and secure switching between roles, including authentication and role persistence.

    // MARK: - App Lifecycle & UI

    @Published var isOnboardingComplete: Bool = false   // Controls whether onboarding screens are shown
    @Published var showOnboarding: Bool = false         // Controls visibility of onboarding flow UI
    @Published var selectedTab: Int = 0                  // Drives currently selected tab in tab-based navigation UI

    // MARK: - Authentication (optional)

    @Published var isAuthenticated: Bool = true         // Indicates if user is logged in; controls access to authenticated areas

    // MARK: - Notifications & Alerts

    @Published var showAlert: Bool = false              // Controls display of alert modals
    @Published var alertMessage: String? = nil          // Message content for alerts
    @Published var lastError: AppError? = nil            // Stores last occurred error for reporting or UI display

    // MARK: - User/Business Profile

    @Published var ownerName: String = ""                // Owner name displayed in UI and used in communications
    @Published var businessName: String = "Furfolio Grooming"  // Business name shown throughout the app
    @Published var businessSettings: [String: Any] = [:] // Holds customizable business settings and preferences

    // MARK: - Navigation

    @Published var deepLink: URL? = nil                   // Holds incoming deep link URL for navigation routing

    // MARK: - Onboarding Progress (optional)

    @Published var onboardingStep: Int = 0                // Tracks current onboarding step for multi-step flows

    // MARK: - Trust Center & Security

    @Published var isDataEncrypted: Bool = false          // Indicates if data encryption is enabled (UI toggle)
    @Published var auditLogEnabled: Bool = true           // Indicates if audit logging is enabled (UI toggle)
    // TODO: Wire up data encryption and audit log toggles in Trust Center UI and integrate with security services.

    // MARK: - Calendar Integration

    @Published var calendarAccessGranted: Bool = false    // Tracks if user granted calendar permissions
    // TODO: Handle calendar permission flow and sync with calendar-related features.

    // MARK: - App Recovery/Export

    @Published var isPerformingBackup: Bool = false       // Indicates backup operation in progress (UI activity indicator)

    /// Initiates backup process for app data.
    /// Integrate with AppRecoveryManager.backup() to perform actual backup operations.
    func triggerBackup() {
        // TODO: Call AppRecoveryManager.backup() and handle completion/errors.
    }

    /// Initiates restore process for app data.
    /// Integrate with AppRecoveryManager.restore() to perform actual restore operations.
    func triggerRestore() {
        // TODO: Call AppRecoveryManager.restore() and handle completion/errors.
    }

    // MARK: - App Versioning & Feature Flags

    @Published var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    // Used for displaying current app version in UI and for diagnostic reporting.

    @Published var featureFlags: [String: Bool] = [
        "enableTSP": false,               // Toggle for TSP feature
        "enableCrashReporting": false,   // Toggle for crash reporting feature
        "showExperimentalUI": false      // Toggle for showing experimental UI elements
    ]

    // MARK: - Developer Tools

    @Published var debugMode: Bool = false                // Enables debug UI and logging

    // MARK: - Initialization

    init() {
        loadPersistentState()
        loadFeatureFlags()
    }

    // MARK: - Persistence (Onboarding, Settings)

    /// Marks onboarding as completed and updates persistent storage.
    func completeOnboarding() {
        isOnboardingComplete = true
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
    }

    /// Loads onboarding completion state from persistent storage.
    func loadPersistentState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        showOnboarding = !isOnboardingComplete
    }

    // MARK: - Feature Flags

    /// Loads feature flags from remote config or local settings.
    /// Currently simulated with hardcoded flags set in property declaration.
    func loadFeatureFlags() {
        // TODO: Load feature flags from remote config or local settings.
    }

    // MARK: - Alert Helper

    /// Presents an error alert with localized description.
    /// - Parameter error: The AppError to present.
    func presentError(_ error: AppError) {
        lastError = error
        alertMessage = error.errorDescription
        showAlert = true
    }

    /// Presents a generic alert with a custom message.
    /// - Parameter message: The alert message to display.
    func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Preview Helper

extension AppState {
    /// Provides a preview instance of AppState for SwiftUI previews, UI prototyping, and testing.
    /// This enables developers to see the app UI in various states without running the full app.
    static var preview: AppState {
        let state = AppState()
        state.isOnboardingComplete = false
        state.showOnboarding = true
        state.ownerName = "Taylor"
        state.businessName = "Preview Grooming"
        state.currentUserRole = .assistant
        state.isDataEncrypted = true
        state.auditLogEnabled = true
        state.featureFlags = [
            "enableTSP": true,
            "enableCrashReporting": true,
            "showExperimentalUI": true
        ]
        return state
    }
}
