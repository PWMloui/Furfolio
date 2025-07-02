//
//  OnboardingStateStore.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingStateStore
 --------------------
 A singleton responsible for tracking and persisting onboarding completion state per user and role in Furfolio.

 - **Architecture**: Uses UserDefaults for persistence; exposes a shared instance for global access.
 - **Concurrency & Audit**: Provides async audit logging of completion events via `OnboardingStateAuditManager` actor.
 - **Diagnostics**: Audit entries can be fetched and exported for diagnostics and reporting.
 - **Localization**: Audit messages are localized via NSLocalizedString.
 - **Preview/Testability**: Audit methods can be used in tests to verify onboarding state changes.
 */

/// A record of an onboarding completion event for a specific user and role.
public struct OnboardingStateAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let userId: String
    public let role: OnboardingRole

    public init(id: UUID = UUID(), timestamp: Date = Date(), userId: String, role: OnboardingRole) {
        self.id = id
        self.timestamp = timestamp
        self.userId = userId
        self.role = role
    }
}

/// Manages concurrency-safe audit logging for onboarding state changes.
public actor OnboardingStateAuditManager {
    private var buffer: [OnboardingStateAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingStateAuditManager()

    /// Append a new audit entry, retaining only the most recent `maxEntries` entries.
    public func add(_ entry: OnboardingStateAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingStateAuditEntry] {
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

// MARK: - OnboardingStateStore.swift

final class OnboardingStateStore {
    static let shared = OnboardingStateStore()
    private init() {}

    func hasCompleted(role: OnboardingRole, userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: role, userId: userId))
    }

    func markCompleted(role: OnboardingRole, userId: String) {
        UserDefaults.standard.set(true, forKey: key(for: role, userId: userId))
        Task {
            let entry = OnboardingStateAuditEntry(userId: userId, role: role)
            await OnboardingStateAuditManager.shared.add(entry)
        }
    }

    /// Fetches recent onboarding completion audit entries for diagnostics.
    public func recentAuditEntries(limit: Int = 20) async -> [OnboardingStateAuditEntry] {
        await OnboardingStateAuditManager.shared.recent(limit: limit)
    }

    /// Exports onboarding completion audit log as JSON.
    public func exportAuditLogJSON() async -> String {
        await OnboardingStateAuditManager.shared.exportJSON()
    }

    private func key(for role: OnboardingRole, userId: String) -> String {
        "onboarding_complete_\(userId)_\(role.rawValue)"
    }
}
