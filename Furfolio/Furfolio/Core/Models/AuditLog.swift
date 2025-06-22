//
//  AuditLog.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - AuditLog (Unified, Modular, Tokenized, Auditable Change/Event Log)

/// Represents a single audit log entry (change/action/event) in the app.
/// This is a modular, tokenized, multi-entity, fully auditable event/change log designed to capture all core business object interactions.
/// Enables advanced compliance tracking, detailed business reporting, analytics, and seamless UI integration with badges and icons.
/// Supports complex querying across multiple linked entities to provide a unified audit trail for multi-user environments.
///
/// - Note: Future migrations may include adding indices on timestamp and entity relationships.
///         Consider migrating existing logs to support multi-entity linking if needed.
@Model
final class AuditLog: Identifiable, ObservableObject {
    
    // MARK: - Primary Attributes
    
    /// Unique identifier for this audit log entry.
    /// Used as a primary key to uniquely identify each logged event/action.
    @Attribute(.unique)
    var id: UUID = UUID()
    
    /// Timestamp when the action/event occurred.
    /// Critical for audit timelines, business analytics, and chronological reporting.
    var timestamp: Date = Date()
    
    /// Type of action performed (create, update, delete, etc.).
    /// Drives business workflow interpretation, compliance categorization, and UI token/badge display.
    var actionType: AuditActionType
    
    /// Type of entity the action applies to (owner, dog, appointment, etc.).
    /// Used for grouping, filtering, and analytics in reports and UI displays.
    var entityType: AuditEntityType
    
    /// Identifier of the affected entity instance (UUID or composite key as string).
    /// Links the audit log entry to the specific business object instance for traceability.
    var entityID: String   // Use String for UUID or composite keys
    
    /// Human-readable summary describing the action or event.
    /// Provides quick context in audit reports, UI lists, and notifications.
    var summary: String    // Human-readable summary of action
    
    /// Optional detailed JSON or formatted string describing changes or event specifics.
    /// Supports deep audit inspection, compliance evidence, and analytics enrichment.
    var details: String?   // Optional: JSON or formatted change detail
    
    /// Optional identifier for the user who performed the action.
    /// Enables user-centric audit trails, accountability, and access control reporting.
    var user: String?      // Who made the change (user identifier)
    
    // MARK: - Relationships to Entities
    
    /// Optional link to the affected DogOwner entity.
    /// Used to associate audit events with specific dog owners for business workflows and owner-centric reports.
    @Relationship(inverse: \DogOwner.auditLogs)
    var dogOwner: DogOwner?
    
    /// Optional link to the affected Dog entity.
    /// Enables dog-specific audit trails for health, appointments, and activity analytics.
    @Relationship(inverse: \Dog.auditLogs)
    var dog: Dog?
    
    /// Optional link to the affected Appointment entity.
    /// Connects audit entries to scheduled activities for appointment history and compliance tracking.
    @Relationship(inverse: \Appointment.auditLogs)
    var appointment: Appointment?
    
    /// Optional link to the affected Charge entity.
    /// Associates financial transactions with audit logs for billing and payment compliance.
    @Relationship(inverse: \Charge.auditLogs)
    var charge: Charge?
    
    /// Optional link to the affected User entity.
    /// Links audit events to users for security audits, login/logout tracking, and user activity reports.
    @Relationship(inverse: \User.auditLogs)
    var userEntity: User?
    
    /// Optional link to the affected Task entity.
    /// Associates audit logs with task management for workflow monitoring and productivity analytics.
    @Relationship(inverse: \Task.auditLogs)
    var task: Task?
    
    /// Optional link to the affected Setting entity.
    /// Tracks configuration changes for system audit and compliance.
    @Relationship(inverse: \Setting.auditLogs)
    var setting: Setting?
    
    /// Optional link to the affected Business entity.
    /// Enables business-wide audit aggregation and multi-entity reporting.
    @Relationship(inverse: \Business.auditLogs)
    var business: Business?
    
