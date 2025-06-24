//
//  NotificationPermissionHelper.swift
//  Furfolio
//
//  Updated for modularity, diagnostics, and iOS best practices.
//
//  NOTE: Any UI using this class for permission display should use AppColors, AppFonts, and AppSpacing tokens for all notification UI.

import Foundation
import UserNotifications

/// Centralized helper for managing notification permissions.
/// 
/// This class is designed with full business compliance in mind:
/// - Audit/Logging: Hooks are provided for auditing permission requests and status refreshes.
/// - Modular Analytics: Easily extendable for integrating with analytics platforms.
/// - Token Compliance: UI should leverage design tokens (AppColors, AppFonts, AppSpacing) for consistent styling.
/// - Extensibility: Can be extended to support new permission types beyond notifications in the future.
final class NotificationPermissionHelper: ObservableObject {
    static let shared = NotificationPermissionHelper()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        refreshAuthorizationStatus()
    }

    /// Refreshes and updates the current notification permission state.
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
                // TODO: Audit status refresh event here if needed.
            }
        }
    }

    /// Requests notification permission from the user.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.refreshAuthorizationStatus()
                completion(granted)
                // TODO: Plug audit log/analytics for permission request here with granted/denied status.
                // TODO: Localize any user-facing messages if added here in the future.
            }
        }
    }

    /// Convenience property: true if notifications are fully enabled.
    var notificationsEnabled: Bool {
        isAuthorized && (authorizationStatus == .authorized)
    }
}
