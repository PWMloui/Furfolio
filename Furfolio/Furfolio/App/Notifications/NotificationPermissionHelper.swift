import Foundation
import UserNotifications
import SwiftUI
import OSLog

/// Centralized helper for handling notification permission lifecycle across iOS, iPadOS, and Mac Catalyst.
/// Designed for localization, audit logging, analytics, and Trust Center integration.
@MainActor
final class NotificationPermissionHelper: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = NotificationPermissionHelper()
    
    // MARK: - Published Properties
    @Published var isAuthorized: Bool = false
    @Published var statusDescription: String = NSLocalizedString("NOTIFICATION_PERMISSION_Unknown", comment: "Unknown notification permission status")
    @Published var error: Error? = nil

    // MARK: - Constants
    private let localizationPrefix = "NOTIFICATION_PERMISSION_"
    private let logger = Logger(subsystem: "com.furfolio.notifications", category: "permissions")

    // MARK: - Init
    private init() {
        Task { await refreshStatus() }
    }

    // MARK: - Public API

    /// Request basic notification permissions (alert, badge, sound).
    /// - Returns: Whether the user granted permission.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        clearError()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
            // TODO(priority: high): Log permission request for audit
            // TODO(priority: medium): Track analytics for permission granted/denied
            return granted
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
            await handleError(error, localizedKey: "Error")
            return false
        }
    }

    /// Request advanced notification permissions (critical alerts, time-sensitive).
    /// - Returns: Whether advanced permissions were granted.
    func requestAdvancedPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        clearError()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive, .criticalAlert])
            await refreshStatus()
            // TODO(priority: high): Log advanced permission request
            return granted
        } catch {
            logger.error("Advanced notification permission error: \(error.localizedDescription)")
            await handleError(error, localizedKey: "Error_Advanced")
            return false
        }
    }

    /// Refreshes the current system-level notification status.
    func refreshStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .notDetermined:
                isAuthorized = false
                statusDescription = NSLocalizedString(localizationPrefix + "NotDetermined", comment: "")
            case .denied:
                isAuthorized = false
                statusDescription = NSLocalizedString(localizationPrefix + "Denied", comment: "")
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
                statusDescription = NSLocalizedString(localizationPrefix + "Granted", comment: "")
            @unknown default:
                isAuthorized = false
                statusDescription = NSLocalizedString(localizationPrefix + "Unknown", comment: "")
            }
            error = nil
        }
    }

    /// Opens system settings so user can manually adjust notification settings.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        #if os(iOS) || targetEnvironment(macCatalyst)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }

    // MARK: - Private Helpers

    private func clearError() {
        error = nil
    }

    private func handleError(_ error: Error, localizedKey: String) async {
        await MainActor.run {
            self.statusDescription = NSLocalizedString(localizationPrefix + localizedKey, comment: "")
            self.error = error
        }
    }
}
