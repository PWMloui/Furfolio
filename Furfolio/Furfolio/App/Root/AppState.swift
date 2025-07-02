//
//  AppState.swift
//  Furfolio
//
//  Updated: 2025-06-30 – Enterprise role/staff/context audit, escalation, trust center/BI ready, fully modular.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Audit-Escalation)

public protocol AppStateAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async
}

/// A no-op analytics logger for default/testing.
public struct NullAppStateAnalyticsLogger: AppStateAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async {}
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async {}
}

/// A simple console logger for QA/testing.
public class ConsoleAppStateAnalyticsLogger: AppStateAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async {
        print("[AppState][LOG] \(event) | Info: \(info ?? "nil") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
    }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?, state: AppState) async {
        print("[AppState][ESCALATE] \(event) | Info: \(info ?? "nil") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
    }
}

// MARK: - AppState (Global App State, Roles, Trust Center, Navigation, Feature Flags)

@MainActor
final class AppState: ObservableObject {
    // MARK: - Audit Context

    /// Shared analytics logger instance. Can be swapped for admin/QA/BI/trust center.
    static var analyticsLogger: AppStateAnalyticsLogger = NullAppStateAnalyticsLogger()
    /// Flag to suppress real analytics logging and only log to console (QA/testing/previews).
    @Published var testMode: Bool = false
    /// Current business/user/staff context for audit/event logs (set after login or by session).
    @Published var currentRole: UserRole = .owner
    @Published var currentStaffID: String? = nil
    @Published var businessContext: String? = "AppState"
    /// Last 20 analytics events for admin/diagnostics.
    public private(set) var recentAnalyticsEvents: [(event: String, info: String?, role: String?, staffID: String?, context: String?)] = []

    // MARK: - Multi-User & Roles

    enum UserRole: String, CaseIterable, CustomStringConvertible {
        case owner, assistant, admin, groomer, staff, guest
        public var description: String { rawValue.capitalized }
    }

    // (Published) user role is now here, for role-aware logs.
    @Published var userRole: UserRole = .owner {
        didSet {
            Task {
                await logEvent("role_switched", info: userRole.description)
            }
        }
    }

    // MARK: - App Lifecycle & UI

    @Published var isOnboardingComplete: Bool = false {
        didSet {
            Task {
                await logEvent("onboarding_complete", info: isOnboardingComplete ? "complete" : "not complete")
            }
        }
    }
    @Published var showOnboarding: Bool = false
    @Published var selectedTab: Int = 0

    // MARK: - Authentication

    @Published var isAuthenticated: Bool = true {
        didSet {
            Task {
                await logEvent("auth_state_changed", info: isAuthenticated ? "authenticated" : "unauthenticated")
            }
        }
    }

    // MARK: - Notifications & Alerts

    @Published var showAlert: Bool = false
    @Published var alertMessage: String? = nil
    @Published var lastError: AppError? = nil {
        didSet {
            if let err = lastError {
                Task {
                    await logEvent("error_occurred", info: err.localizedDescription, escalate: err.shouldEscalate)
                }
            }
        }
    }

    // MARK: - User/Business Profile

    @Published var ownerName: String = "" {
        didSet {
            Task {
                await logEvent("owner_name_changed", info: ownerName)
            }
        }
    }
    @Published var businessName: String = NSLocalizedString("Furfolio Grooming", comment: "Default business name") {
        didSet {
            Task {
                await logEvent("business_name_changed", info: businessName)
            }
        }
    }
    @Published var businessSettings: [String: Any] = [:]

    // MARK: - Navigation

    @Published var deepLink: URL? = nil {
        didSet {
            if let url = deepLink {
                Task {
                    await logEvent("deep_link_navigated", info: url.absoluteString)
                }
            }
        }
    }

    // MARK: - Onboarding Progress

    @Published var onboardingStep: Int = 0

    // MARK: - Trust Center & Security

