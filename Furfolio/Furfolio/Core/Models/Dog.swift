//
//  Dog.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated & enhanced for architectural unification, business intelligence, and UX.
//  Author: senpai + ChatGPT
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Dog (Modular, Tokenized, Auditable Business Pet Entity)

/// Represents a modular, auditable, tokenized pet entity (dog) in the Furfolio system.
/// This class supports comprehensive business analytics, compliance auditing, badge/status logic,
/// and seamless UI integration including badges, icons, and color coding.
/// Designed to unify pet data for workflows, reporting, and user experience enhancements.
@Model
final class Dog: Identifiable, ObservableObject {
    // MARK: - Core Properties

    /// Unique identifier for audit trails, data integrity, and tokenization across systems.
    @Attribute(.unique)
    @Published
    var id: UUID

    /// Dog's name, used in UI display, search, and business workflows.
    @Attribute(.required)
    @Published
    var name: String

    /// Optional breed information for analytics, breed-specific care recommendations, and UI badges.
    @Published
    var breed: String?

    /// Birthdate used for age calculation, birthday badges, and lifecycle analytics.
    @Published
    var birthdate: Date?

    /// Color attribute supports UI customization and breed/color-based analytics.
    @Published
    var color: String?

    /// Gender information for demographic analytics and personalized care workflows.
    @Published
    var gender: String?

    /// Notes field for freeform audit comments, behavior observations, or medical details.
    @Published
    var notes: String?

    /// Active status flag used in business logic, UI status indicators, and retention analysis.
    @Published
    var isActive: Bool

    // MARK: - Relationships

    /// The owner this dog belongs to.
    /// Business and analytics intent: link pet to client profiles for billing, communication, and loyalty tracking.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.dogs)
    @Published
    var owner: DogOwner?

    /// All appointments for this dog.
    /// Used for scheduling workflows, service analytics, and tracking visit history.
    @Relationship(deleteRule: .cascade, inverse: \Appointment.dog)
    @Published
    var appointments: [Appointment]

    /// All charges associated with this dog.
    /// Supports billing workflows, revenue analytics, and financial auditing.
    @Relationship(deleteRule: .nullify, inverse: \Charge.dog)
    @Published
    var charges: [Charge]

    /// Vaccination records for this dog.
    /// Critical for compliance auditing, health analytics, and vaccination reminders.
    @Relationship(deleteRule: .cascade)
    @Published
    var vaccinationRecords: [VaccinationRecord]

    /// Behavior logs for this dog.
    /// Used for behavioral analytics, risk assessment, and personalized care planning.
    @Relationship(deleteRule: .cascade)
    @Published
    var behaviorLogs: [BehaviorLog]

    /// Pet gallery: list of images (as Data).
    /// Supports UI display, marketing, and engagement analytics.
    @Published
    var imageGallery: [Data]

    /// Tags (behavioral, medical, UX/analytics, etc.)
    /// Used extensively for badge displays, filtering, segmentation, and analytics.
    @Published
    var tags: [String]

    // MARK: - Metadata & Audit

    /// Date the dog was added to the system.
    /// Used for lifecycle analytics, retention tracking, and auditing.
    @Published
    var dateAdded: Date

    /// Timestamp of the last modification for audit trails and sync operations.
    @Published
    var lastModified: Date

    // MARK: - Security / Auditing

    /// For audit logs, tracks the last user or role who modified this record.
    /// Enables multi-user accountability and compliance reporting.
    @Published
    var lastModifiedBy: String? // (e.g., "Owner", "Assistant", or user ID)

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        breed: String? = nil,
        birthdate: Date? = nil,
        color: String? = nil,
        gender: String? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        owner: DogOwner? = nil,
        appointments: [Appointment] = [],
        charges: [Charge] = [],
        vaccinationRecords: [VaccinationRecord] = [],
        behaviorLogs: [BehaviorLog] = [],
        imageGallery: [Data] = [],
        tags: [String] = [],
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        lastModifiedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.color = color
        self.gender = gender
        self.notes = notes
        self.isActive = isActive
        self.owner = owner
        self.appointments = appointments
        self.charges = charges
        self.vaccinationRecords = vaccinationRecords
        self.behaviorLogs = behaviorLogs
        self.imageGallery = imageGallery
        self.tags = tags
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
    }

    // MARK: - Computed Properties

    /// Calculate dog's age in years (rounded down).
    /// Used for lifecycle analytics, UI age display, and care planning workflows.
    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year
    }

    /// Get the first image (thumbnail) as SwiftUI Image, if available.
    /// Supports UI thumbnails, galleries, and marketing visuals.
    var thumbnailImage: Image? {
        guard let data = imageGallery.first, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Returns true if the dog's birthday is this month (for dashboard badge).
    /// Supports birthday badges, notifications, and engagement campaigns.
    var isBirthdayMonth: Bool {
        guard let birthdate else { return false }
        return Calendar.current.component(.month, from: birthdate) == Calendar.current.component(.month, from: Date())
    }

    /// Returns a string summary of key tags (for badges/analytics).
    /// Used in UI badges, filtering, segmentation, and business intelligence.
    var tagSummary: String {
        tags.joined(separator: ", ")
    }

    /// Returns true if the dog is overdue for vaccination (for retention/risk engine).
    /// Supports compliance alerts, retention workflows, and health risk analytics.
    var isOverdueForVaccination: Bool {
        vaccinationRecords.contains { $0.isOverdue }
    }

    /// Returns true if behavioral log contains recent aggression flags (for risk dashboard).
    /// Used in risk management, behavior intervention workflows, and alerting.
    var hasRecentAggression: Bool {
        behaviorLogs.suffix(3).contains { $0.isAggressive }
    }

    /// Quick status for dashboard (active/inactive + main tag).
    /// Used in UI status indicators, filtering, and business workflows.
    var statusLabel: String {
        isActive ? (tags.first ?? "Active") : "Inactive"
    }

    /// Returns dog's full profile as a formatted string (for debug or export).
    /// Supports reporting, export, and audit review workflows.
    var fullProfileDescription: String {
        """
        Name: \(name)
        Breed: \(breed ?? "Unknown")
        Age: \(age.map { String($0) } ?? "Unknown")
        Color: \(color ?? "Unknown")
        Gender: \(gender ?? "Unknown")
        Notes: \(notes ?? "")
        Owner: \(owner?.displayName ?? "No Owner")
        Active: \(isActive ? "Yes" : "No")
        Tags: \(tagSummary)
        Appointments: \(appointments.count)
        Charges: \(charges.count)
        Vaccinations: \(vaccinationRecords.count)
        Behaviors: \(behaviorLogs.count)
        Added: \(dateAdded.formatted(.dateTime.month().day().year()))
        Last Modified: \(lastModified.formatted(.dateTime.month().day().year()))
        """
    }
}

// MARK: - Example Usage (for preview/testing)
#if DEBUG
extension Dog {
    /// Demo/business/preview instance used for UI previews and logic validation.
    /// Illustrates tokenized intent by including tags and key business attributes.
    static var preview: Dog {
        Dog(
            name: "Baxter",
            breed: "Golden Retriever",
            birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
            color: "Golden",
            gender: "Male",
            notes: "Friendly, loves water.",
            tags: ["Loyal", "BirthdayThisMonth"],
            imageGallery: [],
            isActive: true
        )
    }
}
#endif
