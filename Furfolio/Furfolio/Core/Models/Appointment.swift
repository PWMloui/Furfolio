//
//  Appointment.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - Appointment (Unified, Modular, Tokenized, Auditable Appointment Model)

/// Represents a modular, auditable, and tokenized business appointment entity within the Furfolio system.
/// This class supports comprehensive audit trails for compliance and business reporting, integrates route optimization for logistics,
/// and is designed to facilitate business analytics and insights. It is also prepared for UI design system integration,
/// including badges, status indicators, and color coding to enhance user workflows and visual consistency.
@Model
final class Appointment: Identifiable, ObservableObject {
    // MARK: - Core Properties
    
    /// Unique identifier for the appointment, ensuring entity integrity across systems and audit logs.
    @Attribute(.unique)
    var id: UUID = UUID()
    
    /// The scheduled start date and time of the appointment.
    /// Critical for scheduling workflows, calendar integrations, and time-based analytics.
    var date: Date
    
    /// Duration of the appointment in minutes.
    /// Used for capacity planning, resource allocation, and service billing analytics.
    var durationMinutes: Int
    
    /// The type of service provided during the appointment.
    /// Supports business logic branching, pricing, and UI tokenization for display badges and color coding.
    var serviceType: ServiceType
    
    /// Optional notes related to the appointment.
    /// Useful for capturing client requests, service details, and internal communications.
    var notes: String?
    
    /// Current status of the appointment.
    /// Drives workflow states, UI status indicators, and operational reporting.
    var status: AppointmentStatus
    
    /// Tags associated with the appointment for categorization and filtering.
    /// Enables analytics segmentation and enhances search and reporting capabilities.
    var tags: [String]
    
    // MARK: - Relationships
    
    /// The dog owner associated with this appointment.
    /// Supports customer relationship management and personalized service analytics.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.appointments)
    var owner: DogOwner?
    
    /// The dog associated with this appointment.
    /// Enables pet-specific service tracking and health analytics.
    @Relationship(deleteRule: .nullify, inverse: \Dog.appointments)
    var dog: Dog?
    
    // MARK: - Behavior & Logs
    
    /// Optional behavior log related to the appointment.
    /// Facilitates detailed service notes, behavior tracking, and supports compliance and training analytics.
    @Relationship(deleteRule: .cascade)
    var behaviorLog: BehaviorLog?
    
    // MARK: - Audit & Metadata
    
    /// Timestamp of the last edit to the appointment.
    /// Essential for audit trails, concurrency control, and operational transparency.
    var lastEdited: Date
    
    /// Identifier of the user who created the appointment.
    /// Supports accountability, audit reporting, and user activity analytics.
    var createdBy: String?
    
    /// Identifier of the user who last modified the appointment.
    /// Enables detailed audit trails and user workflow tracking.
    var lastModifiedBy: String?
    
    /// Timestamp when the appointment was created.
    /// Important for lifecycle analytics and historical reporting.
    var createdAt: Date
    
    /// A chronological log of audit entries capturing changes and events related to the appointment.
    /// Central to compliance, event sourcing, and business intelligence.
    var auditLog: [AuditEntry]
    
    // MARK: - Computed Properties
    
