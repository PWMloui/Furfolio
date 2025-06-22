//
//  DogOwner.swift
//  Furfolio
//
//  Enhanced, unified, and ready for multi-user/offline-first/analytics.
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - DogOwner (Modular, Tokenized, Auditable, Multi-Role Client/Owner Model)

/// Represents a modular, auditable, tokenized multi-role client/owner entity within the Furfolio system.
/// This class supports comprehensive business analytics, compliance adherence, detailed audit trails,
/// loyalty and retention logic, badge integration, and UI design system compatibility.
/// It is designed for scalable, owner-focused dashboards and multi-user scenarios, enabling robust
/// client management, role-based access control, and offline-first capabilities.
@Model
final class DogOwner: Identifiable, ObservableObject {
    @Attribute(.unique)
    var id: UUID

    /// The primary name of the owner/client.
    /// Used for display in UI, search, and audit logs.
    /// Essential for business workflows and client identification.
    @Published
    var ownerName: String

    /// Contact email address.
    /// Used for communication, notifications, and audit trail contact points.
    @Published
    var email: String?

    /// Physical address of the owner.
    /// Supports compliance requirements for location-based regulations and mailing.
    @Published
    var address: String?

    /// Primary phone number.
    /// Critical for direct client contact, emergency workflows, and multi-channel communication.
    @Published
    var phone: String?

    /// Backup or emergency contact information.
    /// Ensures compliance and safety workflows by providing alternate contact options.
    @Published
    var emergencyContact: String?

    /// Additional notes or comments about the owner.
    /// Supports workflow customization, audit context, and client-specific instructions.
    @Published
    var notes: String?

    /// Indicates if the owner is currently active.
    /// Drives business logic for active client filtering, analytics segmentation, and UI visibility.
    @Published
    var isActive: Bool

    /// Role of the user for access control purposes. Defaults to "Owner".
    /// Enables multi-role support, RBAC compliance, and tailored UI/feature access.
    @Published
    var role: String

    /// Preferred contact method, e.g., "phone", "email", "sms".
    /// Guides communication workflows and analytics on contact preferences.
    @Published
    var preferredContact: String?

    /// Preferred language of the owner for multi-language support.
    /// Supports UI localization, compliance with language laws, and better client experience.
    @Published
    var preferredLanguage: String?

    /// Date when this owner record was added.
    /// Critical for audit trails, compliance timelines, and business analytics.
    @Published
    var dateAdded: Date

    /// Date when this owner record was last modified.
    /// Used for audit logs, data freshness indicators, and compliance reporting.
    @Published
    var lastModified: Date

    /// Identifier for the user who last modified this record (for audit trail).
    /// Supports multi-user audit trails, accountability, and compliance.
    @Published
    var lastModifiedBy: String?

    /// Simple audit log capturing change descriptions and timestamps.
    /// Enables detailed event history for compliance, troubleshooting, and analytics.
    @Published
    var auditLog: [String]

    // MARK: - Relationships

    /// All dogs belonging to this owner.
    /// Supports business logic for pet management, analytics on pet demographics,
    /// and UI display of owner-pet relationships.
    @Relationship(deleteRule: .cascade, inverse: \Dog.owner)
    @Published
    var dogs: [Dog]

    /// All appointments linked to this owner.
    /// Enables scheduling workflows, retention analytics, and UI calendar integration.
    @Relationship(deleteRule: .cascade, inverse: \Appointment.owner)
    @Published
    var appointments: [Appointment]

    /// All charges billed to this owner.
    /// Supports financial analytics, billing workflows, and compliance with payment records.
    @Relationship(deleteRule: .cascade, inverse: \Charge.owner)
    @Published
    var charges: [Charge]

