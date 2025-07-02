//
//  AppDelegate.swift
//  Furfolio
//
//  ENHANCED: Modular, role/staff-aware, audit/analytics/compliance-ready, Trust Center hooks, future-proof.
//  Last updated: 2025-06-30
//

import Foundation
import UIKit
import UserNotifications

// MARK: - Analytics/Audit Protocol (for Trust Center/QA/BI)
public protocol AppDelegateAnalyticsLogger {
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async
    var testMode: Bool { get set }
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}
public struct NullAppDelegateAnalyticsLogger: AppDelegateAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        if testMode {
            print("[AppDelegateAnalyticsLogger][TESTMODE] \(event): \(info ?? "nil") [role:\(role ?? "-") staff:\(staffID ?? "-") ctx:\(context ?? "-")]")
        }
    }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        if testMode {
            print("[AppDelegateAnalyticsLogger][ESCALATE-TESTMODE] \(event): \(info ?? "nil") [role:\(role ?? "-") staff:\(staffID ?? "-") ctx:\(context ?? "-")]")
        }
    }
}

/// AppDelegate for Furfolio – now supports role/staff context, audit/compliance escalation, and future Trust Center features.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Analytics logger with compliance hooks
    static var analyticsLogger: AppDelegateAnalyticsLogger = NullAppDelegateAnalyticsLogger()
    // Global current user role and staffID (set by login/session manager)
    static var currentRole: String? = nil
    static var currentStaffID: String? = nil
    static var currentContext: String? = "AppDelegate"

    // MARK: - Application Lifecycle
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("app_launch", value: "App Launched", comment: "App launch event"),
                info: "\(String(describing: launchOptions))",
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }

        // Example escalation: If app is launched with unsafe env (jailbreak detected, missing privacy config, etc)
        // if unsafeEnvironmentDetected {
        //     Task {
        //         await Self.analyticsLogger.escalate(
        //             event: NSLocalizedString("app_launch_unsafe_env", value: "App Launch Unsafe Env", comment: "Unsafe env launch event"),
        //             info: "Environment: \(environmentInfo)",
        //             role: Self.currentRole,
        //             staffID: Self.currentStaffID,
        //             context: Self.currentContext
        //         )
        //     }
        // }

        // Register tokens/branding (future: dependency injection)
        // DependencyContainer.shared.register(CrashReporter.self, CrashReporter())
        // DependencyContainer.shared.register(TrustCenterService.self, TrustCenterService())
        // DependencyContainer.shared.register(RoleManager.self, RoleManager())
        // DependencyContainer.shared.register(AuditLogger.self, AuditLogger())

        // Optional onboarding: only trigger for staff, not for owner/admin
        // if Self.currentRole == "staff" || Self.currentRole == "receptionist" {
        //     OnboardingFlowManager.shared.checkAndPresentOnFirstLaunch()
        //     Task {
        //         await Self.analyticsLogger.log(
        //             event: NSLocalizedString("onboarding_checked", value: "Onboarding Checked", comment: "Onboarding event"),
        //             info: nil,
        //             role: Self.currentRole,
        //             staffID: Self.currentStaffID,
        //             context: Self.currentContext
        //         )
        //     }
        // }

        return true
    }

    // MARK: - Foreground/Background Transition Logging
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("app_will_enter_foreground", value: "App Will Enter Foreground", comment: "Foreground event"),
                info: nil,
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("app_did_enter_background", value: "App Did Enter Background", comment: "Background event"),
                info: nil,
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
    }

    // MARK: - Notification Handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("notification_presented", value: "Notification Presented", comment: "Notification event"),
                info: notification.request.identifier,
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("notification_received", value: "Notification Received", comment: "Notification event"),
                info: response.notification.request.identifier,
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
        completionHandler()
    }

    // MARK: - Background Fetch Example (optional)
    /*
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("background_fetch", value: "Background Fetch", comment: "Background fetch event"),
                info: nil,
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
        completionHandler(.noData)
    }
    */

    // MARK: - Locale/Accessibility Change Handlers (future-proof)
    func application(_ application: UIApplication, willChangeStatusBarFrame newStatusBarFrame: CGRect) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("statusbar_frame_changed", value: "StatusBar Frame Changed", comment: "Status bar change event"),
                info: "\(newStatusBarFrame)",
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
    }
    func application(_ application: UIApplication, willChangeStatusBarOrientation newStatusBarOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        Task {
            await Self.analyticsLogger.log(
                event: NSLocalizedString("statusbar_orientation_changed", value: "StatusBar Orientation Changed", comment: "Status bar orientation event"),
                info: "\(newStatusBarOrientation.rawValue)",
                role: Self.currentRole,
                staffID: Self.currentStaffID,
                context: Self.currentContext
            )
        }
    }

    // MARK: - Trust Center/Compliance/Diagnostics (stubs)
    // func escalateComplianceEvent(_ event: String, info: String?) {
    //     Task {
    //         await Self.analyticsLogger.escalate(
    //             event: event,
    //             info: info,
    //             role: Self.currentRole,
    //             staffID: Self.currentStaffID,
    //             context: Self.currentContext
    //         )
    //     }
    // }

    // MARK: - Modular Stubs for Expansion
    // private func setupCrashReporter() { /* Crash analytics / os_log setup */ }
    // private func setupTrustCenter() { /* Privacy/Audit Center registration */ }
    // private func setupRoleManager() { /* Multi-user, role-based access setup */ }
    // private func setupFeatureFlagManager() { /* Developer feature flags */ }
    // private func setupAuditLogger() { /* Business data audit logs */ }
    // ... add more as needed

    // MARK: - Developer Tools / QA
    #if DEBUG
    func injectQAAnalyticsLogger(_ logger: AppDelegateAnalyticsLogger) {
        Self.analyticsLogger = logger
    }
    func enableTestMode(_ enabled: Bool) {
        Self.analyticsLogger.testMode = enabled
    }
    #endif
}

// MARK: - End of AppDelegate