    /// Calculates the end date/time of the appointment based on start date and duration.
    /// Useful for scheduling conflicts detection, route planning, and time-based analytics.
    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: date) ?? date
    }
    
    /// Indicates whether the appointment has already passed.
    /// Drives UI state changes, reminders, and historical reporting.
    var isPast: Bool {
        endDate < Date()
    }
    
    /// Indicates whether the appointment is upcoming.
    /// Supports proactive notifications, scheduling workflows, and business forecasting.
    var isUpcoming: Bool {
        date > Date()
    }
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        date: Date,
        durationMinutes: Int = 60,
        serviceType: ServiceType,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        notes: String? = nil,
        status: AppointmentStatus = .scheduled,
        tags: [String] = [],
        behaviorLog: BehaviorLog? = nil,
        lastEdited: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil,
        createdAt: Date = Date(),
        auditLog: [AuditEntry] = []
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.serviceType = serviceType
        self.owner = owner
        self.dog = dog
        self.notes = notes
        self.status = status
        self.tags = tags
        self.behaviorLog = behaviorLog
        self.lastEdited = lastEdited
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.auditLog = auditLog
    }
    
    // MARK: - Methods
    
    /// Adds a new audit entry to the audit log and updates metadata accordingly.
    ///
    /// This method is critical for maintaining an accurate audit trail of all appointment-related events,
    /// supporting compliance requirements, enabling detailed event logging for business owners,
    /// and feeding analytics systems for behavioral insights and operational metrics.
    ///
    /// - Parameters:
    ///   - action: The type of audit action performed (e.g., created, modified).
    ///   - user: The identifier of the user performing the action, used for accountability.
    func addAudit(action: AuditAction, user: String?) {
        let entry = AuditEntry(
            date: Date(),
            action: action,
            user: user
        )
        // Append immutably for thread safety if needed
        auditLog.append(entry)
        lastEdited = entry.date
        lastModifiedBy = user
    }
    
    /// Location coordinate for route optimization (TSP solver).
    ///
    /// Provides geospatial data used in logistics optimizations, route planning,
    /// and mapping visualizations to improve operational efficiency and customer service.
    ///
    /// Returns nil if no valid owner address coordinate is available.
    var locationCoordinate: Coordinate? {
        guard let coord = owner?.address?.coordinate else {
            return nil
        }
        return coord
    }
}

// MARK: - Enums & Supporting Types

/// Defines the types of services available for appointments, integrating design tokens for UI representation,
/// and supporting business logic for pricing, duration estimates, and workflow branching.
enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case fullGroom
    case basicBath
    case nailTrim
    case custom
    
    var id: String { rawValue }
    
    /// Display-friendly name for UI elements such as badges and labels, consistent with design system tokens.
    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .custom: return "Custom"
        }
    }
    
    /// Estimated duration in minutes for the service type.
    /// Used in scheduling algorithms, capacity planning, and customer expectations management.
    var durationEstimate: Int {
        switch self {
        case .fullGroom: return 90
        case .basicBath: return 45
        case .nailTrim: return 20
        case .custom: return 60
        }
    }
}

/// Represents the status of an appointment, designed to integrate with UI design tokens for color coding and badges,
/// and to drive business workflow logic such as notifications, reporting, and operational metrics.
enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case completed
    case cancelled
    case noShow
    case inProgress
    
    var id: String { rawValue }
    
    /// Display-friendly status name for UI elements and reports.
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .inProgress: return "In Progress"
        }
    }
    
    /// Returns true if appointment status is considered active.
    /// Used for filtering active workflows, resource allocation, and real-time dashboards.
    var isActive: Bool {
        self == .scheduled || self == .inProgress
    }
}

// MARK: - Audit Trail Types

/// Represents a single audit entry capturing an event or change related to an appointment.
/// This struct supports detailed audit/event logging necessary for compliance, operational transparency,
/// and enriched business reporting and analytics.
struct AuditEntry: Codable, Identifiable {
    /// Unique identifier for the audit entry.
    var id: UUID = UUID()
    
    /// Timestamp when the audit event occurred.
    var date: Date
    
    /// The type of action performed, critical for event classification and reporting.
    var action: AuditAction
    
    /// Identifier of the user responsible for the action, supporting accountability and user activity tracking.
    var user: String?
}

/// Enumerates possible audit actions on appointments, facilitating precise event categorization
/// for audit trails and business intelligence reporting.
enum AuditAction: String, Codable, CaseIterable, Identifiable {
    case created, modified, deleted, statusChanged, noteAdded
    
    var id: String { rawValue }
    
    /// Human-readable description of the audit action for UI display and report generation.
    var description: String {
        switch self {
        case .created: return "Created appointment"
        case .modified: return "Edited appointment"
        case .deleted: return "Deleted appointment"
        case .statusChanged: return "Changed status"
        case .noteAdded: return "Added note"
        }
    }
}

// MARK: - Coordinate (for TSP/route optimization)

/// Represents a geographic coordinate used in route optimization,
/// analytics, and map visualization to enhance logistics and operational efficiency.
struct Coordinate: Codable, Equatable {
    /// Latitude component of the coordinate.
    let latitude: Double
    
    /// Longitude component of the coordinate.
    let longitude: Double
}
