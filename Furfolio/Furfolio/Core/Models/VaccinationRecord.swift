//  VaccinationRecord.swift
//  Furfolio Business Management
//
//  Created by mac on 6/19/25.
//  Updated for best practices and enhanced business management features.
//

import Foundation
import SwiftData

// MARK: - VaccinationRecord (Modular, Tokenized, Auditable Vaccine Model)

/// Represents a modular, auditable, and tokenized vaccination record for a dog within Furfolio's business management ecosystem.
/// This model supports compliance tracking, analytics, badge/status logic, reminder workflows, reporting, and UI tokenization including icons, tags, and verified status.
/// Designed to integrate seamlessly with dashboards, owner workflows, and advanced querying capabilities for comprehensive business management.
@Model
public final class VaccinationRecord: Identifiable, ObservableObject {
    /// Unique identifier for the vaccination record, supporting audit trails and event logging.
    @Attribute(.unique)
    public var id: UUID

    /// The vaccine type administered (e.g., Rabies, Bordetella, Parvo, etc.), enabling detailed analytics, compliance categorization, and UI tokenization.
    public var vaccineType: VaccineType

    /// The date the vaccine was administered, critical for compliance audits, scheduling, and historical analytics.
    public var dateAdministered: Date

    /// The expiration or next due date for the vaccine, used for compliance monitoring, reminder workflows, and reporting of upcoming needs.
    public var expirationDate: Date

    /// Optional lot number for traceability, recall management, and quality control analytics.
    public var lotNumber: String?

    /// Manufacturer of the vaccine, supporting vendor tracking, quality assurance, and business analytics.
    public var manufacturer: String?

    /// Clinic where the vaccine was administered, important for business records, compliance verification, and reporting.
    public var clinic: String?

    /// Veterinarian who administered the vaccine, supporting accountability, audit trails, and trust reporting.
    public var veterinarian: String?

    /// Indicates if the clinic or veterinarian is verified, used for compliance validation, trust badges, and UI status indicators.
    public var isVerified: Bool?

    /// Notes or reactions related to the vaccination, stored externally for scalability and detailed audit or clinical observations.
    @Attribute(.externalStorage)
    public var notes: String?

    /// Reminder date for upcoming vaccinations or follow-ups, enabling proactive workflows and notification scheduling.
    public var reminderDate: Date?

    /// Tags for advanced querying, categorization, and UI badge display (e.g., ["Booster", "Annual"]).
    public var tags: [String]

    /// The dog this vaccination record belongs to, enabling relationship management for business analytics, owner workflows, and UI contextualization.
    @Relationship(deleteRule: .nullify, inverse: \Dog.vaccinationRecords)
    public var dog: Dog?

    /// The user who created this record, supporting audit trails, accountability, and UI attribution.
    @Relationship(deleteRule: .nullify)
    public var createdBy: User?

    // MARK: - Computed Properties

    /// Indicates if the vaccination is expired based on the current date.
    /// Used for dashboard status indicators, compliance alerts, analytics on vaccination currency, and reporting overdue vaccines.
    public var isExpired: Bool {
        Date() > expirationDate
    }

    /// Indicates if the vaccination is due soon (within 30 days).
    /// Supports proactive alerting in dashboards, reminder workflows, compliance monitoring, and reporting upcoming vaccine renewals.
    public var isDueSoon: Bool {
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expirationDate <= thirtyDaysFromNow && !isExpired
    }

    // MARK: - Init