    /// Optional link to a custom entity or other entity types.
    /// Provides extensibility for audit logging beyond predefined entities, supporting custom business needs.
    @Relationship
    var customEntity: AnyObject?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: AuditActionType,
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        details: String? = nil,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.entityType = entityType
        self.entityID = entityID
        self.summary = summary
        self.details = details
        self.user = user
        self.dogOwner = dogOwner
        self.dog = dog
        self.appointment = appointment
        self.charge = charge
        self.userEntity = userEntity
        self.task = task
        self.setting = setting
        self.business = business
        self.customEntity = customEntity
    }
    
    // MARK: - Computed Properties
    
    /// A short, human-friendly label summarizing the audit log entry.
    /// Useful for UI display, notifications, and quick audit overviews.
    var shortLabel: String {
        "\(actionType.displayName) \(entityType.displayName)"
    }
    
    // MARK: - Static Helpers for Common Audit Log Creation
    
    /// Creates a 'create' audit log entry for the specified entity.
    /// Use this method to log creation events in business workflows, enabling accurate reporting and compliance tracking.
    /// This supports audit trails that verify entity lifecycle starts and informs UI badges for new entries.
    static func created(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil
    ) -> AuditLog {
        AuditLog(
            actionType: .create,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity
        )
    }
    
    /// Creates an 'update' audit log entry for the specified entity.
    /// Use this to log modifications within business processes, facilitating detailed change tracking and versioning.
    /// Supports audit compliance by capturing what was updated and by whom, and enables analytics on change frequency.
    static func updated(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil
    ) -> AuditLog {
        AuditLog(
            actionType: .update,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity
        )
    }
    
    /// Creates a 'delete' audit log entry for the specified entity.
    /// Use this to record deletions for compliance auditing, data lifecycle management, and forensic analysis.
    /// Helps ensure traceability of removals and supports business reporting on data retention and deletion events.
    static func deleted(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil
    ) -> AuditLog {
        AuditLog(
            actionType: .delete,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity
        )
    }
}

/// Enum of audit action types (what happened).
/// Defines the kind of action performed on entities, fundamental for audit reporting, business analytics, and UI token/badge integration.
/// Enables consistent classification of audit events across the app.
enum AuditActionType: String, Codable, CaseIterable, Identifiable {
    case create
    case update
    case delete
    case view
    case login
    case logout
    case export
    case importData
    case restore
    case custom
    
    var id: String { rawValue }
    
    /// Human-readable display name for the action type.
    /// Used in UI badges, reports, and analytics dashboards to clearly indicate the nature of the audit event.
    var displayName: String {
        switch self {
        case .create: return "Created"
        case .update: return "Updated"
        case .delete: return "Deleted"
        case .view: return "Viewed"
        case .login: return "Logged In"
        case .logout: return "Logged Out"
        case .export: return "Exported Data"
        case .importData: return "Imported Data"
        case .restore: return "Restored"
        case .custom: return "Custom Action"
        }
    }
    
    /// Icon name representing the action type.
    /// Utilized in UI components and badges to provide visual cues corresponding to audit actions.
    var icon: String {
        switch self {
        case .create: return "plus.circle.fill"
        case .update: return "pencil.circle.fill"
        case .delete: return "trash.circle.fill"
        case .view: return "eye.circle.fill"
        case .login: return "person.crop.circle.badge.checkmark"
        case .logout: return "person.crop.circle.badge.xmark"
        case .export: return "square.and.arrow.up"
        case .importData: return "square.and.arrow.down"
        case .restore: return "arrow.uturn.left.circle"
        case .custom: return "star.circle"
        }
    }
}

/// Enum for what type of entity the action applies to.
/// Categorizes audit events by entity type to enable effective report grouping, business analytics segmentation, and display grouping in the UI.
enum AuditEntityType: String, Codable, CaseIterable, Identifiable {
    case owner
    case dog
    case appointment
    case charge
    case user
    case task
    case setting
    case business
    case custom
    
    var id: String { rawValue }
    
    /// Human-readable display name for the entity type.
    /// Used in reports, analytics dashboards, and UI grouping to clearly identify the affected business object category.
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .dog: return "Dog"
        case .appointment: return "Appointment"
        case .charge: return "Charge"
        case .user: return "User"
        case .task: return "Task"
        case .setting: return "Setting"
        case .business: return "Business"
        case .custom: return "Other"
        }
    }
}
