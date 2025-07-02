//
//  OnboardingPathProvider.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/**
 OnboardingPathProvider
 ----------------------
 Provides the onboarding sequence for different user roles in Furfolio, with support for dynamic descriptors, offline fallback, async audit logging, diagnostics, localization, and preview/testability.

 - **Architecture**: Static provider independent of UI, returning an array of `OnboardingStep` tokens.
 - **Concurrency & Audit**: Logs dynamic load and fallback usage asynchronously via `OnboardingPathAuditManager`.
 - **Localization**: All console messages use `NSLocalizedString` for internationalization.
 - **Diagnostics**: Exposes async methods for retrieving and exporting recent audit entries.
 - **Preview/Testability**: Can be tested by fetching steps for any role and inspecting audit logs.
 */

/// A record of an onboarding path load or fallback event.
public struct OnboardingPathAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let role: OnboardingRole
    public let usedFallback: Bool
    public let count: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), role: OnboardingRole, usedFallback: Bool, count: Int) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.usedFallback = usedFallback
        self.count = count
    }
}

/// Manages concurrency-safe audit logging for onboarding path events.
public actor OnboardingPathAuditManager {
    private var buffer: [OnboardingPathAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingPathAuditManager()

    /// Add a new audit entry, capping to `maxEntries`.
    public func add(_ entry: OnboardingPathAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingPathAuditEntry] {
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

// MARK: - OnboardingPathProvider

/// Provides a list of onboarding steps for a given user role
public struct OnboardingPathProvider {
    
    /// Returns steps dynamically filtered from step descriptors.
    /// Falls back to offline defaults if descriptors are missing.
    static func steps(for role: OnboardingRole, includeSkippable: Bool = true) -> [OnboardingStep] {
        let descriptors = OnboardingStepDescriptor.defaultDescriptors()
            .filter { $0.rolesApplicable.contains(role) && (includeSkippable || !$0.isSkippable) }

        if descriptors.isEmpty {
            let fallback = OfflineOnboardingFallback.defaultSteps(for: role)
            let message = String(
                format: NSLocalizedString("Using offline fallback for role: %@", comment: "Fallback console log"),
                role.rawValue
            )
            Task {
                await OnboardingPathAuditManager.shared.add(
                    OnboardingPathAuditEntry(role: role, usedFallback: true, count: fallback.count)
                )
                print(message)
            }
            return fallback
        }

        let result = descriptors.map { $0.id }
        let message = String(
            format: NSLocalizedString("Loaded %d steps for role: %@", comment: "Loaded console log"),
            result.count,
            role.rawValue
        )
        Task {
            await OnboardingPathAuditManager.shared.add(
                OnboardingPathAuditEntry(role: role, usedFallback: false, count: result.count)
            )
            print(message)
        }
        return result
    }
}

public extension OnboardingPathProvider {
    /// Fetches recent onboarding path audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingPathAuditEntry] {
        await OnboardingPathAuditManager.shared.recent(limit: limit)
    }

    /// Exports onboarding path audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await OnboardingPathAuditManager.shared.exportJSON()
    }
}
