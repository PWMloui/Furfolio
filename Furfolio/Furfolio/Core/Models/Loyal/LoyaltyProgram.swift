//
//  LoyaltyProgram.swift
//  Furfolio
//
//  Enhanced for tiers, expiry, tokenization, audit, analytics, and accessibility.
//
import Foundation
import SwiftData

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
    var badges: [LoyaltyBadge] { badgeTokens.compactMap { LoyaltyBadge(rawValue: $0) } }
    func addBadge(_ badge: LoyaltyBadge) { if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) } }
    func removeBadge(_ badge: LoyaltyBadge) { badgeTokens.removeAll { $0 == badge.rawValue } }
    func hasBadge(_ badge: LoyaltyBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    /// Loyalty tier, determined by points or visits
    var tier: String {
        switch points {
        case 0..<100:  "Bronze"
        case 100..<250: "Silver"
        case 250..<500: "Gold"
        default: "Platinum"
        }
    }

    // MARK: - Reward Expiry Support

    /// Optional: Expiry period in days for rewards (business rule)
    static let rewardExpiryDays: Int = 180
    var expiringSoonRewards: [LoyaltyReward] {
        let soon = Calendar.current.date(byAdding: .day, value: Self.rewardExpiryDays, to: Date())!
        return rewardsRedeemed.filter { $0.expiryDate != nil && $0.expiryDate! < soon && $0.expiryDate! > Date() }
    }

    // MARK: - Audit Trail

    @Attribute(.required) var dateCreated: Date
    @Attribute(.required) var lastModified: Date
    var createdBy: String?
    var lastModifiedBy: String?
    var auditLog: [String]

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
        lastModifiedBy: String? = nil,
        auditLog: [String] = []
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
        self.auditLog = auditLog
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
        auditLog.append("Added \(newPoints) points by \(user ?? "system") on \(DateFormatter.short.string(from: Date()))")
    }

    func redeemReward(type: LoyaltyRewardType, notes: String? = nil, user: String? = nil) -> Bool {
        guard isEligibleForReward else { return false }
        points -= LoyaltyProgram.pointsPerReward
        let reward = LoyaltyReward(type: type, date: Date(), notes: notes, expiryDate: Calendar.current.date(byAdding: .day, value: Self.rewardExpiryDays, to: Date()))
        rewardsRedeemed.append(reward)
        lastRewardDate = reward.date
        lastModified = Date()
        if let user = user { lastModifiedBy = user }
        auditLog.append("Redeemed reward '\(type.displayName)' by \(user ?? "system") on \(DateFormatter.short.string(from: reward.date))")
        return true
    }

    var isEligibleForReward: Bool { points >= LoyaltyProgram.pointsPerReward }
    var rewardProgress: Double { Double(points % LoyaltyProgram.pointsPerReward) / Double(LoyaltyProgram.pointsPerReward) }
    var summary: String {
        "Tier: \(tier) • Points: \(points) (\(rewardProgress * 100, specifier: "%.0f")% to reward)"
    }

    // MARK: - Analytics & Export

    /// Time since last reward
    var daysSinceLastReward: Int? {
        guard let last = lastRewardDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
    /// Number of rewards expiring within 30 days
    var expiringRewardsCount: Int {
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

    // MARK: - Audit Helpers

    func addAudit(_ entry: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(ts)] \(entry)")
        lastModified = Date()
    }
    func recentAudit(_ count: Int = 3) -> [String] { Array(auditLog.suffix(count)) }

    // MARK: - Accessibility

    var accessibilityLabel: String {
        "Loyalty tier: \(tier). \(points) points. \(rewardsRedeemed.count) rewards redeemed. \(isEligibleForReward ? "Eligible for reward." : "")"
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
