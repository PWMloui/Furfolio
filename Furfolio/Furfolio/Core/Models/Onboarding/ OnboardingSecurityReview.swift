//
//  OnboardingSecurityReview.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingSecurityReview
 ------------------------
 A model representing the user’s acceptance of security and privacy terms during onboarding in Furfolio.

 - **Architecture**: Codable struct used for persistence and compliance checks.
 - **Concurrency & Audit**: Provides async/await audit logging via `OnboardingSecurityAuditManager` actor.
 - **Diagnostics**: Tracks consent events with timestamps for audit and reporting.
 - **Localization**: All user-facing audit entries and timestamps use `NSLocalizedString`.
 - **Preview/Testability**: Includes async methods to fetch and export audit entries for diagnostics.
 */

/// A record of a security onboarding audit event.
public struct OnboardingSecurityAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

struct OnboardingSecurityReview: Codable {
    var hasAcceptedTerms: Bool
    var hasReviewedPrivacyPolicy: Bool
    var consentTimestamp: Date?
    
    static let storageKey = "onboarding_security_review"

    /// Load the stored state from UserDefaults.
    /// Returns the saved OnboardingSecurityReview or a default instance if none is stored.
    static func load() -> OnboardingSecurityReview {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OnboardingSecurityReview.self, from: data) else {
            return OnboardingSecurityReview(hasAcceptedTerms: false, hasReviewedPrivacyPolicy: false, consentTimestamp: nil)
        }
        return decoded
    }

    /// Save the current state to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Mark both terms and privacy as accepted, timestamp consent, save, and log audit.
    mutating func acceptAll() async {
        hasAcceptedTerms = true
        hasReviewedPrivacyPolicy = true
        consentTimestamp = Date()
        save()
        let entry = NSLocalizedString("User accepted terms and privacy policy", comment: "Audit event")
        await OnboardingSecurityAuditManager.shared.add(OnboardingSecurityAuditEntry(event: entry))
    }

    /// Fetch recent audit entries for diagnostics.
    func recentAuditEntries(limit: Int = 20) async -> [OnboardingSecurityAuditEntry] {
        await OnboardingSecurityAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as JSON string.
    func exportAuditLogJSON() async -> String {
        await OnboardingSecurityAuditManager.shared.exportJSON()
    }

    /// Reset to default state
    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

/// Manages concurrency-safe audit logging for onboarding security review events.
public actor OnboardingSecurityAuditManager {
    private var buffer: [OnboardingSecurityAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingSecurityAuditManager()

    /// Add a new audit entry, capping the buffer at `maxEntries`.
    public func add(_ entry: OnboardingSecurityAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingSecurityAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a pretty-printed JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }
}
