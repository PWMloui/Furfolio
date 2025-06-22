//
//  Contact.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - Contact (Modular, Tokenized, Auditable, Multi-Role Contact Model)

/// Represents a modular, auditable, and tokenized contact entity designed for reuse across multiple roles including business, owner, staff, and emergency contacts.
/// This class supports comprehensive audit trails, analytics tracking, compliance requirements, and seamless integration with UI design systems.
/// It centralizes contact information, relationship context, and metadata to facilitate business logic and analytics insights while maintaining data integrity and traceability.
@MainActor
@Model
final class Contact: Identifiable, ObservableObject, Hashable {

    // MARK: - Properties
    
    /// Unique identifier for the contact entity.
    /// Used for audit logging, analytics correlation, and business entity tracking.
    @Attribute(.unique)
    var id: UUID = UUID()

    /// The street address associated with the contact.
    /// Important for business location analytics and UI address display formatting.
    var address: String?
    
    /// The city component of the contact's address.
    /// Useful for geographic analytics and regional business logic.
    var city: String?
    
    /// The country component of the contact's address.
    /// Supports compliance with location-based regulations and internationalization analytics.
    var country: String?
    
    /// The email address for the contact.
    /// Used for communication, audit trails, and analytics on contact engagement.
    var email: String?
    
    /// Name of the emergency contact person related to this contact.
    /// Critical for emergency response workflows, audit records, and risk management.
    var emergencyContactName: String?
    
    /// Phone number of the emergency contact.
    /// Supports emergency communication channels and compliance documentation.
    var emergencyContactPhone: String?
    
    /// The first name of the contact.
    /// Used for personalized communication, UI display, and analytics segmentation.
    var firstName: String?
    
    /// The last name of the contact.
    /// Complements firstName for full identification and business reporting.
    var lastName: String?
    
    /// Additional notes related to the contact.
    /// Useful for audit annotations, business context, and internal communication.
    var notes: String?
    
    /// Primary phone number for the contact.
    /// Supports communication workflows, audit logging of contact attempts, and UI display.
    var phone: String?
    
    /// Describes the contact's relationship role (e.g., Owner, Staff, Vet).
    /// Enables role-based analytics, permissioning, and business logic branching.
    var relationship: String? // e.g., Owner, Staff, Vet, etc.
    
    /// The state or province component of the contact's address.
    /// Supports regional compliance and geographic analytics.
    var state: String?
    
    /// Postal or ZIP code for the contact's address.
    /// Important for location validation, compliance, and business reporting.
    var zip: String?
    
    /// Timestamp indicating when the contact was created.
    /// Essential for audit trails, lifecycle analytics, and compliance record keeping.
    var createdAt: Date = Date()
    
    /// Timestamp indicating the last modification date.
    /// Supports audit logging, change tracking, and synchronization analytics.
    var lastModified: Date = Date()

    // MARK: - Relationships
    
    /// Link to owner/staff/dog if needed via inverse relationships.
    /// This separation allows clean management of relationships externally.
    
    // MARK: - Initialization
    
    /// Initializes a new Contact instance with optional parameters.
    /// - Parameters:
    ///   - id: Unique identifier for audit and business tracking.
    ///   - firstName: Contact's first name for personalization and analytics.
    ///   - lastName: Contact's last name for identification and reporting.
    ///   - phone: Primary phone number for communication and audit.
    ///   - email: Contact email, trimmed and normalized for consistency.
    ///   - address: Street address for location analytics and UI.
    ///   - city: City component for geographic segmentation.
    ///   - state: State or province for compliance and analytics.
    ///   - zip: Postal code for validation and reporting.
    ///   - country: Country for internationalization and compliance.
    ///   - emergencyContactName: Name of emergency contact for safety and audit.
    ///   - emergencyContactPhone: Phone of emergency contact for quick reach.
    ///   - relationship: Role descriptor for business logic and analytics.
    ///   - notes: Additional notes for audit and business context.
    ///   - createdAt: Creation timestamp for audit trail.
    ///   - lastModified: Last updated timestamp for change tracking.
    init(
        id: UUID = UUID(),
        firstName: String? = nil,
        lastName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        country: String? = nil,
        emergencyContactName: String? = nil,
        emergencyContactPhone: String? = nil,
        relationship: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.address = address
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.relationship = relationship
        self.notes = notes
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    // MARK: - Computed Properties
    
    /// Full name combining first and last names, trimmed of extra spaces.
    /// Used for UI display, personalized communication, and analytics segmentation.
    var fullName: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Formatted address combining address components separated by commas.
    /// Supports UI display consistency, location analytics, and reporting.
    var formattedAddress: String {
        [address, city, state, zip, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
    
    /// Indicates if emergency contact information is available.
    /// Important for risk management workflows, audit compliance, and emergency readiness.
    var isEmergencyContactAvailable: Bool {
        guard let name = emergencyContactName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let phone = emergencyContactPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Methods
    
    /// Updates the lastModified timestamp to the current date.
    /// Also logs an audit event to maintain a traceable change history.
    /// This method supports audit compliance and analytics on data modifications.
    func updateLastModified() {
        lastModified = Date()
        logAuditEvent(event: "Contact updated")
    }
    
    /// Stub method to log audit events for future audit trail implementation.
    /// Integrates with analytics and compliance systems to record significant events.
    /// - Parameter event: Description of the event to log, aiding traceability and monitoring.
    func logAuditEvent(event: String) {
        // Placeholder for audit logging implementation.
        // Could integrate with analytics or audit trail system.
    }
    
    // MARK: - Hashable Conformance
    
    /// Determines equality based on unique identifier for consistent business logic and collections.
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes the unique identifier to support use in sets and dictionaries.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Sample Data
    
    /// Sample contact instance for demos, previews, and business testing.
    /// Provides a realistic example to support UI development, analytics validation, and business scenario simulations.
    static let sample = Contact(
        firstName: "Jane",
        lastName: "Doe",
        phone: "555-123-4567",
        email: "jane.doe@example.com",
        address: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip: "62704",
        country: "USA",
        emergencyContactName: "John Doe",
        emergencyContactPhone: "555-987-6543",
        relationship: "Owner",
        notes: "Prefers email contact."
    )
}

// MARK: - Contact Extensions

extension Contact {
    
    /// Returns a formatted phone number string suitable for display.
    /// Enhances UI readability and supports business communication standards.
    var formattedPhone: String? {
        guard let phone = phone else { return nil }
        // Simple formatting: remove non-digit characters and format as (XXX) XXX-XXXX if possible.
        let digits = phone.filter { $0.isNumber }
        switch digits.count {
        case 10:
            let areaCode = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let lineNumber = digits.suffix(4)
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        default:
            return phone
        }
    }
    
    /// Returns a formatted email string suitable for display.
    /// Normalizes email for consistent analytics and UI presentation.
    var formattedEmail: String? {
        email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
