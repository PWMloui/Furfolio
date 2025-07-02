//
//  LoyaltyProgram.swift
//  Furfolio
//
//  Enhanced for tiers, expiry, tokenization, audit, analytics, and accessibility.
//
import Foundation
import SwiftData
import SwiftData

/**
 `LoyaltyProgram` is a comprehensive model representing a customer's loyalty engagement within the Furfolio ecosystem.  

 **Architecture & Concurrency:**  
 Designed as a SwiftData `@Model` class, it supports reactive updates and observability. Audit logging is offloaded to a concurrency-safe `actor` (`LoyaltyProgramAuditManager`) ensuring thread-safe mutation and retrieval of audit events, suitable for multi-threaded or async environments.

 **Audit & Analytics Hooks:**  
 The class tracks detailed audit logs with timestamps and user attribution. It supports analytics-ready computed properties such as tier segmentation, reward progress, and expiry notifications. Audit entries are asynchronously logged and can be exported as JSON for diagnostics or compliance.

 **Diagnostics & Export:**  
 Provides JSON export of program state and audit logs to facilitate reporting, backup, or migration workflows.

 **Localization & Accessibility:**  
 All user-facing strings are localized via `NSLocalizedString` to support internationalization. Accessibility labels are provided to improve UI/UX for assistive technologies.

 **Preview & Testability:**  
 The model includes default initializers and mockable properties to facilitate SwiftUI previews and unit testing.

 This design balances rich domain modeling with modern Swift concurrency and localization best practices.
 */

/// A record of a LoyaltyProgram audit event.
@Model public struct LoyaltyProgramAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String
    public let user: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String, user: String? = nil) {
        self.id = id; self.timestamp = timestamp; self.entry = entry; self.user = user
    }
}

