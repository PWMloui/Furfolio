
/**
 FurfolioRole
 ------------
 Represents user roles within Furfolio, providing display metadata and audit logging hooks.

 - **Architecture**: Tokenized enum conforming to `Identifiable`, `CaseIterable`, and `Codable` for SwiftUI and networking.
 - **Localization**: All user-facing strings use `NSLocalizedString`.
 - **Audit/Analytics Ready**: Includes async audit logging via `FurfolioRoleAuditManager`.
 - **Accessibility**: Provides `displayName` suitable for VoiceOver.
 - **Diagnostics & Preview/Testability**: Exposes async methods to record and retrieve audit events for role-related actions.
 */

import Foundation

public enum FurfolioRole: String, CaseIterable, Identifiable, Codable {
    case owner = "Owner"
    case assistant = "Assistant"
    case receptionist = "Receptionist"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .owner: return NSLocalizedString("Manager / Owner", comment: "Role display name for owner")
        case .assistant: return NSLocalizedString("Staff", comment: "Role display name for assistant")
        case .receptionist: return NSLocalizedString("Front Desk", comment: "Role display name for receptionist")
        }
    }

    /// A brief localized description for the role.
    public var description: String {
        switch self {
        case .owner:
            return NSLocalizedString("Full access to all features", comment: "Role description for owner")
        case .assistant:
            return NSLocalizedString("Can manage appointments and clients", comment: "Role description for assistant")
        case .receptionist:
            return NSLocalizedString("Handles calls and scheduling", comment: "Role description for receptionist")
        }
    }

    public var systemIcon: String {
        switch self {
        case .owner: return "chart.bar.fill"
        case .assistant: return "scissors"
        case .receptionist: return "phone.fill"
        }
    }
}

// MARK: - Audit Entry & Manager

/// A record of a FurfolioRole audit event.
public struct FurfolioRoleAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let role: FurfolioRole
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), role: FurfolioRole, event: String) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.event = event
    }
}

/// Manages concurrency-safe audit logging for role-related events.
public actor FurfolioRoleAuditManager {
    private var buffer: [FurfolioRoleAuditEntry] = []
    private let maxEntries = 100
    public static let shared = FurfolioRoleAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: FurfolioRoleAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [FurfolioRoleAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a pretty-printed JSON string.
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

// MARK: - Async Audit Methods

public extension FurfolioRole {
    /// Log a role-related event asynchronously.
    /// - Parameter event: Description of the event.
    func logAudit(event: String) async {
        let localized = NSLocalizedString(event, comment: "Role audit event")
        let entry = FurfolioRoleAuditEntry(role: self, event: localized)
        await FurfolioRoleAuditManager.shared.add(entry)
    }

    /// Fetch recent role audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [FurfolioRoleAuditEntry] {
        await FurfolioRoleAuditManager.shared.recent(limit: limit)
    }

    /// Export the role audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await FurfolioRoleAuditManager.shared.exportJSON()
    }
}