    /// Initializes a new VaccinationRecord with all relevant details for comprehensive business management.
    /// This initializer supports audit/event logging, analytics tracking, business logic integration, and compliance adherence.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID to ensure traceability.
    ///   - vaccineType: Type of vaccine administered, essential for categorization and compliance.
    ///   - dateAdministered: Date when the vaccine was given, critical for audit and scheduling.
    ///   - expirationDate: Date when the vaccine expires or is due next, used for compliance and reminders.
    ///   - lotNumber: Optional lot number for traceability and recall management.
    ///   - manufacturer: Optional manufacturer name, supporting vendor analytics.
    ///   - clinic: Optional clinic name for compliance and business records.
    ///   - veterinarian: Optional veterinarian name for accountability.
    ///   - isVerified: Optional flag indicating clinic/vet verification status for trust and compliance.
    ///   - notes: Optional notes or reactions, stored externally for scalability and detailed audit.
    ///   - reminderDate: Optional date for reminders, enabling proactive workflows.
    ///   - tags: Tags for categorization, advanced querying, and UI badge display.
    ///   - dog: Optional associated Dog entity for relationship management and analytics.
    ///   - createdBy: Optional User who created the record, supporting audit trails and accountability.
    public init(
        id: UUID = UUID(),
        vaccineType: VaccineType,
        dateAdministered: Date,
        expirationDate: Date,
        lotNumber: String? = nil,
        manufacturer: String? = nil,
        clinic: String? = nil,
        veterinarian: String? = nil,
        isVerified: Bool? = nil,
        notes: String? = nil,
        reminderDate: Date? = nil,
        tags: [String] = [],
        dog: Dog? = nil,
        createdBy: User? = nil
    ) {
        self.id = id
        self.vaccineType = vaccineType
        self.dateAdministered = dateAdministered
        self.expirationDate = expirationDate
        self.lotNumber = lotNumber
        self.manufacturer = manufacturer
        self.clinic = clinic
        self.veterinarian = veterinarian
        self.isVerified = isVerified
        self.notes = notes
        self.reminderDate = reminderDate
        self.tags = tags
        self.dog = dog
        self.createdBy = createdBy
    }

    /// Sample vaccination record for SwiftUI previews, onboarding, and demo purposes.
    /// Demonstrates business logic, tokenized UI elements, and provides realistic data for preview and testing.
    public static let sample = VaccinationRecord(
        vaccineType: .rabies,
        dateAdministered: Date(timeIntervalSinceNow: -31536000), // 1 year ago
        expirationDate: Date(timeIntervalSinceNow: 31536000), // 1 year ahead
        lotNumber: "ABC123",
        manufacturer: "VetPharma",
        clinic: "Happy Paws Clinic",
        veterinarian: "Dr. Smith",
        isVerified: true,
        notes: "No adverse reactions observed.",
        reminderDate: Calendar.current.date(byAdding: .day, value: 350, to: Date()),
        tags: ["Annual", "Booster"]
    )
}

/// Enum for common vaccine types used in Furfolio's business management.
/// Conforms to Codable, CaseIterable, Identifiable, and Equatable to support multi-module access, audit, analytics, compliance, UI badge/token integration, and business logic workflows.
public enum VaccineType: String, Codable, CaseIterable, Identifiable, Equatable {
    case rabies
    case bordetella
    case parvo
    case distemper
    case hepatitis
    case parainfluenza
    case leptospirosis
    case influenza
    case coronavirus
    case custom

    /// Unique identifier for each vaccine type, supporting audit, analytics, and UI tokenization.
    public var id: String { rawValue }

    /// User-friendly label for display purposes in UI, supporting localization, analytics categorization, and reporting.
    public var label: String {
        switch self {
        case .rabies: return "Rabies"
        case .bordetella: return "Bordetella"
        case .parvo: return "Parvo"
        case .distemper: return "Distemper"
        case .hepatitis: return "Hepatitis"
        case .parainfluenza: return "Parainfluenza"
        case .leptospirosis: return "Leptospirosis"
        case .influenza: return "Influenza"
        case .coronavirus: return "Coronavirus"
        case .custom: return "Custom"
        }
    }

    /// System icon name representing the vaccine type for consistent UI tokenization, badge display, and analytics visualization.
    public var icon: String {
        switch self {
        case .rabies: return "bandage"
        case .bordetella: return "lungs.fill"
        case .parvo: return "cross.case.fill"
        case .distemper: return "cross.case"
        case .hepatitis: return "heart.fill"
        case .parainfluenza: return "wind"
        case .leptospirosis: return "drop"
        case .influenza: return "thermometer"
        case .coronavirus: return "shield.lefthalf.filled"
        case .custom: return "star"
        }
    }
}
