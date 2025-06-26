//
//  NotificationPermissionHelper.swift
//  Furfolio
//
//  Enhanced: modular, auditable, analytics-ready, diagnostics/compliance, tokenized, and future-proof.
//  Any UI using this class for permission display should use AppColors, AppFonts, and AppSpacing tokens for all notification UI.
//

import Foundation
import UserNotifications
import OSLog

// Protocol for audit logging/analytics injection
public protocol PermissionAuditLogger {
    func log(event: PermissionAuditEvent)
}

/// Default no-op logger for previews/tests.
public struct NullPermissionAuditLogger: PermissionAuditLogger {
    public init() {}
    public func log(event: PermissionAuditEvent) {}
}

/// Audit event structure
public struct PermissionAuditEvent {
    public let type: String       // e.g. "refresh", "request"
    public let granted: Bool?
    public let status: UNAuthorizationStatus
    public let timestamp: Date
    public let userID: String?    // For business/multi-user compliance, if available

    public init(type: String, granted: Bool?, status: UNAuthorizationStatus, timestamp: Date = .init(), userID: String? = nil) {
        self.type = type
        self.granted = granted
        self.status = status
        self.timestamp = timestamp
        self.userID = userID
    }
}

/// Centralized, modular helper for managing notification (and future) permissions.
/// Designed for full business diagnostics, Trust Center audit logging, modular analytics, and extensibility.
@MainActor
final class NotificationPermissionHelper: ObservableObject {
    static let shared = NotificationPermissionHelper()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Inject logger for diagnostics, audit, analytics, or compliance.
    private let auditLogger: PermissionAuditLogger
    private let userID: String? // For multi-user/business context if needed

    /// Init for production, preview, or test injection.
    init(auditLogger: PermissionAuditLogger = NullPermissionAuditLogger(), userID: String? = nil) {
        self.auditLogger = auditLogger
        self.userID = userID
        refreshAuthorizationStatus()
    }

    /// Refreshes and updates the current notification permission state, then logs/audits.
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
                self.auditLogger.log(event: PermissionAuditEvent(
                    type: "refresh",
                    granted: self.isAuthorized,
                    status: settings.authorizationStatus,
                    userID: self.userID
                ))
                // Optional: Add more diagnostics here if needed
            }
        }
    }

    /// Requests notification permission from the user and audits/analytics the event.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refreshAuthorizationStatus()
                self.auditLogger.log(event: PermissionAuditEvent(
                    type: "request",
                    granted: granted,
                    status: self.authorizationStatus,
                    userID: self.userID
                ))
                completion(granted)
                // If adding user-facing messages, use NSLocalizedString for localization.
            }
        }
    }

    /// True if notifications are fully enabled and authorized.
    var notificationsEnabled: Bool {
        isAuthorized && (authorizationStatus == .authorized)
    }

    /// For diagnostics: localized string for current status (useful in admin/owner panels).
    var localizedStatusDescription: String {
        switch authorizationStatus {
        case .authorized: return NSLocalizedString("Notifications enabled", comment: "Notifications fully enabled")
        case .denied: return NSLocalizedString("Notifications denied", comment: "Notifications denied by user")
        case .notDetermined: return NSLocalizedString("Permission not determined", comment: "Notification permission not yet determined")
        case .provisional: return NSLocalizedString("Provisional permission", comment: "Notification permission provisional")
        case .ephemeral: return NSLocalizedString("Ephemeral permission", comment: "Notification permission ephemeral")
        @unknown default: return NSLocalizedString("Unknown notification status", comment: "Unknown notification permission status")
        }
    }

    // MARK: - Extensibility for future permission types (camera, location, etc.)
    // Add more permission check/request logic here for other modules.
}
