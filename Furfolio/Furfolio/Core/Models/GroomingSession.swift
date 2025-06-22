//
//  GroomingSession.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - GroomingSession (Modular, Tokenized, Auditable Grooming Session Model)

/// Represents a modular, auditable, and tokenized business session entity for a dog's grooming appointment.
/// This model supports comprehensive audit trails, business analytics, badge/status logic, compliance requirements,
/// and seamless UI design system integration (including badges, colors, icons, and outcome tags).
/// Designed to facilitate advanced analytics, route optimization for mobile groomers, staff and owner workflows,
/// and full integration with SwiftUI and SwiftData frameworks for efficient data management and UI rendering.
@Model
final class GroomingSession: Identifiable, ObservableObject {
    // MARK: - Identifiers
    
    /// Unique identifier for the grooming session.
    /// Used for audit tracking, data integrity, and referencing in business workflows.
    @Attribute(.unique)
    @Attribute(.required)
    var id: UUID
    
    // MARK: - Time
    
    /// The date and time of the session.
    /// Critical for audit trails, compliance reporting, scheduling analytics, and timeline visualizations in UI.
    @Attribute(.required)
    var date: Date
    
    // MARK: - Relationships
    
    /// Staff member who performed the grooming.
    /// Integral for business analytics on staff performance, workload, and compliance with service standards.
    /// Enables UI workflows for staff assignment and reporting dashboards.
    @Relationship(deleteRule: .nullify, inverse: nil)
    var staff: StaffMember?
    
    /// The dog that was groomed.
    /// Central to linking grooming records for analytics on pet health, preferences, and owner engagement.
    /// Supports UI features like profile badges and history views.
    @Relationship(deleteRule: .nullify, inverse: \Dog.groomingSessions)
    var dog: Dog?
    
    /// Appointment this session is linked to (optional).
    /// Provides business context and linkage for scheduling analytics, appointment compliance, and workflow tracking.
    /// Supports UI appointment management and reminders.
    @Relationship(deleteRule: .nullify, inverse: nil)
    var appointment: Appointment?
    
    /// Behavior log or mood (optional relationship).
    /// Captures behavioral notes for compliance, owner communication, and staff training analytics.
    /// Enables UI indicators and badges related to temperament and session adjustments.
    @Relationship(deleteRule: .cascade, inverse: nil)
    var behaviorLog: BehaviorLog?
    
    /// Audit log entries for tracking changes, history, and event provenance.
    /// Essential for compliance, forensic auditing, and business intelligence reporting.
    /// Supports UI audit trail views and change notifications.
    @Attribute(.required)
    var auditLog: [String]
    
    // MARK: - Session Data
    
    /// The service performed (e.g., Full Groom, Bath, Nail Trim).
    /// Used for business analytics, service popularity metrics, and UI badge/status display.
    /// Supports tokenized design system integration for consistent iconography and labeling.
    @Attribute(.required)
    var serviceType: ServiceType
    
    /// Duration in minutes.
    /// Important for operational analytics, billing, and route optimization.
    /// Displayed in UI summaries and scheduling views.
    @Attribute(.required)
    var durationMinutes: Int
    
    /// Optional notes (style, temperament, instructions).
    /// Captures session-specific details for owner/staff communication, compliance, and personalized service.
    /// Supports UI detail views and workflow instructions.
    var notes: String?
    
    /// List of products used (shampoos, treatments, etc.)
    /// Facilitates product usage analytics, inventory tracking, and compliance with safety standards.
    /// Enables UI product tagging and reporting.
    @Attribute(.required)
    var productsUsed: [String]
    
    /// List of outcomes/tags (e.g., "Ear Cleaned", "Nail Dremel", "Bit Clippers").
    /// Supports outcome-based analytics, badge/status logic, and UI tokenization for quick visual cues.
    /// Enables filtering and reporting on service quality and compliance.
    @Attribute(.required)
    var outcomes: [String]
    
    /// Is this session marked as a favorite style for the dog?
    /// Used in business logic to recommend styles, personalize marketing, and enhance owner engagement.
    /// Drives UI badges and favorite indicators.
    @Attribute(.required)
    var isFavorite: Bool
    
    /// Session rating (owner satisfaction, 1–5 stars).
    /// Key metric for business performance analytics, staff evaluation, and quality control.
    /// Displayed in UI dashboards and summary views.
    @Attribute(.required)
    var rating: Int
    