/// Manages concurrency-safe audit logging for LoyaltyProgram events.
public actor LoyaltyProgramAuditManager {
    private var buffer: [LoyaltyProgramAuditEntry] = []
    private let maxEntries = 100
    public static let shared = LoyaltyProgramAuditManager()

    /// Add a new audit entry, capping to `maxEntries`.
    public func add(_ entry: LoyaltyProgramAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [LoyaltyProgramAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

@Model
final class LoyaltyProgram: Identifiable, ObservableObject {

    // MARK: - Identifiers

    @Attribute(.unique) var id: UUID
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.loyaltyProgram)
    var owner: DogOwner?

    // MARK: - Program Data

    @Attribute(.required) var points: Int
    @Attribute(.required) var visitCount: Int
    @Attribute(.required) var rewardsRedeemed: [LoyaltyReward]
    var lastRewardDate: Date?
    var notes: String?

    // MARK: - Tier, Badges, Expiry

    /// Type-safe program segmentation, analytics & UI
    enum LoyaltyBadge: String, CaseIterable, Codable {
        case highEngager, atRisk, newMember, platinum, gold, silver, bronze
    }
    var badgeTokens: [String]
    @Attribute(.transient) var badges: [LoyaltyBadge] { badgeTokens.compactMap { LoyaltyBadge(rawValue: $0) } }

    /// Add a badge and log the action.
    public func addBadge(_ badge: LoyaltyBadge, user: String? = nil) async {
        if !badgeTokens.contains(badge.rawValue) {
            badgeTokens.append(badge.rawValue)
            await addAudit("Added badge \(badge.rawValue)", user: user)
        }
    }

    /// Remove a badge and log the action.
    public func removeBadge(_ badge: LoyaltyBadge, user: String? = nil) async {
        badgeTokens.removeAll { $0 == badge.rawValue }
        await addAudit("Removed badge \(badge.rawValue)", user: user)
    }

    func hasBadge(_ badge: LoyaltyBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    /// Loyalty tier, determined by points or visits
    @Attribute(.transient) var tier: String {
        switch points {
        case 0..<100:  NSLocalizedString("Bronze", comment: "Loyalty tier Bronze")
        case 100..<250: NSLocalizedString("Silver", comment: "Loyalty tier Silver")
        case 250..<500: NSLocalizedString("Gold", comment: "Loyalty tier Gold")
        default: NSLocalizedString("Platinum", comment: "Loyalty tier Platinum")
        }
    }

    // MARK: - Reward Expiry Support

    /// Optional: Expiry period in days for rewards (business rule)
    static let rewardExpiryDays: Int = 180
    @Attribute(.transient) var expiringSoonRewards: [LoyaltyReward] {
        let soon = Calendar.current.date(byAdding: .day, value: Self.rewardExpiryDays, to: Date())!
        return rewardsRedeemed.filter { $0.expiryDate != nil && $0.expiryDate! < soon && $0.expiryDate! > Date() }
    }

    // MARK: - Audit Trail

    @Attribute(.required) var dateCreated: Date
    @Attribute(.required) var lastModified: Date
    var createdBy: String?
    var lastModifiedBy: String?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        owner: DogOwner? = nil,
        points: Int = 0,
        visitCount: Int = 0,
        rewardsRedeemed: [LoyaltyReward] = [],
        lastRewardDate: Date? = nil,
        notes: String? = nil,
        badgeTokens: [String] = [],
        dateCreated: Date = Date(),
        lastModified: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil
    ) {
        self.id = id
        self.owner = owner
        self.points = points
        self.visitCount = visitCount
        self.rewardsRedeemed = rewardsRedeemed
        self.lastRewardDate = lastRewardDate
        self.notes = notes
        self.badgeTokens = badgeTokens
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
    }

    // MARK: - Constants

    static let pointsPerReward = 50
    static let visitsPerReward = 5

    // MARK: - Business Logic

    func addPoints(_ newPoints: Int, forVisit: Bool = false, user: String? = nil) {
        points += newPoints
        if forVisit { visitCount += 1 }
        lastModified = Date()
        if let user = user { lastModifiedBy = user }
        Task {
            await addAudit(String(format: NSLocalizedString("Added %d points", comment: "Audit log added points"), newPoints), user: user)
        }
    }

    func redeemReward(type: LoyaltyRewardType, notes: String? = nil, user: String? = nil) -> Bool {
        guard isEligibleForReward else { return false }
        points -= LoyaltyProgram.pointsPerReward
        let reward = LoyaltyReward(type: type, date: Date(), notes: notes, expiryDate: Calendar.current.date(byAdding: .day, value: Self.rewardExpiryDays, to: Date()))
        rewardsRedeemed.append(reward)
        lastRewardDate = reward.date
        lastModified = Date()
        if let user = user { lastModifiedBy = user }
        Task {
            await addAudit(String(format: NSLocalizedString("Redeemed reward '%@'", comment: "Audit log redeemed reward"), type.displayName), user: user)
        }
        return true
    }

    @Attribute(.transient) var isEligibleForReward: Bool { points >= LoyaltyProgram.pointsPerReward }
    @Attribute(.transient) var rewardProgress: Double { Double(points % LoyaltyProgram.pointsPerReward) / Double(LoyaltyProgram.pointsPerReward) }
    @Attribute(.transient) var summary: String {
        String(
            format: NSLocalizedString("Tier: %@ • Points: %d (%.0f%% to reward)", comment: "Loyalty summary"),
            tier, points, rewardProgress * 100
        )
    }

    // MARK: - Analytics & Export

    /// Time since last reward
    @Attribute(.transient) var daysSinceLastReward: Int? {
        guard let last = lastRewardDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
    /// Number of rewards expiring within 30 days
    @Attribute(.transient) var expiringRewardsCount: Int {
        expiringSoonRewards.count
    }

    /// Export this program as JSON for reporting/migration
    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID, ownerID: UUID?, points: Int, visitCount: Int, tier: String, rewardsRedeemed: [LoyaltyReward], badges: [String], dateCreated: Date
        }
        let export = Export(id: id, ownerID: owner?.id, points: points, visitCount: visitCount, tier: tier, rewardsRedeemed: rewardsRedeemed, badges: badgeTokens, dateCreated: dateCreated)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Audit Methods

    /// Asynchronously logs an audit entry.
    /// - Parameters:
    ///   - entry: Description of the change.
    ///   - user: Optional user who made the change.
    public func addAudit(_ entry: String, user: String? = nil) async {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let localizedEntry = NSLocalizedString(entry, comment: "LoyaltyProgram audit log entry")
        let auditEntry = LoyaltyProgramAuditEntry(timestamp: Date(), entry: "[\(ts)] \(localizedEntry)", user: user)
        await LoyaltyProgramAuditManager.shared.add(auditEntry)
        lastModified = Date()
        if let user { lastModifiedBy = user }
    }

    /// Fetches recent audit entries asynchronously.
    public func recentAuditEntries(limit: Int = 3) async -> [LoyaltyProgramAuditEntry] {
        await LoyaltyProgramAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as JSON asynchronously.
    public func exportAuditLogJSON() async -> String {
        await LoyaltyProgramAuditManager.shared.exportJSON()
    }

    // MARK: - Accessibility

    @Attribute(.transient) var accessibilityLabel: String {
        NSLocalizedString(
            "Loyalty tier: \(tier). \(points) points. \(rewardsRedeemed.count) rewards redeemed. \(isEligibleForReward ? NSLocalizedString("Eligible for reward.", comment: "") : "")",
            comment: "Accessibility label for LoyaltyProgram"
        )
    }
}

// MARK: - Reward Type

enum LoyaltyRewardType: String, Codable, CaseIterable, Identifiable {
    case freeBath, discount, freeNailTrim, custom

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .freeBath:      return NSLocalizedString("Free Bath", comment: "")
        case .discount:      return NSLocalizedString("Discount", comment: "")
        case .freeNailTrim:  return NSLocalizedString("Free Nail Trim", comment: "")
        case .custom:        return NSLocalizedString("Custom Reward", comment: "")
        }
    }
}

// MARK: - Loyalty Reward

struct LoyaltyReward: Codable, Identifiable, Hashable {
    let id: UUID
    let type: LoyaltyRewardType
    let date: Date
    let notes: String?
    /// Optional expiry date for this reward (e.g., 6 months after redemption)
    let expiryDate: Date?

    init(type: LoyaltyRewardType, date: Date = Date(), notes: String? = nil, expiryDate: Date? = nil) {
        self.id = UUID()
        self.type = type
        self.date = date
        self.notes = notes
        self.expiryDate = expiryDate
    }
}

// MARK: - DateFormatter Helper

private extension DateFormatter {
    static let short: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
