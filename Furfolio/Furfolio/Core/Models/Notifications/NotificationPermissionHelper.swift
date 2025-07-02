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

/**
 NotificationPermissionHelper
 -----------------------------
 A centralized, modular helper for managing notification permissions in Furfolio.

 - **Architecture**: Singleton `ObservableObject` for SwiftUI binding.
 - **Concurrency & Audit**: Uses async/await audit logging via `PermissionAuditManager` actor.
 - **Diagnostics**: Tracks permission refresh and request events with timestamps and user context.
 - **Localization**: Exposes `localizedStatusDescription` using `NSLocalizedString`.
 - **Accessibility**: Status and action outcomes can be read by VoiceOver.
 - **Preview/Testability**: Includes SwiftUI preview demonstrating status display, refresh, and request flows with audit log export.
 */

/// Protocol for audit logging/analytics injection
public protocol PermissionAuditLogger {
    func log(event: PermissionAuditEvent) async
}

/// Default no-op logger for previews/tests.
public struct NullPermissionAuditLogger: PermissionAuditLogger {
    public init() {}
    public func log(event: PermissionAuditEvent) async {}
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

/// A record of a permission audit event.
public struct PermissionAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let event: PermissionAuditEvent

    public init(id: UUID = UUID(), event: PermissionAuditEvent) {
        self.id = id
        self.event = event
    }
}

/// Manages concurrency-safe audit logging for permission events.
public actor PermissionAuditManager {
    private var buffer: [PermissionAuditEntry] = []
    private let maxEntries = 100
    public static let shared = PermissionAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: PermissionAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [PermissionAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
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
                Task {
                    let event = PermissionAuditEvent(
                        type: "refresh",
                        granted: self.isAuthorized,
                        status: settings.authorizationStatus,
                        userID: self.userID
                    )
                    await self.auditLogger.log(event: event)
                    await PermissionAuditManager.shared.add(.init(event: event))
                }
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
                Task {
                    let event = PermissionAuditEvent(
                        type: "request",
                        granted: granted,
                        status: self.authorizationStatus,
                        userID: self.userID
                    )
                    await self.auditLogger.log(event: event)
                    await PermissionAuditManager.shared.add(.init(event: event))
                }
                completion(granted)
                // If adding user-facing messages, use NSLocalizedString for localization.
            }
        }
    }

    /// Requests notification permission asynchronously.
    public func requestPermission() async -> Bool {
        let granted = await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                Task { @MainActor in
                    self.refreshAuthorizationStatus()
                    await self.auditLogger.log(event: PermissionAuditEvent(type: "request", granted: granted, status: self.authorizationStatus, userID: self.userID))
                    await PermissionAuditManager.shared.add(.init(event: PermissionAuditEvent(type: "request", granted: granted, status: self.authorizationStatus, userID: self.userID)))
                    cont.resume(returning: granted)
                }
            }
        }
        return granted
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

#if DEBUG
import SwiftUI

struct NotificationPermissionHelper_Previews: PreviewProvider {
    @StateObject static var helper = NotificationPermissionHelper()
    static var previews: some View {
        VStack(spacing: 16) {
            Text(helper.localizedStatusDescription)
            Button("Refresh Status") { helper.refreshAuthorizationStatus() }
            Button("Request Permission") {
                Task {
                    _ = await helper.requestPermission()
                    let logs = await PermissionAuditManager.shared.recent(limit: 5)
                    print(logs)
                }
            }
            Button("Export Audit JSON") {
                Task {
                    let json = await PermissionAuditManager.shared.exportJSON()
                    print(json)
                }
            }
        }
        .padding()
    }
}
#endif
