//
//  StaffMember.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - StaffMember (Modular, Tokenized, Auditable, Multi-Role Staff Model)

/**
 Represents a staff member within the Furfolio architecture.

 - Modular, auditable, and tokenized business entity supporting role-based access control, audit trails, staff analytics, compliance reporting, and UI integration.
 - Tracks core identity, contact info, role, employment, and business association.
 - Designed for multi-role, multi-user, RBAC (role-based access control), analytics, and business workflow scenarios.
 - All mutations should be logged for compliance and event/audit trails. Integrates with Trust Center, privacy controls, and dashboard analytics.
 */
@available(iOS 18.0, *)
@Model
final class StaffMember: Identifiable, ObservableObject {

    // MARK: - Identity

    /// Unique identifier for the staff member (audit/event correlation).
    @Attribute(.unique)
    var id: UUID

    /// Full name of the staff member (UI display, analytics, reporting).
    var name: String

    /// The role of the staff member within the business (RBAC, audit, workflow).
    var role: StaffRole

    // MARK: - Contact Info

    /// Email address of the staff member (compliance, notifications, UI, reporting).
    var email: String?

    /// Phone number of the staff member (compliance, notifications, UI, reporting).
    var phone: String?

    // MARK: - Employment

    /// Indicates whether the staff member is currently active (audit, business, analytics, workflow).
    var isActive: Bool

    /// The date the staff member joined the business (analytics, reporting, dashboard).
    var dateJoined: Date

    /// The last time the staff member was active (analytics, business workflow, audit).
    var lastActiveAt: Date?

    /// Indicates if the staff member is archived (soft-deleted) (audit, compliance, analytics).
    var isArchived: Bool

    // MARK: - Relationships

    /// The business to which the staff member belongs (audit, reporting, analytics, RBAC).
    @Relationship(deleteRule: .nullify, inverse: \Business.staff)
    var business: Business?

    // MARK: - Init

    /**
     Initializes a new StaffMember instance.
     - Parameters:
        - id: Unique identifier, defaults to a new UUID.
        - name: Full name of the staff member.
        - role: Role of the staff member (see StaffRole for business logic).
        - email: Optional email address.
        - phone: Optional phone number.
        - isActive: Active status, defaults to true.
        - dateJoined: Date the member joined, defaults to current date.
        - lastActiveAt: Last active date, optional.
        - isArchived: Soft-delete flag, defaults to false.
        - business: Associated business, optional.
     - All mutations/creations should trigger audit/event logging.
     */
    init(
        id: UUID = UUID(),
        name: String,
        role: StaffRole,
        email: String? = nil,
        phone: String? = nil,
        isActive: Bool = true,
        dateJoined: Date = Date(),
        lastActiveAt: Date? = nil,
        isArchived: Bool = false,
        business: Business? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.isActive = isActive
        self.dateJoined = dateJoined
        self.lastActiveAt = lastActiveAt
        self.isArchived = isArchived
        self.business = business
        // TODO: Audit logging - creation of staff member (compliance, analytics)
    }

    /// Returns true if the staff member holds an owner role (RBAC, workflow, UI badge logic).
    var isOwner: Bool {
        role == .owner
    }

    /// Returns true if the staff member is a groomer (analytics, business logic).
    var isGroomer: Bool {
        role == .groomer
    }

    /// Returns a display-friendly role title (localization, UI, reporting).
    var roleDisplayName: String {
        role.displayName
    }

    /// A sample StaffMember instance for SwiftUI previews or unit tests.
    /// - Demo/business/tokenized preview logic.
    static let sample = StaffMember(
        name: "Jane Doe",
        role: .groomer,
        email: "jane.doe@example.com",
        phone: "555-123-4567",
        isActive: true,
        dateJoined: Date(timeIntervalSinceNow: -86400 * 365),
        lastActiveAt: Date(),
        isArchived: false,
        business: nil
    )
}

// MARK: - StaffRole (RBAC, Tokenized, Auditable Staff Roles)

/**
 Defines the various roles a staff member can have within the business.

 - Modular, tokenized, and auditable RBAC enum.
 - All roles should have business, analytics, UI badge, and compliance rationale.
 */
enum StaffRole: String, Codable, Sendable, CaseIterable {
    case owner      // Business owner or principal (full access, critical audit trail)
    case groomer    // Groomer (service staff, key analytics/retention insights)
    case admin      // Administrative staff (manager-level, staff/event audit)
    case receptionist // Reception/front desk (customer-facing, scheduling)
    case assistant  // Assistant (support, entry-level, compliance training)
    case other      // Other/unspecified (catch-all, analytics flag)

    /// Returns a display/localized name for UI, badge, and analytics/reporting.
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .groomer: return "Groomer"
        case .admin: return "Admin"
        case .receptionist: return "Receptionist"
        case .assistant: return "Assistant"
        case .other: return "Other"
        }
    }
}
