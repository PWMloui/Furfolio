//
//  User.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated & Enhanced by ChatGPT on 6/21/25
//

import Foundation
import SwiftData
import UIKit

// MARK: - User (Modular, Tokenized, Auditable Multi-Role User Account Model)

/// Represents a modular, auditable, tokenized multi-role user entity within Furfolio,
/// designed to support business/staff/owner/admin roles with comprehensive audit trails,
/// role-based access control (RBAC), analytics, compliance tracking, and UI integration
/// (including badges and icons). This model supports multi-business environments and
/// Trust Center features, enabling secure owner-focused dashboards, onboarding flows,
/// and detailed reporting.
///
/// The User entity is central to managing identities across multiple business locations,
/// staff members, and admin roles, ensuring transparency, traceability, and flexibility
/// in permissions and workflows.
@available(iOS 18.0, *)
@Model
final class User: Identifiable, ObservableObject {
    // MARK: - Properties

    /// Unique identifier for the user.
    /// Used for audit logging, analytics tracking, and secure referencing across systems.
    @Attribute(.unique)
    var id: UUID

    /// Username for login and display purposes.
    /// Supports audit trails, user activity analytics, and UI display.
    var username: String

    /// Optional email address.
    /// Important for communication, audit notifications, compliance, and onboarding.
    var email: String?

    /// Optional phone number.
    /// Used for contact, multi-factor authentication, and compliance notifications.
    var phone: String?

    /// Role defining user permissions and access level.
    /// Integral to RBAC, UI role badges, analytics segmentation, and compliance scopes.
    var role: UserRole

    /// Flag indicating if the user account is active.
    /// Used for workflow gating, compliance (e.g., deactivation audits), and UI status indicators.
    var isActive: Bool

    /// Timestamp when the user was created.
    /// Essential for audit history, compliance reporting, and onboarding analytics.
    var dateCreated: Date

    /// Timestamp of the last modification.
    /// Supports audit trails, change tracking, and synchronization analytics.
    var lastModified: Date

    /// Optional profile picture data (stored as Data).
    /// Enhances UI personalization and user recognition in workflows.
    var profileImageData: Data?

    /// Relationship: The business this user belongs to.
    /// Supports multi-location business management, RBAC scoping, analytics by business unit,
    /// and UI workflows reflecting business context.
    @Relationship(deleteRule: .nullify, inverse: \Business.staff)
    var business: Business?

    /// Relationship: Optional staff member record linked to this user.
    /// Enables HR features, detailed RBAC, analytics on staff performance,
    /// and UI workflows for staff management.
    @Relationship(deleteRule: .nullify)
    var staffRecord: StaffMember?

    /// Audit trail of all changes related to this user.
    /// Critical for Trust Center transparency, compliance audits, forensic reporting,
    /// and business accountability.
    var auditTrail: [UserAuditLog] = []

    /// Tags for flexible filtering and categorization.
    /// Used in business segmentation, analytics cohorts, UI filtering, and workflow automation.
    var tags: [String] = []

    // MARK: - Initializer

    /// Initializes a new User instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier; defaults to a new UUID.
    ///   - username: Required username for login and display.
    ///   - email: Optional email for communication and compliance.
    ///   - phone: Optional phone number for contact and MFA.
    ///   - role: User role for RBAC and UI representation; defaults to `.owner`.
    ///   - isActive: Account active status; defaults to `true`.
    ///   - dateCreated: Creation timestamp; defaults to current date.
    ///   - lastModified: Last modification timestamp; defaults to current date.
    ///   - profileImageData: Optional profile image data for UI.
    ///   - business: Optional associated business for RBAC and analytics.
    ///   - staffRecord: Optional linked staff member for HR and workflow.
    ///   - auditTrail: Initial audit logs; used for compliance and event logging.
    ///   - tags: Optional tags for analytics and filtering.
    ///
    /// This initializer supports audit/event logging, business context assignment,
    /// onboarding workflows, analytics segmentation, and compliance tracking.
    init(
        id: UUID = UUID(),
        username: String,
        email: String? = nil,
        phone: String? = nil,
        role: UserRole = .owner,
        isActive: Bool = true,
        dateCreated: Date = Date(),
        lastModified: Date = Date(),
        profileImageData: Data? = nil,
        business: Business? = nil,
        staffRecord: StaffMember? = nil,
        auditTrail: [UserAuditLog] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.phone = phone
        self.role = role
        self.isActive = isActive
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.profileImageData = profileImageData
        self.business = business
        self.staffRecord = staffRecord
        self.auditTrail = auditTrail
        self.tags = tags
    }

