//
//  Badge.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - Badge (Unified, Modular, Tokenized, Auditable Badge System)

/// Types of badges available in Furfolio.
///
/// This enum defines all badge types in a modular, tokenized manner, enabling consistent audit trails,
/// comprehensive analytics, business logic enforcement, and seamless integration with SwiftUI and SwiftData.
/// Each badge type is fully documented, tokenized, and prepared for localization, audit, reporting, and UI token/badge integration.
/// This design ensures badges can be leveraged across dashboards, workflows, and reporting systems with clarity and consistency.
enum BadgeType: String, CaseIterable, Identifiable, Codable {
    case birthday
    case topSpender
    case loyaltyStar
    case newClient
    case retentionRisk
    case behaviorGood
    case behaviorChallenging
    case needsVaccine
    case custom

    /// Unique identifier for the badge type.
    ///
    /// Used for audit logging, analytics grouping, and UI binding.
    var id: String { rawValue }

    /// Emoji or system icon representing the badge.
    ///
    /// Utilized as a UI token for badge display components, ensuring consistent visual representation across the app.
    var icon: String {
        switch self {
        case .birthday: return "🎂"
        case .topSpender: return "💸"
        case .loyaltyStar: return "🏆"
        case .newClient: return "✨"
        case .retentionRisk: return "⚠️"
        case .behaviorGood: return "🟢"
        case .behaviorChallenging: return "🔴"
        case .needsVaccine: return "💉"
        case .custom: return "🔖"
        }
    }

    /// User-facing label for the badge.
    ///
    /// Used in UI components as a localized badge token label and for audit-friendly display.
    var label: String {
        switch self {
        case .birthday: return "Birthday"
        case .topSpender: return "Top Spender"
        case .loyaltyStar: return "Loyalty Star"
        case .newClient: return "New Client"
        case .retentionRisk: return "Retention Risk"
        case .behaviorGood: return "Good Behavior"
        case .behaviorChallenging: return "Challenging Behavior"
        case .needsVaccine: return "Needs Vaccine"
        case .custom: return "Custom"
        }
    }

    /// Optional description for tooltips, detail screens, localization keys, audit logs, and reporting.
    ///
    /// Provides context for the badge’s meaning in UI tooltips and supports detailed audit and analytics explanations.
    var description: String {
        switch self {
        case .birthday: return "It's this pet’s birthday month!"
        case .topSpender: return "This owner is among your top spenders."
        case .loyaltyStar: return "This owner is a loyalty program star."
        case .newClient: return "Recently added to Furfolio."
        case .retentionRisk: return "This client hasn’t booked in a while."
        case .behaviorGood: return "Pet consistently shows good behavior."
        case .behaviorChallenging: return "Challenging grooming behavior."
        case .needsVaccine: return "Pet has a vaccination due."
        case .custom: return "Custom badge."
        }
    }
}

/// Represents a badge awarded to any entity within Furfolio (e.g., Dog, Owner, Appointment).
///
/// This struct implements a modular, tokenized, auditable, and fully SwiftUI/SwiftData-integrated badge system.
/// It supports audit trails, multi-user assignment, flexible entity association, and detailed analytics reporting.
/// Badges can be associated with any model entity, enabling comprehensive dashboard integration,
/// business logic enforcement, and UI token/badge rendering.
/// All properties and methods are designed for clarity in audit, business workflows, and UI presentation.
struct Badge: Identifiable, Codable, Hashable, Equatable {
    // MARK: - Identifiers

    /// Unique identifier for this badge instance.
    ///
    /// Essential for audit trails, unique record identification, and entity tracking in analytics.
    let id: UUID

    /// The type of badge awarded.
    ///
    /// Central to business logic, UI token rendering, audit classification, and analytics grouping.
    let type: BadgeType

    /// The date when the badge was awarded.
    ///
    /// Important for audit timelines, reporting periods, and time-based business rules.
    let dateAwarded: Date

    /// Optional notes or comments associated with the badge.
    ///
    /// Supports audit detail, user annotations, and contextual information for business workflows and reporting.
    let notes: String?

    /// The type of entity this badge is associated with (e.g., "Dog", "Owner", "Appointment").
    ///
    /// Enables flexible linkage to any model entity for dashboard displays, audit trail, and business process integration.
    let entityType: String?

