//
//  AppState.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, brand/white-label, extensible, preview/testable, accessible.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Analytics/Audit Protocol

public protocol AppStateAnalyticsLogger {
    func log(event: String, info: String?, state: AppState)
}
public struct NullAppStateAnalyticsLogger: AppStateAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?, state: AppState) {}
}

// MARK: - AppState (Global App State, Roles, Trust Center, Navigation, Feature Flags)

@MainActor
final class AppState: ObservableObject {
    // Inject analytics logger (can be swapped for QA, Trust Center, admin, or BI dashboard)
    static var analyticsLogger: AppStateAnalyticsLogger = NullAppStateAnalyticsLogger()

    // MARK: - Multi-User & Roles

    enum UserRole: String, CaseIterable, CustomStringConvertible {
        case owner, assistant
        var description: String { rawValue.capitalized }
    }
    @Published var currentUserRole: UserRole = .owner {
        didSet {
            Self.analyticsLogger.log(event: "role_switched", info: currentUserRole.description, state: self)
        }
    }

    // MARK: - App Lifecycle & UI

    @Published var isOnboardingComplete: Bool = false {
        didSet {
            Self.analyticsLogger.log(event: "onboarding_complete", info: isOnboardingComplete ? "complete" : "not complete", state: self)
        }
    }
    @Published var showOnboarding: Bool = false
    @Published var selectedTab: Int = 0

    // MARK: - Authentication

    @Published var isAuthenticated: Bool = true {
        didSet {
            Self.analyticsLogger.log(event: "auth_state_changed", info: isAuthenticated ? "authenticated" : "unauthenticated", state: self)
        }
    }

    // MARK: - Notifications & Alerts

    @Published var showAlert: Bool = false
    @Published var alertMessage: String? = nil
    @Published var lastError: AppError? = nil {
        didSet {
            if let err = lastError {
                Self.analyticsLogger.log(event: "error_occurred", info: err.localizedDescription, state: self)
            }
        }
    }

    // MARK: - User/Business Profile

    @Published var ownerName: String = "" {
        didSet {
            Self.analyticsLogger.log(event: "owner_name_changed", info: ownerName, state: self)
        }
    }
    @Published var businessName: String = "Furfolio Grooming" {
        didSet {
            Self.analyticsLogger.log(event: "business_name_changed", info: businessName, state: self)
        }
    }
    @Published var businessSettings: [String: Any] = [:]

    // MARK: - Navigation

    @Published var deepLink: URL? = nil {
        didSet {
            if let url = deepLink {
                Self.analyticsLogger.log(event: "deep_link_navigated", info: url.absoluteString, state: self)
            }
        }
    }

    // MARK: - Onboarding Progress

    @Published var onboardingStep: Int = 0

    // MARK: - Trust Center & Security

    @Published var isDataEncrypted: Bool = false {
        didSet {
            Self.analyticsLogger.log(event: "encryption_toggle", info: isDataEncrypted ? "enabled" : "disabled", state: self)
        }
    }
    @Published var auditLogEnabled: Bool = true {
        didSet {
            Self.analyticsLogger.log(event: "audit_log_toggle", info: auditLogEnabled ? "enabled" : "disabled", state: self)
        }
    }

    // MARK: - Calendar Integration

    @Published var calendarAccessGranted: Bool = false {
        didSet {
            Self.analyticsLogger.log(event: "calendar_access_changed", info: calendarAccessGranted ? "granted" : "denied", state: self)
        }
    }

    // MARK: - App Recovery/Export

    @Published var isPerformingBackup: Bool = false

    func triggerBackup() {
        isPerformingBackup = true
        Self.analyticsLogger.log(event: "backup_triggered", info: nil, state: self)
        // TODO: Call AppRecoveryManager.backup() and handle completion/errors.
        // On complete:
        // isPerformingBackup = false
    }

    func triggerRestore() {
        Self.analyticsLogger.log(event: "restore_triggered", info: nil, state: self)
        // TODO: Call AppRecoveryManager.restore() and handle completion/errors.
    }

    // MARK: - App Versioning & Feature Flags

    @Published var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    @Published var featureFlags: [String: Bool] = [
        "enableTSP": false,
        "enableCrashReporting": false,
        "showExperimentalUI": false
    ] {
        didSet {
            Self.analyticsLogger.log(event: "feature_flags_changed", info: featureFlags.description, state: self)
        }
    }

    // MARK: - Developer Tools

    @Published var debugMode: Bool = false {
        didSet {
            Self.analyticsLogger.log(event: "debug_mode_toggle", info: debugMode ? "enabled" : "disabled", state: self)
        }
    }

    // MARK: - Initialization

    init() {
        loadPersistentState()
        loadFeatureFlags()
        Self.analyticsLogger.log(event: "app_state_initialized", info: nil, state: self)
    }

    // MARK: - Persistence (Onboarding, Settings)

    func completeOnboarding() {
        isOnboardingComplete = true
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
        Self.analyticsLogger.log(event: "onboarding_completed", info: nil, state: self)
    }

    func loadPersistentState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        showOnboarding = !isOnboardingComplete
        Self.analyticsLogger.log(event: "persistent_state_loaded", info: nil, state: self)
    }

    // MARK: - Feature Flags

    func loadFeatureFlags() {
        // TODO: Load feature flags from remote config or local settings.
        Self.analyticsLogger.log(event: "feature_flags_loaded", info: nil, state: self)
    }

    // MARK: - Alert Helper

    func presentError(_ error: AppError) {
        lastError = error
        alertMessage = error.errorDescription
        showAlert = true
        Self.analyticsLogger.log(event: "error_presented", info: error.localizedDescription, state: self)
    }

    func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
        Self.analyticsLogger.log(event: "alert_presented", info: message, state: self)
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
