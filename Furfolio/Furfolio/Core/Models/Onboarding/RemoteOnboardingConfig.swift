//
//  RemoteOnboardingConfig.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 RemoteOnboardingConfig
 -----------------------
 Represents a remote-driven onboarding configuration for Furfolio.

 - **Architecture**: Decodable model defining role-specific step sequences.
 - **Concurrency & Audit**: Provides async audit logging via `RemoteOnboardingConfigAuditManager`.
 - **Diagnostics**: Errors and loads are recorded for troubleshooting.
 - **Localization**: Error messages are localized.
 - **Preview/Testability**: Includes a mock loader and extension methods for audit retrieval.
 */

import Foundation

/// Represents a remote onboarding configuration response
public struct RemoteOnboardingConfig: Decodable {
    public let role: OnboardingRole
    public let steps: [OnboardingStep]

    enum CodingKeys: String, CodingKey {
        case role
        case steps
    }
}

/// A record of remote onboarding config load events.
public struct RemoteOnboardingConfigAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let role: OnboardingRole
    public let steps: [OnboardingStep]
    public let success: Bool
    public let errorMessage: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), role: OnboardingRole, steps: [OnboardingStep], success: Bool, errorMessage: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.steps = steps
        self.success = success
        self.errorMessage = errorMessage
    }
}

/// Manages concurrency-safe audit logging for remote config events.
public actor RemoteOnboardingConfigAuditManager {
    private var buffer: [RemoteOnboardingConfigAuditEntry] = []
    private let maxEntries = 100
    public static let shared = RemoteOnboardingConfigAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: RemoteOnboardingConfigAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [RemoteOnboardingConfigAuditEntry] {
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

extension RemoteOnboardingConfig {
    /// Decodes config from remote JSON data
    static func load(from data: Data) -> RemoteOnboardingConfig? {
        let decoder = JSONDecoder()
        do {
            let config = try decoder.decode(RemoteOnboardingConfig.self, from: data)
            Task {
                await RemoteOnboardingConfigAuditManager.shared.add(
                    RemoteOnboardingConfigAuditEntry(role: config.role, steps: config.steps, success: true)
                )
            }
            return config
        } catch {
            let message = NSLocalizedString("Failed to decode RemoteOnboardingConfig: \(error)", comment: "Remote config decode error")
            print("❌ \(message)")
            Task {
                await RemoteOnboardingConfigAuditManager.shared.add(
                    RemoteOnboardingConfigAuditEntry(role: .manager, steps: [], success: false, errorMessage: message)
                )
            }
            return nil
        }
    }

    /// Simulated example for development
    static func mock(for role: OnboardingRole) -> RemoteOnboardingConfig {
        let config: RemoteOnboardingConfig
        switch role {
        case .manager:
            config = RemoteOnboardingConfig(role: .manager, steps: [.welcome, .dataImport, .tutorial, .permissions, .completion])
        case .staff:
            config = RemoteOnboardingConfig(role: .staff, steps: [.welcome, .tutorial, .faq, .completion])
        case .receptionist:
            config = RemoteOnboardingConfig(role: .receptionist, steps: [.welcome, .tutorial, .completion])
        }
        Task {
            await RemoteOnboardingConfigAuditManager.shared.add(
                RemoteOnboardingConfigAuditEntry(role: role, steps: config.steps, success: true)
            )
        }
        return config
    }
}

public extension RemoteOnboardingConfig {
    /// Fetch recent remote config audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [RemoteOnboardingConfigAuditEntry] {
        await RemoteOnboardingConfigAuditManager.shared.recent(limit: limit)
    }

    /// Export remote config audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await RemoteOnboardingConfigAuditManager.shared.exportJSON()
    }
}
