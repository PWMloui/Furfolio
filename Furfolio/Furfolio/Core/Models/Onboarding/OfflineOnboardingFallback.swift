//
//  OfflineOnboardingFallback.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


import Foundation

/// A record of an offline onboarding fallback audit event.
public struct OfflineOnboardingAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let role: OnboardingRole
    public let steps: [OnboardingStep]

    public init(id: UUID = UUID(), timestamp: Date = Date(), role: OnboardingRole, steps: [OnboardingStep]) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.steps = steps
    }
}

/// Manages concurrency-safe audit logging for offline onboarding fallback events.
public actor OfflineOnboardingAuditManager {
    private var buffer: [OfflineOnboardingAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OfflineOnboardingAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: OfflineOnboardingAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recentEntries(limit: Int = 20) -> [OfflineOnboardingAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as pretty-printed JSON.
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

/**
 OfflineOnboardingFallback
 --------------------------
 Provides a fallback onboarding experience when dynamic or remote configuration is unavailable.

 - **Architecture**: Static helper for determining default steps and messaging.
 - **Concurrency & Audit**: Logs fallback usage asynchronously via `OfflineOnboardingAuditManager` actor.
 - **Diagnostics**: Enables retrieval and export of audit entries for admin review.
 - **Localization**: All user-facing text is localized via NSLocalizedString.
 - **Preview/Testability**: Can be tested offline with mock Reachability; audit entries are accessible asynchronously.
 */
struct OfflineOnboardingFallback {
    /// Returns a fallback set of onboarding steps if needed
    static func defaultSteps(for role: OnboardingRole) -> [OnboardingStep] {
        let steps: [OnboardingStep]
        switch role {
        case .manager:
            steps = [.welcome, .tutorial, .permissions, .completion]
        case .staff:
            steps = [.welcome, .tutorial, .faq, .completion]
        case .receptionist:
            steps = [.welcome, .tutorial, .completion]
        }
        Task {
            await OfflineOnboardingAuditManager.shared.add(
                OfflineOnboardingAuditEntry(role: role, steps: steps)
            )
        }
        return steps
    }

    /// Returns a message to show when fallback is activated
    static var explanation: String {
        NSLocalizedString(
            "You're offline, so we're showing the default onboarding experience. You can access all features once you're connected again.",
            comment: "Offline onboarding explanation message"
        )
    }

    /// Returns whether we are currently offline (basic check)
    static var isOffline: Bool {
        !Reachability.isConnectedToNetwork()
    }

    /// Fetch recent audit entries for offline fallback usage.
    public static func recentAuditEntries(limit: Int = 20) async -> [OfflineOnboardingAuditEntry] {
        await OfflineOnboardingAuditManager.shared.recentEntries(limit: limit)
    }

    /// Export offline onboarding audit log as JSON.
    public static func exportAuditLogJSON() async -> String {
        await OfflineOnboardingAuditManager.shared.exportJSON()
    }
}