    /// Route order for mobile groomers to optimize travel sequence (TSP support).
    /// Critical for operational efficiency analytics and route planning algorithms.
    /// Supports UI route maps and schedule optimization features.
    @Attribute(.required)
    var routeOrder: Int
    
    // MARK: - Images
    
    /// Before photo for the session (as Data).
    /// Supports visual audit, compliance documentation, and marketing materials.
    /// Used in UI galleries and session summaries.
    var beforePhoto: Data?
    
    /// After photo for the session (as Data).
    /// Enables visual outcome verification, owner satisfaction tracking, and marketing.
    /// Displayed in UI galleries and progress views.
    var afterPhoto: Data?
    
    // MARK: - Analytics / Metadata
    
    /// Metadata: creation date.
    /// Used for audit timelines, compliance reporting, and data lifecycle management.
    @Attribute(.required)
    var createdAt: Date
    
    /// Metadata: last modification date.
    /// Supports audit trail accuracy, version control, and compliance.
    @Attribute(.required)
    var lastModified: Date
    
    /// Metadata: created by user identifier.
    /// Essential for accountability, audit logs, and staff performance tracking.
    @Attribute(.required)
    var createdBy: String
    
    /// Metadata: last modified by user identifier.
    /// Facilitates change tracking, audit compliance, and workflow accountability.
    @Attribute(.required)
    var lastModifiedBy: String
    
    // MARK: - Computed Properties
    
    /// Returns a readable summary string of the service performed and duration.
    /// Used extensively in dashboards, analytics exports, badge generation, and business workflows
    /// to provide quick, human-readable overviews of session details.
    var displayServiceSummary: String {
        "\(serviceType.rawValue) - \(durationMinutes) min"
    }
    
    // MARK: - Initializer
    
    /// Initializes a new GroomingSession instance with full audit, analytics, and workflow metadata.
    /// Emphasizes audit/event logging, analytics readiness, and owner/staff workflow impact.
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        serviceType: ServiceType,
        durationMinutes: Int = 60,
        notes: String? = nil,
        staff: StaffMember? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        beforePhoto: Data? = nil,
        afterPhoto: Data? = nil,
        productsUsed: [String] = [],
        outcomes: [String] = [],
        behaviorLog: BehaviorLog? = nil,
        isFavorite: Bool = false,
        rating: Int = 3,
        routeOrder: Int = 0,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        createdBy: String = "system",
        lastModifiedBy: String = "system",
        auditLog: [String] = []
    ) {
        self.id = id
        self.date = date
        self.serviceType = serviceType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.staff = staff
        self.dog = dog
        self.appointment = appointment
        self.beforePhoto = beforePhoto
        self.afterPhoto = afterPhoto
        self.productsUsed = productsUsed
        self.outcomes = outcomes
        self.behaviorLog = behaviorLog
        self.isFavorite = isFavorite
        self.rating = rating
        self.routeOrder = routeOrder
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
    }
    
    // MARK: - Preview for SwiftUI and testing
    
    /// Preview instance for SwiftUI previews and development/testing.
    /// Demonstrates demo/business/preview logic and tokenized design intent,
    /// showcasing audit, analytics, and UI integration in a representative sample.
    static var preview: GroomingSession {
        GroomingSession(
            date: Date(),
            serviceType: .fullGroom,
            durationMinutes: 90,
            notes: "Calm and cooperative. Used lavender shampoo.",
            staff: nil,
            dog: nil,
            appointment: nil,
            productsUsed: ["Lavender Shampoo", "Conditioner"],
            outcomes: ["Nail Trimmed", "Ear Cleaned"],
            behaviorLog: nil,
            isFavorite: true,
            rating: 5,
            routeOrder: 1,
            createdAt: Date(),
            lastModified: Date(),
            createdBy: "previewUser",
            lastModifiedBy: "previewUser",
            auditLog: ["Created preview session"]
        )
    }
}

// MARK: - Extend Dog to relate to grooming sessions

extension Dog {
    /// All grooming sessions associated with this dog.
    /// Enables audit and analytics integration by linking pet grooming history with business workflows.
    /// Supports UI features for displaying session history, badges, and compliance status.
    /// Facilitates business logic for personalized grooming recommendations and owner engagement.
    @Relationship(deleteRule: .cascade, inverse: \GroomingSession.dog)
    var groomingSessions: [GroomingSession] {
        get { [] }
        set { /* SwiftData synthesized */ }
    }
}
