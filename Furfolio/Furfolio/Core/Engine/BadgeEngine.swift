//
//  BadgeEngine.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  RetentionAlertEngine is now fully merged into BadgeEngine.swift and should be deleted.
//

import Foundation

/// Types of badges available in Furfolio.
/// Represents predefined categories of badges that can be awarded to dogs, owners, or appointments.
/// This engine covers all badge awarding, revoking, and analytics—including retention/risk alerts.
public enum BadgeType: String, CaseIterable, Identifiable {
    case birthday
    case topSpender
    case loyaltyStar
    case newClient
    case retentionRisk
    case behaviorGood
    case behaviorChallenging
    case needsVaccine
    case custom // Use this for admin-defined or app-updated badges

    public var id: String { rawValue }

    /// Emoji or system icon for each badge.
    public var icon: String {
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

    /// User-facing label.
    public var label: String {
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

    /// Description for tooltip or info view.
    public var description: String {
        switch self {
        case .birthday: return "This pet’s birthday is this month!"
        case .topSpender: return "Client is among your top spenders."
        case .loyaltyStar: return "This owner is a loyalty program star."
        case .newClient: return "Recently added to Furfolio."
        case .retentionRisk: return "This client hasn’t booked in a while—reach out!"
        case .behaviorGood: return "Pet consistently shows good behavior."
        case .behaviorChallenging: return "Extra care needed: challenging grooming behavior."
        case .needsVaccine: return "Pet has a vaccination due."
        case .custom: return "Custom badge."
        }
    }
}

/// Represents a badge awarded to a model (dog, owner, etc.).
/// Contains metadata about the badge type, award date, and optional notes.
public struct Badge: Identifiable, Hashable {
    public let id = UUID()
    public let type: BadgeType
    public let dateAwarded: Date
    public let notes: String?

    public init(type: BadgeType, dateAwarded: Date = Date(), notes: String? = nil) {
        self.type = type
        self.dateAwarded = dateAwarded
        self.notes = notes
    }
}

// MARK: - Preview / Mock Data Extension

public extension Badge {
    /// Provides sample badges for preview or testing purposes.
    static var previewBadges: [Badge] {
        [
            Badge(type: .birthday),
            Badge(type: .topSpender),
            Badge(type: .loyaltyStar),
            Badge(type: .newClient),
            Badge(type: .retentionRisk),
            Badge(type: .behaviorGood),
            Badge(type: .behaviorChallenging),
            Badge(type: .needsVaccine),
            Badge(type: .custom, notes: "Special event")
        ]
    }
}

// MARK: - BadgeEngine

/// BadgeEngine computes and manages awarding and revoking badges.
/// Thread-safe singleton class responsible for business logic related to awarding, revoking badges and analytics.
/// Supports injection of custom badge assignment rules and auditing hooks.
/// This engine fully covers all badge awarding, revoking, and analytics—including retention/risk alerts.
@MainActor
public final class BadgeEngine {

    // MARK: - Singleton Instance

    /// Shared singleton instance of BadgeEngine.
    public static let shared = BadgeEngine()

    private init() {}

    // MARK: - Types

    /// Type alias for custom badge assignment closure.
    /// Allows injecting custom business logic to award badges for a given model.
    public typealias CustomBadgeLogic<T> = (T) -> [Badge]

    /// Type alias for custom badge revocation closure.
    /// Allows injecting custom business logic to revoke badges from a given model.
    public typealias CustomBadgeRevocationLogic<T> = (T, Badge) -> Bool

    // MARK: - Properties

    /// Custom badge assignment logic for dogs.
    /// Can be set by business logic to extend or override default dog badge rules.
    public var customDogBadgeLogic: CustomBadgeLogic<Dog>?

    /// Custom badge assignment logic for owners.
    /// Can be set by business logic to extend or override default owner badge rules.
    public var customOwnerBadgeLogic: CustomBadgeLogic<DogOwner>?

    /// Custom badge assignment logic for appointments.
    /// Can be set by business logic to extend or override default appointment badge rules.
    public var customAppointmentBadgeLogic: CustomBadgeLogic<Appointment>?

    /// Closure called whenever a badge is awarded.
    /// Provides an audit hook for logging or analytics.
    public var badgeAwardedHandler: ((Badge, Any) -> Void)?

    /// Closure called whenever a badge is revoked.
    /// Provides an audit hook for logging or analytics.
    public var badgeRevokedHandler: ((Badge, Any) -> Void)?

    // MARK: - Badge Assignment Logic (Dog)

    /// Returns badges for a given dog.
    ///
    /// - Parameter dog: The dog model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// This method is modular, tokenized, and fully auditable. All logic and styling for badge determination
    /// should use the app’s business logic engines. All badge assignment or display must be accessible,
    /// localized, and maintainable.
    ///
    /// **Add new dog badge rules in this method or via `customDogBadgeLogic`.**
    public func badges(for dog: Dog) -> [Badge] {
        // TODO: Refactor to move all hardcoded logic to dedicated badge rule engines,
        // allow dynamic badge rule configuration, and support tokenized badge presentation via design system.
        var awarded: [Badge] = []

        // Birthday Badge:
        // Award if the dog's birthdate month matches the current month.
        if let birthday = dog.birthdate,
           Calendar.current.isDate(birthday, equalTo: Date(), toGranularity: .month) {
            let badge = Badge(type: .birthday)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Behavior Badges:
        // Award good behavior badge if any positive mood behavior logs exist.
        if let logs = dog.behaviorLogs,
           logs.contains(where: { $0.mood == .positive }) {
            let badge = Badge(type: .behaviorGood)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Award challenging behavior badge if any aggressive mood behavior logs exist.
        if let logs = dog.behaviorLogs,
           logs.contains(where: { $0.mood == .aggressive }) {
            let badge = Badge(type: .behaviorChallenging)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Needs Vaccine Badge:
        // Award if any vaccination record is due.
        if let vaccines = dog.vaccinationRecords,
           vaccines.contains(where: { $0.isDue }) {
            let badge = Badge(type: .needsVaccine)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Insert additional dog-specific badge assignment logic here...

        // Apply custom dog badge logic if provided.
        if let customLogic = customDogBadgeLogic {
            let customBadges = customLogic(dog)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: dog)
            }
        }

        return awarded
    }

    /// Returns badges for a given owner.
    ///
    /// - Parameter owner: The dog owner model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// **Add new owner badge rules in this method or via `customOwnerBadgeLogic`.**
    public func badges(for owner: DogOwner) -> [Badge] {
        var awarded: [Badge] = []

        // New Client Badge:
        // Award if the owner was added within the last 14 days.
        if let created = owner.dateAdded,
           Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 99 < 14 {
            let badge = Badge(type: .newClient)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Loyalty Star Badge:
        // Award if the owner has completed 10 or more appointments.
        if let count = owner.completedAppointments?.count,
           count >= 10 {
            let badge = Badge(type: .loyaltyStar)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Top Spender Badge:
        // Award if the total spent by the owner exceeds 500.
        if let total = owner.totalSpent,
           total > 500 {
            let badge = Badge(type: .topSpender)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Retention Risk Badge:
        // Award if the owner's last appointment was over 60 days ago.
        if let last = owner.lastAppointmentDate,
           Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0 > 60 {
            let badge = Badge(type: .retentionRisk)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Insert additional owner-specific badge assignment logic here...

        // Apply custom owner badge logic if provided.
        if let customLogic = customOwnerBadgeLogic {
            let customBadges = customLogic(owner)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: owner)
            }
        }

        return awarded
    }

    /// Returns badges for an appointment (example: behavioral).
    ///
    /// - Parameter appointment: The appointment model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// **Add new appointment badge rules in this method or via `customAppointmentBadgeLogic`.**
    public func badges(for appointment: Appointment) -> [Badge] {
        var awarded: [Badge] = []

        // Behavior Badge:
        // Award badges based on the mood recorded in the appointment's behavior log.
        if let behavior = appointment.behaviorLog?.mood {
            switch behavior {
            case .positive:
                let badge = Badge(type: .behaviorGood)
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            case .aggressive:
                let badge = Badge(type: .behaviorChallenging)
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            default:
                break
            }
        }

        // Insert additional appointment-specific badge assignment logic here...

        // Apply custom appointment badge logic if provided.
        if let customLogic = customAppointmentBadgeLogic {
            let customBadges = customLogic(appointment)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            }
        }

        return awarded
    }

    // MARK: - Badge Revocation Logic

    /// Revokes a badge from a given model (dog, owner, appointment).
    ///
    /// - Parameters:
    ///   - badge: The badge to revoke.
    ///   - model: The model instance (Dog, DogOwner, Appointment) from which to revoke the badge.
    ///
    /// This method enables centralized badge revocation, completing the full badge lifecycle management.
    public func revokeBadge(_ badge: Badge, from model: Any) {
        // Perform revocation logic here.
        // Since Badge instances are immutable and models are external,
        // actual removal should be handled by the caller's data store or model layer.
        // This method triggers the auditRevocation hook and posts notifications for analytics.

        auditRevocation(badge: badge, for: model)
    }

    // MARK: - Utility Methods

    /// Human-readable string summary for a list of badges.
    ///
    /// - Parameter badges: The badges to summarize.
    /// - Returns: A concatenated string of badge icons and labels.
    public func badgeSummary(_ badges: [Badge]) -> String {
        badges.map { "\($0.type.icon) \($0.type.label)" }.joined(separator: "   ")
    }

    // MARK: - Auditing

    /// Internal method to trigger auditing hooks when a badge is awarded.
    ///
    /// - Parameters:
    ///   - badge: The badge awarded.
    ///   - model: The model instance (Dog, DogOwner, Appointment) the badge was awarded for.
    private func audit(badge: Badge, for model: Any) {
        // Trigger the badge awarded handler closure if set.
        badgeAwardedHandler?(badge, model)

        // Post a notification for observers if needed.
        NotificationCenter.default.post(name: .badgeAwarded,
                                        object: self,
                                        userInfo: ["badge": badge, "model": model])
    }

    /// Internal method to trigger auditing hooks when a badge is revoked.
    ///
    /// - Parameters:
    ///   - badge: The badge revoked.
    ///   - model: The model instance (Dog, DogOwner, Appointment) the badge was revoked from.
    private func auditRevocation(badge: Badge, for model: Any) {
        // Trigger the badge revoked handler closure if set.
        badgeRevokedHandler?(badge, model)

        // Post a notification for observers if needed.
        NotificationCenter.default.post(name: .badgeRevoked,
                                        object: self,
                                        userInfo: ["badge": badge, "model": model])
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Notification posted when a badge is awarded.
    static let badgeAwarded = Notification.Name("BadgeEngineBadgeAwardedNotification")

    /// Notification posted when a badge is revoked.
    static let badgeRevoked = Notification.Name("BadgeEngineBadgeRevokedNotification")
}
