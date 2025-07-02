//
//  LoyaltyTier.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 LoyaltyTier
 -----------
 A tokenized, auditable model representing customer loyalty tiers in Furfolio.

 - **Architecture**: Enum-based design conforming to Identifiable, Codable, and CaseIterable for easy use in SwiftUI and networking.
 - **Concurrency & Audit**: Provides async audit logging hooks via `LoyaltyTierAuditManager` actor to record tier-related events safely.
 - **Localization**: All user-facing strings use `NSLocalizedString` for internationalization.
 - **Accessibility**: Computed properties include localized accessibility labels.
 - **Diagnostics**: Async methods to fetch and export recent audit entries for diagnostics and admin review.
 - **Preview/Testability**: Includes SwiftUI previews demonstrating tier display and audit log functionality.
 */

import Foundation
import SwiftUI
import SwiftData

/// Represents the available loyalty tiers.
public enum LoyaltyTier: String, Codable, CaseIterable, Identifiable {
    public var id: String { rawValue }

    case bronze
    case silver
    case gold
    case platinum

    /// Localized display name for the tier.
    public var displayName: String {
        NSLocalizedString(rawValue.capitalized, comment: "Loyalty tier name")
    }

    /// Localized description for the tier.
    public var description: String {
        switch self {
        case .bronze:
            return NSLocalizedString("Bronze tier - Up to 99 points", comment: "Bronze tier description")
        case .silver:
            return NSLocalizedString("Silver tier - 100 to 249 points", comment: "Silver tier description")
        case .gold:
            return NSLocalizedString("Gold tier - 250 to 499 points", comment: "Gold tier description")
        case .platinum:
            return NSLocalizedString("Platinum tier - 500+ points", comment: "Platinum tier description")
        }
    }

    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: Text {
        Text(String(format: NSLocalizedString("Tier %@: %@", comment: "Accessibility label for loyalty tier"), displayName, description))
    }
}

// MARK: - Audit Entry & Manager

/// A record of a LoyaltyTier audit event.
@Model public struct LoyaltyTierAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let tier: LoyaltyTier
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), tier: LoyaltyTier, event: String) {
        self.id = id
        self.timestamp = timestamp
        self.tier = tier
        self.event = event
    }
}

/// Manages concurrency-safe audit logging for LoyaltyTier events.
public actor LoyaltyTierAuditManager {
    private var buffer: [LoyaltyTierAuditEntry] = []
    private let maxEntries = 100
    public static let shared = LoyaltyTierAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: LoyaltyTierAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [LoyaltyTierAuditEntry] {
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

// MARK: - LoyaltyTier Async Audit Methods

public extension LoyaltyTier {
    /// Log an audit event for this tier.
    /// - Parameter event: Description of the event.
    public func logAudit(event: String) async {
        let localized = NSLocalizedString(event, comment: "LoyaltyTier audit event")
        let entry = LoyaltyTierAuditEntry(tier: self, event: localized)
        await LoyaltyTierAuditManager.shared.add(entry)
    }

    /// Fetch recent audit entries asynchronously.
    public static func recentAuditEntries(limit: Int = 20) async -> [LoyaltyTierAuditEntry] {
        await LoyaltyTierAuditManager.shared.recent(limit: limit)
    }

    /// Export the audit log as JSON asynchronously.
    public static func exportAuditLogJSON() async -> String {
        await LoyaltyTierAuditManager.shared.exportJSON()
    }
}

// MARK: - PreviewProvider

#if DEBUG
struct LoyaltyTier_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ForEach(LoyaltyTier.allCases) { tier in
                VStack(alignment: .leading) {
                    Text(tier.displayName)
                        .font(.headline)
                    Text(tier.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Log Audit") {
                        Task {
                            await tier.logAudit(event: "Viewed tier \(tier.rawValue)")
                            let recent = await LoyaltyTier.recentAuditEntries(limit: 5)
                            print(recent)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}
#endif
