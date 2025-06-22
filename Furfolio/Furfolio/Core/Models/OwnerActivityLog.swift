//
//  OwnerActivityLog.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - OwnerActivityLog (Modular, Tokenized, Auditable Owner Activity Log)

/// Represents a modular, auditable, and tokenized owner activity log entity designed to support comprehensive analytics, compliance requirements, Trust Center integration, multi-user audit trails, dashboard and event reporting, as well as design system integration including badges, icons, and criticality markings.
/// This entity captures detailed activity metadata to enable business workflows, audit compliance, and user interface consistency across platforms.
@Model
final class OwnerActivityLog: Identifiable, ObservableObject, Hashable {
    // MARK: - Properties
    
    /// Unique identifier for this log entry.
    /// Serves as the primary key for audit integrity and cross-system correlation.
    @Attribute(.unique)
    var id: UUID = UUID()

    /// Audit or traceable identifier for external system correlation.
    /// Enables integration with third-party audit, logging, and compliance systems, ensuring traceability across distributed environments.
    var auditID: String = UUID().uuidString

    /// The owner this activity log is associated with.
    /// Links this activity to a specific `DogOwner` for business logic, analytics segmentation, and audit trail completeness.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.activityLogs)
    var owner: DogOwner?

    /// The timestamp when the activity occurred.
    /// Critical for audit timelines, compliance reporting, analytics event sequencing, and UI chronological display.
    var date: Date = Date()

    /// The type of owner-related activity.
    /// Drives business logic categorization, analytics event grouping, UI token selection, and audit classification.
    var type: OwnerActivityType = .custom

    /// Human-readable summary of the activity, localized for UI display.
    /// Provides concise context for users, audit reviewers, and analytic dashboards with localization support.
    var summary: String = ""

    /// Optional detailed information about the activity (e.g., notes, diffs).
    /// Supports deeper audit investigation, compliance evidence, and enriched analytics.
    var details: String?

    /// Optional identifier referencing a related entity (e.g., appointment, charge, dog).
    /// Enables linking to associated domain objects for cross-entity analytics, workflows, and audit correlation.
    var relatedEntityID: String?

    /// Optional string describing the type of the related entity.
    /// Facilitates filtering, reporting, and UI contextualization of related activities.
    var relatedEntityType: String?

    /// The user or staff who performed the action, if applicable.
    /// Supports multi-user audit trails, compliance accountability, and workflow ownership.
    var user: String?

    /// Indicates whether this activity is critical for Trust Center or business audits.
    /// Flags entries that require elevated visibility, compliance review, or special handling in dashboards.
    var isCritical: Bool = false

    // MARK: - Computed Properties

    /// Descriptive display string combining icon, summary, and formatted date.
    /// Utilized for consistent UI/UX presentation, analytics labeling, dashboard event reporting, and token/badge rendering in design systems.
    var displayString: String {
        let icon = type.icon
        let formattedDate = Self.dateFormatter.string(from: date)
        return "\(icon) \(summary) (\(formattedDate))"
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        auditID: String = UUID().uuidString,
        owner: DogOwner? = nil,
        date: Date = Date(),
        type: OwnerActivityType = .custom,
        summary: String = "",
        details: String? = nil,
        relatedEntityID: String? = nil,
        relatedEntityType: String? = nil,
        user: String? = nil,
        isCritical: Bool = false
    ) {
        self.id = id
        self.auditID = auditID
        self.owner = owner
        self.date = date
        self.type = type
        self.summary = summary
        self.details = details
        self.relatedEntityID = relatedEntityID
        self.relatedEntityType = relatedEntityType
        self.user = user
        self.isCritical = isCritical
    }

    // MARK: - Hashable

    static func == (lhs: OwnerActivityLog, rhs: OwnerActivityLog) -> Bool {
        lhs.id == rhs.id && lhs.auditID == rhs.auditID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(auditID)
    }

    // MARK: - Static Date Formatter

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    // MARK: - Builder-style Static Factory Method

    /// Builder to facilitate creation of `OwnerActivityLog` instances with chainable configuration.
    /// Supports audit trail completeness, analytics event construction, localization, and workflow clarity.
    class Builder {
        private var id: UUID = UUID()
        private var auditID: String = UUID().uuidString
        private var owner: DogOwner?
        private var date: Date = Date()
        private var type: OwnerActivityType = .custom
        private var summary: String = ""
        private var details: String?
        private var relatedEntityID: String?
        private var relatedEntityType: String?
        private var user: String?
        private var isCritical: Bool = false

        /// Sets the owner associated with this activity log.
        /// - Parameter owner: The `DogOwner` instance to link.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setOwner(_ owner: DogOwner?) -> Builder {
            self.owner = owner
            return self
        }

