//
//  Badge.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation

// MARK: - Analytics/Audit Protocol

public protocol BadgeAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullBadgeAnalyticsLogger: BadgeAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol BadgeTrustCenterDelegate {
    func permission(for action: String, badge: Badge, context: [String: Any]?) -> Bool
}
public struct NullBadgeTrustCenterDelegate: BadgeTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, badge: Badge, context: [String: Any]?) -> Bool { true }
}

// MARK: - BadgeType (unchanged, but always add to this enum ONLY)

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

    var id: String { rawValue }

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

// MARK: - Badge

struct Badge: Identifiable, Codable, Hashable, Equatable {
    // MARK: - Identifiers
    let id: UUID
    let type: BadgeType
    let dateAwarded: Date
    let notes: String?
    let entityType: String?
    let entityID: UUID?
    let awardedBy: UUID?
    let customIcon: String?
    let customLabel: String?

    // MARK: - Audit/Analytics/Trust Center Injectables
    static var analyticsLogger: BadgeAnalyticsLogger = NullBadgeAnalyticsLogger()
    static var trustCenterDelegate: BadgeTrustCenterDelegate = NullBadgeTrustCenterDelegate()

    // MARK: - Initialization

    init(
        type: BadgeType,
        dateAwarded: Date = Date(),
        notes: String? = nil,
        entityType: String? = nil,
        entityID: UUID? = nil,
        awardedBy: UUID? = nil,
        customIcon: String? = nil,
        customLabel: String? = nil,
        auditTag: String? = nil
    ) {
        let badge = Self._newInstance(
            type: type, dateAwarded: dateAwarded, notes: notes,
            entityType: entityType, entityID: entityID,
            awardedBy: awardedBy, customIcon: customIcon, customLabel: customLabel
        )

        // Trust Center permission check before creating (for restricted, role, or business rules)
        guard Self.trustCenterDelegate.permission(for: "create", badge: badge, context: ["auditTag": auditTag as Any]) else {
            Self.analyticsLogger.log(event: "badge_create_denied", info: [
                "type": type.rawValue,
                "entityType": entityType as Any,
                "entityID": entityID as Any,
                "awardedBy": awardedBy as Any,
                "auditTag": auditTag as Any
            ])
            fatalError("Badge creation denied by Trust Center.")
        }
        self = badge
        Self.analyticsLogger.log(event: "badge_created", info: [
            "type": type.rawValue,
            "entityType": entityType as Any,
            "entityID": entityID as Any,
            "awardedBy": awardedBy as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Internal initializer to build badge instance for Trust Center check.
    private static func _newInstance(
        type: BadgeType,
        dateAwarded: Date,
        notes: String?,
        entityType: String?,
        entityID: UUID?,
        awardedBy: UUID?,
        customIcon: String?,
        customLabel: String?
    ) -> Badge {
        Badge(
            id: UUID(),
            type: type,
            dateAwarded: dateAwarded,
            notes: notes,
            entityType: entityType,
            entityID: entityID,
            awardedBy: awardedBy,
            customIcon: customIcon,
            customLabel: customLabel
        )
    }

    // MARK: - Computed Properties

    var displayString: String {
        let iconToUse = customIcon ?? type.icon
        let labelToUse = customLabel ?? type.label
        return "\(iconToUse) \(labelToUse)"
    }

    /// Accessibility: Descriptive label for VoiceOver and UI.
    var accessibilityLabel: String {
        "\(customLabel ?? type.label) badge, \(type.description)"
    }

    // MARK: - Static Helpers

    static func birthdayBadge(
        for entityType: String,
        entityID: UUID,
        awardedBy: UUID? = nil,
        auditTag: String? = nil
    ) -> Badge {
        Badge(type: .birthday, entityType: entityType, entityID: entityID, awardedBy: awardedBy, auditTag: auditTag)
    }

    static func behaviorBadge(
        isGoodBehavior: Bool,
        for entityType: String,
        entityID: UUID,
        notes: String? = nil,
        awardedBy: UUID? = nil,
        auditTag: String? = nil
    ) -> Badge {
        let badgeType: BadgeType = isGoodBehavior ? .behaviorGood : .behaviorChallenging
        return Badge(type: badgeType, notes: notes, entityType: entityType, entityID: entityID, awardedBy: awardedBy, auditTag: auditTag)
    }

    // MARK: - Auditable Badge Mutations (for future)

    /// Example mutation: revoke badge (logs, Trust Center–checked)
    func revoke(by user: UUID?, auditTag: String? = nil) -> Badge? {
        guard Self.trustCenterDelegate.permission(for: "revoke", badge: self, context: [
            "revokedBy": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "badge_revoke_denied", info: [
                "id": id.uuidString,
                "type": type.rawValue,
                "revokedBy": user as Any,
                "auditTag": auditTag as Any
            ])
            return nil
        }
        Self.analyticsLogger.log(event: "badge_revoked", info: [
            "id": id.uuidString,
            "type": type.rawValue,
            "revokedBy": user as Any,
            "auditTag": auditTag as Any
        ])
        // App logic may "soft delete" or archive badge; this returns nil as example.
        return nil
    }
}