    /// The unique identifier of the entity this badge is associated with.
    ///
    /// Must correspond to the entityType's instance ID, enabling precise entity-badge relationship tracking for audit and analytics.
    let entityID: UUID?

    /// Identifier of the user who awarded this badge.
    ///
    /// Supports multi-user audit trails, accountability, and user-based analytics.
    let awardedBy: UUID?

    // MARK: - Initialization

    /// Initializes a new badge instance.
    ///
    /// - Parameters:
    ///   - type: The type of badge awarded, used for business logic, UI tokens, and audit classification.
    ///   - dateAwarded: The date the badge was awarded; defaults to current date for accurate audit timelines.
    ///   - notes: Optional notes providing context for audit, reporting, and business workflows.
    ///   - entityType: Optional string representing the associated entity type, enabling flexible dashboard and audit linkage.
    ///   - entityID: Optional UUID of the associated entity instance, essential for precise audit and analytics tracking.
    ///   - awardedBy: Optional UUID of the user who awarded the badge, supporting multi-user audit and accountability.
    init(
        type: BadgeType,
        dateAwarded: Date = Date(),
        notes: String? = nil,
        entityType: String? = nil,
        entityID: UUID? = nil,
        awardedBy: UUID? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.dateAwarded = dateAwarded
        self.notes = notes
        self.entityType = entityType
        self.entityID = entityID
        self.awardedBy = awardedBy
    }

    // MARK: - Computed Properties

    /// A display-friendly string combining icon and label for UI presentation.
    ///
    /// Used in UI badge components and reporting views as a tokenized representation.
    var displayString: String {
        "\(type.icon) \(type.label)"
    }

    // MARK: - Static Helpers

    /// Helper to create a birthday badge for a given entity.
    ///
    /// Simplifies badge creation with audit and UI token consistency for birthday recognition workflows.
    ///
    /// - Parameters:
    ///   - entityType: The type of entity (e.g., "Dog") to associate the badge with, for dashboard and audit linkage.
    ///   - entityID: The unique identifier of the entity instance, enabling precise audit and analytics tracking.
    ///   - awardedBy: Optional user ID who awarded the badge, supporting multi-user audit trails.
    /// - Returns: A new birthday badge instance ready for UI token display and audit logging.
    static func birthdayBadge(
        for entityType: String,
        entityID: UUID,
        awardedBy: UUID? = nil
    ) -> Badge {
        Badge(type: .birthday, entityType: entityType, entityID: entityID, awardedBy: awardedBy)
    }

    /// Helper to create a behavioral badge (good or challenging) for a given entity.
    ///
    /// Facilitates consistent behavior badge assignment with audit and UI token integration.
    ///
    /// - Parameters:
    ///   - isGoodBehavior: Flag indicating if behavior is good (true) or challenging (false), driving business logic and UI badges.
    ///   - entityType: The type of entity associated with the badge, for audit and dashboard correlation.
    ///   - entityID: The unique identifier of the entity instance, supporting detailed audit and analytics.
    ///   - notes: Optional notes providing context for behavior, enhancing audit and reporting clarity.
    ///   - awardedBy: Optional user ID who awarded the badge, enabling multi-user audit and accountability.
    /// - Returns: A new behavior badge instance ready for UI rendering and audit tracking.
    static func behaviorBadge(
        isGoodBehavior: Bool,
        for entityType: String,
        entityID: UUID,
        notes: String? = nil,
        awardedBy: UUID? = nil
    ) -> Badge {
        let badgeType: BadgeType = isGoodBehavior ? .behaviorGood : .behaviorChallenging
        return Badge(type: badgeType, notes: notes, entityType: entityType, entityID: entityID, awardedBy: awardedBy)
    }

    // MARK: - Future Expansion Notes

    /*
     To extend badge logic for additional business rules, complex assignment criteria, or enhanced UI token integration,
     all extensions must remain modular, tokenized, and fully auditable to maintain consistency across business logic,
     UI components, and audit trails.

     Consider adding methods or computed properties that support eligibility evaluation, expiration handling,
     tiered badge systems, or integration with SwiftData property wrappers and protocols.

     Maintaining this disciplined approach ensures badges remain a reliable source of truth for analytics,
     reporting, UI display, and business workflows.
     */
}