        /// Sets the date/time when the activity occurred.
        /// - Parameter date: The `Date` of the activity.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setDate(_ date: Date) -> Builder {
            self.date = date
            return self
        }

        /// Sets the type of owner activity.
        /// - Parameter type: The `OwnerActivityType` representing the activity category.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setType(_ type: OwnerActivityType) -> Builder {
            self.type = type
            return self
        }

        /// Sets the localized summary string with format arguments.
        /// - Parameters:
        ///   - summaryKey: The localization key for the summary.
        ///   - args: Format arguments for localization.
        /// - Returns: The builder instance for chaining.
        /// This supports localization for UI display, analytics labeling, and audit clarity.
        @discardableResult
        func setSummary(_ summaryKey: String, _ args: CVarArg...) -> Builder {
            let localized = String(format: NSLocalizedString(summaryKey, comment: ""), arguments: args)
            self.summary = localized
            return self
        }

        /// Sets optional detailed information about the activity.
        /// - Parameter details: Additional textual details or diffs.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setDetails(_ details: String?) -> Builder {
            self.details = details
            return self
        }

        /// Sets an optional identifier for a related entity.
        /// - Parameter id: The related entity's identifier.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setRelatedEntityID(_ id: String?) -> Builder {
            self.relatedEntityID = id
            return self
        }

        /// Sets an optional string describing the related entity type.
        /// - Parameter type: The related entity type.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setRelatedEntityType(_ type: String?) -> Builder {
            self.relatedEntityType = type
            return self
        }

        /// Sets the user or staff who performed the action.
        /// - Parameter user: The username or identifier.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setUser(_ user: String?) -> Builder {
            self.user = user
            return self
        }

        /// Flags whether this activity is critical for audits or Trust Center.
        /// - Parameter critical: Boolean indicating criticality.
        /// - Returns: The builder instance for chaining.
        @discardableResult
        func setIsCritical(_ critical: Bool) -> Builder {
            self.isCritical = critical
            return self
        }

        /// Builds the configured `OwnerActivityLog` instance.
        /// - Returns: A fully constructed `OwnerActivityLog`.
        func build() -> OwnerActivityLog {
            OwnerActivityLog(
                id: id,
                auditID: auditID,
                owner: owner,
                date: date,
                type: type,
                summary: summary,
                details: details,
                relatedEntityID: relatedEntityID,
                relatedEntityType: relatedEntityType,
                user: user,
                isCritical: isCritical
            )
        }
    }
}

/// Enum for owner-related activity log types.
/// Provides localized display names and SF Symbol icons for UI consistency, audit categorization, analytics event grouping, and business logic triggers.
/// Designed to integrate with UI tokens, badges, and event reporting systems.
enum OwnerActivityType: String, Codable, CaseIterable, Identifiable, Hashable {
    case profileCreated
    case profileEdited
    case appointmentBooked
    case appointmentCancelled
    case appointmentCompleted
    case chargeAdded
    case chargePaid
    case retentionStatusChanged
    case loyaltyReward
    case noteAdded
    case custom

    var id: String { rawValue }

    /// Localized display name used for UI labels, badges, analytics event naming, and business reporting.
    var displayName: String {
        switch self {
        case .profileCreated: return NSLocalizedString("Profile Created", comment: "Owner activity type")
        case .profileEdited: return NSLocalizedString("Profile Edited", comment: "Owner activity type")
        case .appointmentBooked: return NSLocalizedString("Appointment Booked", comment: "Owner activity type")
        case .appointmentCancelled: return NSLocalizedString("Appointment Cancelled", comment: "Owner activity type")
        case .appointmentCompleted: return NSLocalizedString("Appointment Completed", comment: "Owner activity type")
        case .chargeAdded: return NSLocalizedString("Charge Added", comment: "Owner activity type")
        case .chargePaid: return NSLocalizedString("Charge Paid", comment: "Owner activity type")
        case .retentionStatusChanged: return NSLocalizedString("Retention Status Changed", comment: "Owner activity type")
        case .loyaltyReward: return NSLocalizedString("Loyalty Reward", comment: "Owner activity type")
        case .noteAdded: return NSLocalizedString("Note Added", comment: "Owner activity type")
        case .custom: return NSLocalizedString("Other", comment: "Owner activity type")
        }
    }

    /// SF Symbol icon name used for UI tokens, badges, audit visual cues, and analytics dashboards.
    var icon: String {
        switch self {
        case .profileCreated: return "person.crop.circle.badge.plus"
        case .profileEdited: return "pencil.circle"
        case .appointmentBooked: return "calendar.badge.plus"
        case .appointmentCancelled: return "calendar.badge.minus"
        case .appointmentCompleted: return "checkmark.circle"
        case .chargeAdded: return "creditcard"
        case .chargePaid: return "checkmark.seal"
        case .retentionStatusChanged: return "arrow.2.squarepath"
        case .loyaltyReward: return "star.circle"
        case .noteAdded: return "note.text"
        case .custom: return "ellipsis.circle"
        }
    }
}
