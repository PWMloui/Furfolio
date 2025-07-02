
//
//  AccessControlService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 AccessControlService
 --------------------
 Centralized service for managing user permissions and roles in Furfolio.

 - **Purpose**: Checks and updates user access rights for features and resources.
 - **Architecture**: Singleton `ObservableObject` or service class with dependency-injected analytics and audit loggers.
 - **Concurrency & Async Logging**: Exposes async methods for permission checks and updates, logging events via `AccessControlAuditManager`.
 - **Localization**: Uses `NSLocalizedString` for user-facing error messages.
 - **Diagnostics & Preview/Testability**: Provides async methods to fetch and export recent audit entries for troubleshooting.
 */

import Foundation

// MARK: - Analytics & Audit Protocols

public protocol AccessControlAnalyticsLogger {
    /// Logs an access control event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol AccessControlAuditLogger {
    /// Records an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullAccessControlAnalyticsLogger: AccessControlAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String: Any]?) async {}
}

public struct NullAccessControlAuditLogger: AccessControlAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String: String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an access control audit event.
public struct AccessControlAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let action: String
    public let userId: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), action: String, userId: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.userId = userId
    }
}

/// Actor for concurrency-safe audit logging in access control.
public actor AccessControlAuditManager {
    private var buffer: [AccessControlAuditEntry] = []
    private let maxEntries = 100
    public static let shared = AccessControlAuditManager()

    public func add(_ entry: AccessControlAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [AccessControlAuditEntry] {
        Array(buffer.suffix(limit))
    }

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

// MARK: - AccessControlService

public class AccessControlService {
    let analytics: AccessControlAnalyticsLogger
    let audit: AccessControlAuditLogger

    public init(
        analytics: AccessControlAnalyticsLogger = NullAccessControlAnalyticsLogger(),
        audit: AccessControlAuditLogger = NullAccessControlAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Checks if a user has a specific permission.
    public func hasPermission(userId: String, permission: String) async -> Bool {
        // ... (actual permission check logic goes here)
        let granted = false // Replace with real logic
        Task {
            await analytics.log(event: "permission_checked", parameters: ["userId": userId, "permission": permission])
            await audit.record("Checked permission \(permission)", metadata: ["userId": userId])
            await AccessControlAuditManager.shared.add(
                AccessControlAuditEntry(action: "permission_checked:\(permission)", userId: userId)
            )
        }
        return granted
    }

    /// Grants a permission to a user.
    public func grantPermission(userId: String, permission: String) async throws {
        // ... (actual grant logic goes here)
        Task {
            await analytics.log(event: "permission_granted", parameters: ["userId": userId, "permission": permission])
            await audit.record("Granted permission \(permission)", metadata: ["userId": userId])
            await AccessControlAuditManager.shared.add(
                AccessControlAuditEntry(action: "permission_granted:\(permission)", userId: userId)
            )
        }
    }

    /// Revokes a permission from a user.
    public func revokePermission(userId: String, permission: String) async throws {
        // ... (actual revoke logic goes here)
        Task {
            await analytics.log(event: "permission_revoked", parameters: ["userId": userId, "permission": permission])
            await audit.record("Revoked permission \(permission)", metadata: ["userId": userId])
            await AccessControlAuditManager.shared.add(
                AccessControlAuditEntry(action: "permission_revoked:\(permission)", userId: userId)
            )
        }
    }
}

public extension AccessControlService {
    static func recentAuditEntries(limit: Int = 20) async -> [AccessControlAuditEntry] {
        await AccessControlAuditManager.shared.recent(limit: limit)
    }
    static func exportAuditLogJSON() async -> String {
        await AccessControlAuditManager.shared.exportJSON()
    }
}

