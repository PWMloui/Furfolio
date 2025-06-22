//
//  LoyaltyProgram.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated, enhanced, and cleaned for unified Furfolio architecture.
//

import Foundation
import SwiftData

// MARK: - LoyaltyProgram (Modular, Tokenized, Auditable Loyalty Program Model)

/// Represents a modular, auditable, and tokenized loyalty program entity tied to a dog owner.
/// This model supports comprehensive business analytics, compliance tracking, badge/status logic,
/// and integration with UI design systems (including badges, colors, and progress indicators).
/// It enables detailed audit trails for multi-user environments and drives owner engagement workflows.
@Model
final class LoyaltyProgram: Identifiable, ObservableObject {

    // MARK: - Identifiers

    /// Unique identifier for this loyalty program record.
    /// Serves as the primary key for audit and data integrity purposes.
    @Attribute(.unique)
    var id: UUID

    /// The dog owner associated with this loyalty program.
    /// Establishes business relationship and enables owner-level analytics and segmentation.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.loyaltyProgram)
    var owner: DogOwner?

    // MARK: - Program Data

    /// Current point balance representing earned loyalty tokens.
    /// Used for business logic on reward eligibility and analytics on engagement.
    @Attribute(.required)
    var points: Int

    /// Total number of visits tracked for this owner.
    /// Supports business workflows that reward visit frequency and drives compliance reporting.
    @Attribute(.required)
    var visitCount: Int

    /// History of redeemed rewards, supporting audit trails and compliance.
    /// Also enables UI display of past redemptions and analytics on reward utilization.
    @Attribute(.required)
    var rewardsRedeemed: [LoyaltyReward]

    /// Date of the most recent reward redemption.
    /// Useful for compliance auditing, business reporting, and triggering time-based workflows.
    var lastRewardDate: Date?

    /// Optional notes or custom program details.
    /// Supports business customization and audit annotations.
    var notes: String?

    // MARK: - Audit Trail

    /// Timestamp when this loyalty program record was created.
    /// Critical for compliance, auditing, and historical analytics.
    @Attribute(.required)
    var dateCreated: Date

    /// Timestamp when this record was last modified.
    /// Supports audit logging, change tracking, and workflow triggers.
    @Attribute(.required)
    var lastModified: Date

    /// Identifier for the user who created this record.
    /// Enables multi-user audit trails and accountability.
    var createdBy: String?

    /// Identifier for the user who last modified this record.
    /// Supports audit compliance and workflow notifications.
    var lastModifiedBy: String?

    /// Change history or audit log entries capturing significant events.
    /// Essential for compliance, troubleshooting, and business event analytics.
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
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
    }

    // MARK: - Constants

    /// Points required per reward.
    /// This threshold reflects the loyalty program's business strategy for balancing engagement and reward frequency.
    static let pointsPerReward = 50

    /// Visits required per reward (if using visit-based rewards).
    /// Reflects business logic encouraging frequent visits to increase customer retention.
    static let visitsPerReward = 5

    // MARK: - Business Logic

    /// Adds loyalty points and optionally increments visit count.
    /// This method updates audit logs with event details, supporting analytics and compliance.
    /// - Parameters:
    ///   - newPoints: The number of points to add.
    ///   - forVisit: Whether this addition corresponds to a visit increment.
    ///   - user: Optional identifier of the user performing the update, for audit tracking.
    func addPoints(_ newPoints: Int, forVisit: Bool = false, user: String? = nil) {
        points += newPoints
        if forVisit { visitCount += 1 }
        lastModified = Date()
        if let user = user { lastModifiedBy = user }
        auditLog.append("Added \(newPoints) points by \(user ?? "system") on \(DateFormatter.short.string(from: Date()))")
    }

    /// Redeems a reward if the owner is eligible, updating points and redemption history.
    /// Logs the redemption event for audit and analytics purposes, supporting business owner workflows.
    /// - Parameters:
    ///   - type: The type of reward to redeem.
    ///   - notes: Optional notes associated with this redemption.
    ///   - user: Optional user identifier performing the redemption.
    /// - Returns: True if redemption was successful, false if not eligible.
    func redeemReward(type: LoyaltyRewardType, notes: String? = nil, user: String? = nil) -> Bool {
        guard isEligibleForReward else { return false }
        points -= LoyaltyProgram.pointsPerReward
        let reward = LoyaltyReward(type: type, date: Date(), notes: notes)
        rewardsRedeemed.append(reward)
        lastRewardDate = reward.date
        lastModified = Date()
        if let user = user { lastModifiedBy = user }
        auditLog.append("Redeemed reward '\(type.displayName)' by \(user ?? "system") on \(DateFormatter.short.string(from: reward.date))")
        return true
    }

    /// Indicates whether the owner currently qualifies for a reward based on points.
    /// This encapsulates business rules for reward eligibility, facilitating analytics and UI state.
    var isEligibleForReward: Bool {
        points >= LoyaltyProgram.pointsPerReward
    }

    /// Progress ratio towards the next reward (range 0.0 to 1.0).
    /// Useful for UI progress bars, dashboards, and motivating owner engagement.
    var rewardProgress: Double {
        Double(points % LoyaltyProgram.pointsPerReward) / Double(LoyaltyProgram.pointsPerReward)
    }

    /// Display-friendly summary string for dashboards and owner-facing UI.
    /// Summarizes points and progress, supporting quick analytics and engagement at a glance.
    var summary: String {
        "Points: \(points) (\(rewardProgress * 100, specifier: "%.0f")% to reward)"
    }
}

// MARK: - Reward Type

/// Enumerates the types of rewards offered by the loyalty program.
/// Supports business logic for reward differentiation, analytics tracking of redemption types,
/// localization for UI display, and badge/status visualization within the app.
enum LoyaltyRewardType: String, Codable, CaseIterable, Identifiable {
    case freeBath
    case discount
    case freeNailTrim
    case custom

    var id: String { rawValue }

    /// Localized display name for UI and reporting.
    /// Enables consistent user-facing labels and supports multi-language compliance.
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

/// Represents a redeemed loyalty reward instance.
/// Captures analytics data for reward usage, supports audit trails for compliance,
/// and provides display information for owner-facing UI elements.
struct LoyaltyReward: Codable, Identifiable, Hashable {
    let id: UUID
    let type: LoyaltyRewardType
    let date: Date
    let notes: String?

    init(type: LoyaltyRewardType, date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.type = type
        self.date = date
        self.notes = notes
    }
}

// MARK: - DateFormatter Helper

private extension DateFormatter {
    /// Shared short date formatter used for audit logs and dashboard display.
    /// Localized to respect user settings and ensure consistent date/time presentation.
    static let short: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