    /// List of badges/tags for loyalty, retention, behavior, etc.
    /// Drives loyalty program logic, client segmentation, and UI badge displays.
    @Published
    var badgeTypes: [String]

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        ownerName: String,
        email: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        emergencyContact: String? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        role: String = "Owner",
        preferredContact: String? = nil,
        preferredLanguage: String? = nil,
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        lastModifiedBy: String? = nil,
        auditLog: [String] = [],
        dogs: [Dog] = [],
        appointments: [Appointment] = [],
        charges: [Charge] = [],
        badgeTypes: [String] = []
    ) {
        self.id = id
        self.ownerName = ownerName
        self.email = email
        self.address = address
        self.phone = phone
        self.emergencyContact = emergencyContact
        self.notes = notes
        self.isActive = isActive
        self.role = role
        self.preferredContact = preferredContact
        self.preferredLanguage = preferredLanguage
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
        self.dogs = dogs
        self.appointments = appointments
        self.charges = charges
        self.badgeTypes = badgeTypes
    }

    // MARK: - Computed Properties & Helpers

    /// Returns the total amount spent by this owner across all charges.
    /// Used for business analytics, loyalty tier calculations, and financial reporting dashboards.
    var totalSpent: Double {
        charges.reduce(0) { $0 + $1.amount }
    }

    /// Returns all appointments with a completed status.
    /// Supports retention analytics, compliance tracking, and UI filtering of appointment history.
    var completedAppointments: [Appointment] {
        appointments.filter { $0.status == .completed }
    }

    /// Returns the date of the most recent appointment, if any.
    /// Critical for retention risk analysis, compliance follow-ups, and dashboard recency indicators.
    var lastAppointmentDate: Date? {
        appointments.sorted(by: { $0.date > $1.date }).first?.date
    }

    /// Indicates if the owner has any dogs currently marked as active.
    /// Used for business segmentation, active client filtering, and UI status displays.
    var hasActiveDogs: Bool {
        dogs.contains(where: { $0.isActive })
    }

    /// Returns the display name for UI, falling back to "Unnamed Owner" if empty.
    /// Improves UI consistency and user experience in client lists and dashboards.
    var displayName: String {
        ownerName.isEmpty ? "Unnamed Owner" : ownerName
    }

    /// Returns true if the last appointment was more than 60 days ago, indicating retention risk.
    /// Supports proactive client retention workflows, risk analytics, and targeted marketing.
    var isRetentionRisk: Bool {
        guard let lastDate = lastAppointmentDate else { return true }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0 > 60
    }

    /// Returns a loyalty tier string based on total amount spent.
    /// Drives loyalty program logic, UI badge assignments, and business segmentation.
    var loyaltyTier: String {
        switch totalSpent {
        case 0..<500:
            return "Bronze"
        case 500..<2000:
            return "Silver"
        case 2000..<5000:
            return "Gold"
        default:
            return "Platinum"
        }
    }

    // MARK: - Utility Methods

    /// Adds an audit log entry with a timestamp.
    /// Essential for detailed audit/event logging, compliance records, and analytics on data changes.
    /// Also impacts workflow transparency and troubleshooting.
    func addAuditLogEntry(_ entry: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(timestamp)] \(entry)")
        lastModified = Date()
    }

    /// Updates the last modified date and user.
    /// Supports multi-user audit trails, accountability, and compliance with modification tracking.
    func updateModification(user: String?) {
        lastModified = Date()
        lastModifiedBy = user
    }

    // MARK: - Static Properties

    /// A preview instance for SwiftUI previews and development/testing.
    /// Demonstrates demo/business logic, tokenized design intent, and typical data usage scenarios.
    static let preview = DogOwner(
        ownerName: "Jane Doe",
        email: "jane.doe@example.com",
        phone: "555-1234",
        emergencyContact: "John Doe - 555-5678",
        notes: "Prefers morning appointments.",
        isActive: true,
        role: "Owner",
        preferredContact: "email",
        preferredLanguage: "en",
        lastModifiedBy: "admin",
        auditLog: ["Created record on \(Date())"],
        dogs: [],
        appointments: [],
        charges: [],
        badgeTypes: ["Loyal", "Friendly"]
    )
}
