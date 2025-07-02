//
//  OnboardingRole.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/**
 OnboardingRole
 --------------
 Represents the different user roles in Furfolio and their onboarding metadata.

 - **Architecture**: Tokenized enum conforming to `Identifiable`, `Codable`, `CaseIterable`, and `Hashable` for SwiftUI and networking.
 - **Localization**: All user-facing strings use `NSLocalizedString` for internationalization.
 - **Audit/Analytics Ready**: Provides async audit logging hooks via `OnboardingRoleAuditManager`.
 - **Accessibility**: Exposes localized display names and descriptions for VoiceOver.
 - **Preview/Testability**: SwiftUI previews can iterate roles and demonstrate localized output.
 */

public enum OnboardingRole: String, CaseIterable, Codable, Hashable, Identifiable {
    case manager
    case staff
    case receptionist

    public var id: String { rawValue }

    /// Human-readable role name
    public var displayName: String {
        switch self {
        case .manager:
            return NSLocalizedString("Manager", comment: "Role name: manager")
        case .staff:
            return NSLocalizedString("Staff", comment: "Role name: staff")
        case .receptionist:
            return NSLocalizedString("Receptionist", comment: "Role name: receptionist")
        }
    }

    /// Role description for onboarding screens or settings
    public var description: String {
        switch self {
        case .manager:
            return NSLocalizedString("Full access to scheduling, data import, permissions, and business management.", comment: "Role description: manager")
        case .staff:
            return NSLocalizedString("Focused access for groomers including tutorials and client interaction help.", comment: "Role description: staff")
        case .receptionist:
            return NSLocalizedString("Simplified onboarding focused on appointments and communication features.", comment: "Role description: receptionist")
        }
    }

    /// Optional SF Symbol icon for role-specific UI (onboarding, profile)
    public var iconName: String {
        switch self {
        case .manager: return "person.crop.rectangle.stack"
        case .staff: return "scissors"
        case .receptionist: return "phone.fill"
        }
    }
}

/// A record of an OnboardingRole audit event.
public struct OnboardingRoleAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let role: OnboardingRole
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), role: OnboardingRole, event: String) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.event = event
    }
}

/// Manages async, concurrency-safe audit logging for OnboardingRole events.
public actor OnboardingRoleAuditManager {
    private var buffer: [OnboardingRoleAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingRoleAuditManager()

    /// Add a new audit entry, capping the buffer to `maxEntries`.
    public func add(_ entry: OnboardingRoleAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingRoleAuditEntry] {
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

public extension OnboardingRole {
    /// Log an audit event for this role asynchronously.
    /// - Parameter event: Description of the audit event.
    func logAudit(event: String) async {
        let localized = NSLocalizedString(event, comment: "OnboardingRole audit event")
        let entry = OnboardingRoleAuditEntry(role: self, event: localized)
        await OnboardingRoleAuditManager.shared.add(entry)
    }

    /// Fetch recent audit entries for all roles.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingRoleAuditEntry] {
        await OnboardingRoleAuditManager.shared.recent(limit: limit)
    }

    /// Export the audit log as JSON asynchronously.
    static func exportAuditLogJSON() async -> String {
        await OnboardingRoleAuditManager.shared.exportJSON()
    }
}
