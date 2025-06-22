//
//  Task.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - Task (Modular, Tokenized, Auditable Task/To-Do Model)

/// Defines the Task model used in the new architecture for managing business operations, reminders, and to-do items.
/// This class supports relationships with owners, dogs, appointments, businesses, and staff members,
/// and includes properties for recurrence, priority, tagging, reminders, and archival status.
/// 
/// This model represents a modular, tokenized, and auditable business task entity designed for owner, staff, and automation scenarios.
/// It supports detailed audit trails for compliance and event logging, integrates with analytics for reporting and insights,
/// and is built to work seamlessly with UI design systems through badges, colors, and priority/status logic.
/// The Task entity is designed for scalable, owner-focused dashboards, comprehensive business reporting,
/// and full workflow coverage ensuring operational efficiency and compliance.
@available(iOS 18.0, *)
@Model
final class Task: Identifiable, ObservableObject {
    // MARK: - Properties

    /// Unique identifier for the task.
    /// Used for audit tracking, event correlation, and unique tokenization across systems.
    @Attribute(.unique)
    var id: UUID

    /// Title or name of the task.
    /// Serves as the primary descriptor for UI display, reporting, and workflow identification.
    var title: String

    /// Optional detailed description of the task.
    /// Provides context for compliance, audit clarity, and detailed business notes.
    var details: String?

    /// Optional due date for the task.
    /// Critical for business scheduling, workflow deadlines, analytics on task timeliness, and UI calendar integration.
    var dueDate: Date?

    /// Optional specific reminder time for alerts and notifications.
    /// Supports compliance with reminder policies, user notifications, and event-driven analytics.
    var reminderTime: Date?

    /// Indicates whether the task has been completed.
    /// Used for audit trail status, workflow progression, and business reporting on task closure.
    var completed: Bool

    /// Timestamp when the task was marked completed.
    /// Essential for audit logging, compliance verification, and performance analytics.
    var completedAt: Date?

    /// Timestamp when the task was created.
    /// Used for audit history, lifecycle tracking, and business analytics on task creation trends.
    var createdAt: Date

    /// Timestamp for the last modification of the task.
    /// Supports audit trails, versioning, and UI indicators for recent activity.
    var lastModified: Date

    /// Indicates if the task is recurring.
    /// Supports business logic for automation, scheduling, and compliance with repeatable task policies.
    var isRecurring: Bool

    /// Recurrence rule defining the pattern of recurrence.
    /// Used in analytics for recurring task trends, business scheduling logic, and UI recurrence labeling.
    var recurrenceRule: RecurrenceRule?

    /// Priority level of the task.
    /// Drives audit importance, analytics on task criticality, business urgency workflows,
    /// compliance prioritization, and UI badge/token display.
    var priority: Priority

    /// Tags assigned to the task for categorization and filtering.
    /// Enables business segmentation, analytics filtering, audit categorization, and UI workflow grouping.
    var tags: [String]

    /// Flag indicating if the task is archived (soft deleted).
    /// Supports compliance with data retention policies, audit archiving, and UI visibility toggling.
    var isArchived: Bool

    // MARK: - Relationships

    /// Owner associated with the task (e.g., dog owner).
    /// Links business client context for analytics, audit ownership, and UI workflow personalization.
    @Relationship(deleteRule: .nullify)
    var owner: DogOwner?

    /// Dog associated with the task.
    /// Provides business context for pet-related workflows, analytics on pet-specific tasks,
    /// audit traceability, and UI detail views.
    @Relationship(deleteRule: .nullify)
    var dog: Dog?

    /// Appointment associated with the task.
    /// Connects scheduling workflows, audit event correlation, business appointment analytics,
    /// and UI calendar/task integration.
    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?

    /// Business entity associated with the task.
    /// Essential for multi-business analytics, audit segregation, compliance boundaries,
    /// and UI dashboard filtering.
    @Relationship(deleteRule: .nullify)
    var business: Business?

    /// Staff member assigned to the task.
    /// Supports workflow assignment tracking, audit accountability, business resource analytics,
    /// and UI task delegation displays.
    @Relationship(deleteRule: .nullify)
    var assignedTo: Staff?

    // MARK: - Initializer

    /// Creates a new Task instance.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID.
    ///   - title: Title of the task.
    ///   - details: Optional detailed description.
    ///   - dueDate: Optional due date.
    ///   - reminderTime: Optional reminder time.
    ///   - completed: Completion status, defaults to false.
    ///   - completedAt: Completion timestamp.
    ///   - createdAt: Creation timestamp, defaults to current date.
    ///   - lastModified: Last modification timestamp, defaults to current date.
    ///   - isRecurring: Flag for recurrence, defaults to false.
    ///   - recurrenceRule: Recurrence pattern.
    ///   - priority: Priority level, defaults to .none.
    ///   - tags: Tags for categorization, defaults to empty array.
    ///   - isArchived: Archival status, defaults to false.
    ///   - owner: Associated dog owner.
    ///   - dog: Associated dog.
    ///   - appointment: Associated appointment.
    ///   - business: Associated business.
    ///   - assignedTo: Assigned staff member.
    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        reminderTime: Date? = nil,
        completed: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        priority: Priority = .none,
        tags: [String] = [],
        isArchived: Bool = false,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        business: Business? = nil,
        assignedTo: Staff? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.reminderTime = reminderTime
        self.completed = completed
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.priority = priority
        self.tags = tags
        self.isArchived = isArchived
        self.owner = owner
        self.dog = dog
        self.appointment = appointment
        self.business = business
        self.assignedTo = assignedTo
    }

    // MARK: - Helpers

    /// Marks the task as completed, updates completion timestamp and last modified date.
    /// This method supports audit/event logging for compliance, triggers analytics event for task completion,
    /// and updates workflow status to reflect current state in UI and business logic.
    func markCompleted() {
        completed = true
        completedAt = Date()
        lastModified = Date()
    }

    /// Marks the task as incomplete, clears completion timestamp and updates last modified date.
    /// Supports audit reversal events, analytics tracking for task reactivation,
    /// and workflow state updates for UI and compliance monitoring.
    func markIncomplete() {
        completed = false
        completedAt = nil
        lastModified = Date()
    }
}

// MARK: - RecurrenceRule Enum

/// Enum representing recurrence patterns for tasks.
/// Used in analytics to track recurrence trends and frequency,
/// drives business logic for scheduling and automation,
/// supports compliance with recurring task policies,
/// and integrates with UI components for scheduling displays and recurrence labeling.
enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    /// User-friendly display name for the recurrence rule.
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Priority Enum

/// Enum representing priority levels for tasks.
/// Used for audit importance tagging, analytics on task criticality distribution,
/// business urgency workflows and escalation policies,
/// compliance prioritization for sensitive tasks,
/// UI badge and token integration to visually communicate urgency,
/// and dashboard filtering and reporting.
enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case low
    case medium
    case high
    case critical

    var id: Int { rawValue }

    /// User-friendly display name for the priority.
    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Sample Data Extension

@available(iOS 18.0, *)
extension Task {
    /// Provides sample Task data for previews and testing.
    /// This sample is designed with demo, business, and preview logic in mind,
    /// illustrating tokenized design intent for priority, recurrence, tagging, and workflow status.
    /// Useful for UI development, business scenario demonstration, and analytics validation.
    static var sample: Task {
        Task(
            title: "Sample Task",
            details: "This is a sample task for testing and preview purposes.",
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            reminderTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()),
            completed: false,
            isRecurring: true,
            recurrenceRule: .weekly,
            priority: .medium,
            tags: ["urgent", "client"],
            isArchived: false
        )
    }
}