    @Published var isDataEncrypted: Bool = false {
        didSet {
            Task {
                await logEvent("encryption_toggle", info: isDataEncrypted ? "enabled" : "disabled")
            }
        }
    }
    @Published var auditLogEnabled: Bool = true {
        didSet {
            Task {
                await logEvent("audit_log_toggle", info: auditLogEnabled ? "enabled" : "disabled")
            }
        }
    }

    // MARK: - Calendar Integration

    @Published var calendarAccessGranted: Bool = false {
        didSet {
            Task {
                await logEvent("calendar_access_changed", info: calendarAccessGranted ? "granted" : "denied")
            }
        }
    }

    // MARK: - App Recovery/Export

    @Published var isPerformingBackup: Bool = false
    func triggerBackup() {
        isPerformingBackup = true
        Task {
            await logEvent("backup_triggered", info: nil)
        }
        // TODO: Integrate AppRecoveryManager for actual backup.
    }
    func triggerRestore() {
        Task {
            await logEvent("restore_triggered", info: nil)
        }
        // TODO: Integrate AppRecoveryManager for actual restore.
    }

    // MARK: - App Versioning & Feature Flags

    @Published var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    @Published var featureFlags: [String: Bool] = [
        "enableTSP": false,
        "enableCrashReporting": false,
        "showExperimentalUI": false
    ] {
        didSet {
            Task {
                await logEvent("feature_flags_changed", info: featureFlags.description)
            }
        }
    }

    // MARK: - Developer Tools

    @Published var debugMode: Bool = false {
        didSet {
            Task {
                await logEvent("debug_mode_toggle", info: debugMode ? "enabled" : "disabled")
            }
        }
    }

    // MARK: - Initialization

    init() {
        loadPersistentState()
        loadFeatureFlags()
        Task {
            await logEvent("app_state_initialized", info: nil)
        }
    }

    // MARK: - Persistence (Onboarding, Settings)

    func completeOnboarding() {
        isOnboardingComplete = true
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
        Task {
            await logEvent("onboarding_completed", info: nil)
        }
    }
    func loadPersistentState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        showOnboarding = !isOnboardingComplete
        Task {
            await logEvent("persistent_state_loaded", info: nil)
        }
    }

    // MARK: - Feature Flags

    func loadFeatureFlags() {
        // TODO: Load from remote config or local settings.
        Task {
            await logEvent("feature_flags_loaded", info: nil)
        }
    }

    // MARK: - Alert Helpers

    func presentError(_ error: AppError) {
        lastError = error
        alertMessage = error.errorDescription
        showAlert = true
        Task {
            await logEvent("error_presented", info: error.localizedDescription, escalate: error.shouldEscalate)
        }
    }
    func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
        Task {
            await logEvent("alert_presented", info: message)
        }
    }

    // MARK: - Private Helpers

    /// Logs an analytics event asynchronously, with audit context and escalation if needed.
    private func logEvent(_ event: String, info: String?, escalate: Bool = false) async {
        let roleString = self.userRole.rawValue
        let staffID = self.currentStaffID
        let ctx = self.businessContext
        // Update recent events (with context)
        DispatchQueue.main.async {
            self.recentAnalyticsEvents.append((event: event, info: info, role: roleString, staffID: staffID, context: ctx))
            if self.recentAnalyticsEvents.count > 20 {
                self.recentAnalyticsEvents.removeFirst()
            }
        }
        // Test/console-only mode
        if testMode || Self.analyticsLogger.testMode {
            print("[AppState][Event]: \(event) | Info: \(info ?? "No additional info") [role:\(roleString)] [staff:\(staffID ?? "-")] [ctx:\(ctx ?? "-")]")
        } else if escalate {
            await Self.analyticsLogger.escalate(event: event, info: info, role: roleString, staffID: staffID, context: ctx, state: self)
        } else {
            await Self.analyticsLogger.log(event: event, info: info, role: roleString, staffID: staffID, context: ctx, state: self)
        }
    }
}

// MARK: - Preview Helper

extension AppState {
    static var preview: AppState {
        let state = AppState()
        state.testMode = true
        state.isOnboardingComplete = false
        state.showOnboarding = true
        state.ownerName = "Taylor"
        state.businessName = "Preview Grooming"
        state.userRole = .assistant
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