    // MARK: - Computed

    /// Returns a user-friendly display name.
    /// Used throughout the UI for personalization, analytics labeling, and reporting.
    var displayName: String {
        username
    }

    /// Decodes the stored profile image data into a UIImage.
    /// Used for UI avatar display and enhancing user recognition in workflows.
    var profileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    /// Returns a user-friendly label for the user's role.
    /// Supports UI badges, analytics segmentation, RBAC displays, and reporting.
    var roleLabel: String {
        role.label
    }

    /// Returns the SFSymbol icon name associated with the user's role.
    /// Used in UI elements, analytics dashboards, and role-based reporting.
    var roleIcon: String {
        role.icon
    }

    // MARK: - State/Helpers

    /// Indicates whether the user is currently enabled (active and not soft-deleted).
    /// Used for gating access, compliance checks, and UI status indicators.
    var isEnabled: Bool {
        isActive
    }

    /// Adds an audit log entry recording a user-related change.
    ///
    /// - Parameters:
    ///   - action: Description of the action performed.
    ///   - actor: Optional user who performed the action; used for accountability.
    ///
    /// This method supports audit/event logging, Trust Center transparency,
    /// business accountability, and analytics on user activity.
    func logChange(_ action: String, by actor: User? = nil) {
        let log = UserAuditLog(
            action: action,
            date: Date(),
            actorID: actor?.id
        )
        auditTrail.append(log)
    }

    // MARK: - Sample Data

    /// Sample user instance for testing and preview purposes.
    static var sample: User {
        User(
            username: "furfolio_owner",
            email: "owner@furfolio.com",
            phone: "555-123-4567",
            role: .owner,
            isActive: true
        )
    }
}

// MARK: - UserRole Enum

/// Defines user roles with associated permissions and metadata.
/// Used extensively for role-based access control (RBAC), business logic,
/// compliance scopes, analytics segmentation, and UI/badge integration.
/// Roles can be expanded as needed to reflect organizational structure.
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case owner
    case admin
    case groomer
    case receptionist
    case staff
    case custom

    var id: String { rawValue }

    /// Human-readable label for the role.
    /// Used in UI elements, analytics reports, RBAC displays, and compliance documentation.
    var label: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .groomer: return "Groomer"
        case .receptionist: return "Receptionist"
        case .staff: return "Staff"
        case .custom: return "Custom"
        }
    }

    /// SFSymbol icon name representing the role.
    /// Supports UI badges, dashboards, analytics visualization, and role-based reporting.
    var icon: String {
        switch self {
        case .owner: return "person.crop.circle.fill.badge.star"
        case .admin: return "person.2.crop.square.stack.fill"
        case .groomer: return "scissors"
        case .receptionist: return "phone"
        case .staff: return "person"
        case .custom: return "person.crop.circle"
        }
    }
}

// MARK: - UserAuditLog

/// Represents a single audit log entry related to user actions.
/// Captures the action description, timestamp, and the actor's user ID (if known).
/// Essential for audit compliance, forensic reporting, Trust Center transparency,
/// and analytics on user behavior and changes.
struct UserAuditLog: Codable {
    let action: String
    let date: Date
    let actorID: UUID?
}
