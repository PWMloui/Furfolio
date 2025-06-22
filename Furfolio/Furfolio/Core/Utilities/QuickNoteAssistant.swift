//
//  QuickNoteAssistant.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - QuickNote (Modular, Tokenized, Auditable Sticky Note Model)

/// Represents a modular, tokenized, auditable sticky note entity within Furfolio.
/// This model supports comprehensive analytics, business intelligence, multi-entity linking (owners, dogs, appointments),
/// compliance requirements including audit trails, badge/category logic for UI filtering, and is prepared for future encryption.
/// Designed for scalable owner-focused dashboards, business reporting, multi-user audit trails, and seamless UI integration.
/// Enables classification, filtering, and reporting while ensuring data integrity and compliance in multi-user environments.
@Model
public final class QuickNote: Identifiable, ObservableObject {

    // MARK: - Properties

    @Attribute(.unique)
    /// Unique identifier for audit tracking and entity referencing across systems.
    public var id: UUID

    /// The textual content of the note.
    /// Audit & Compliance: Captured and versioned for traceability.
    /// Analytics: Enables keyword/token analysis and content categorization.
    /// Business: Supports note-taking workflows and user collaboration.
    /// UI/Workflow: Displayed in quick note interfaces with future encryption readiness.
    public var content: String

    /// Timestamp when the note was created.
    /// Audit & Compliance: Critical for event sequencing and history.
    /// Analytics: Enables trend analysis and lifecycle metrics.
    /// Business: Supports SLA and workflow timing.
    public var createdAt: Date

    /// Timestamp when the note was last updated.
    /// Audit & Compliance: Tracks modification events for compliance.
    /// Analytics: Supports edit frequency and user engagement metrics.
    /// Business: Workflow state monitoring.
    public var updatedAt: Date

    /// Timestamp when the note was last accessed (viewed or edited).
    /// Audit & Compliance: Access logging for security and compliance.
    /// Analytics: Measures note relevance and user interaction.
    /// Business: Prioritizes notes in UI and workflows.
    public var lastAccessedAt: Date

    /// Indicates whether the note is pinned for quick access.
    /// UI/Workflow: Controls badge display and dashboard prominence.
    /// Business: Supports user prioritization and task management.
    /// Analytics: Tracks pinning trends for user behavior insights.
    public var pinned: Bool

    /// Category of the note for filtering, badge display, and analytics.
    /// Audit & Compliance: Enables classification for reporting and filtering.
    /// Analytics: Supports category-based trend analysis and business reporting.
    /// Business: Drives UI badge logic and note grouping.
    /// Future: Prepared for enhanced tagging and encryption schemes.
    public var category: QuickNoteCategory

    /// User identifier who created the note; supports multi-user audit trails.
    /// Audit & Compliance: Essential for user accountability and trust center monitoring.
    /// Analytics: Enables user activity reporting and segmentation.
    /// Business: Supports role-based access and collaboration.
    public var createdBy: String?

    // MARK: - Relationships

    /// Optional weak relationship to a dog owner.
    /// Audit & Compliance: Links note actions to owner entities for traceability.
    /// Analytics: Enables owner-centric reporting and behavioral analysis.
    /// Business: Supports owner-focused dashboards and workflows.
    /// UI/Workflow: Enables contextual display and filtering by owner.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.quickNotes)
    public weak var owner: DogOwner?

    /// Optional weak relationship to a dog.
    /// Audit & Compliance: Associates notes with specific dog records for compliance and history.
    /// Analytics: Supports dog-level analytics and health reporting.
    /// Business: Enables dog-centric workflows and notifications.
    /// UI/Workflow: Facilitates filtering and display in dog profiles.
    @Relationship(deleteRule: .nullify, inverse: \Dog.quickNotes)
    public weak var dog: Dog?

    /// Optional weak relationship to an appointment.
    /// Audit & Compliance: Links notes to appointment events for audit completeness.
    /// Analytics: Enables appointment-related note analysis.
    /// Business: Supports appointment workflows and follow-up actions.
    /// UI/Workflow: Facilitates contextual note display in appointment views.
    @Relationship(deleteRule: .nullify, inverse: \Appointment.quickNotes)
    public weak var appointment: Appointment?

    // MARK: - Computed Properties

    /// Provides a sorting key to order notes by pinned status and most recent access.
    /// UI/Workflow: Enables badge display, dashboard prioritization, and pinning logic.
    /// Business: Supports quick access workflows and user prioritization.
    /// Analytics: Tracks pinning and access patterns for usage insights.
    public var sortingKey: (pinned: Bool, lastAccessedAt: Date) {
        (pinned, lastAccessedAt)
    }

    // MARK: - Initialization

    /// Initializes a new QuickNote with the given parameters.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID.
    ///   - content: Textual content of the note.
    ///   - createdAt: Creation timestamp, defaults to current date.
    ///   - updatedAt: Last updated timestamp, defaults to current date.
    ///   - lastAccessedAt: Last accessed timestamp, defaults to current date.
    ///   - pinned: Whether the note is pinned, defaults to false.
    ///   - category: Category of the note, defaults to `.general`.
    ///   - createdBy: Optional identifier of the user who created the note.
    ///   - owner: Optional linked dog owner.
    ///   - dog: Optional linked dog.
    ///   - appointment: Optional linked appointment.
    public init(
        id: UUID = UUID(),
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
        self.pinned = pinned
        self.category = category
        self.createdBy = createdBy
        self.owner = owner
        self.dog = dog
        self.appointment = appointment
    }

    // MARK: - Methods

    /// Updates the content of the note and refreshes timestamps.
    /// - Parameter newContent: The new textual content for the note.
    /// Audit & Compliance: Records modification events for traceability.
    /// Analytics: Supports content update tracking and engagement metrics.
    /// Business: Enables real-time collaboration and workflow updates.
    /// UI/Workflow: Triggers UI refresh and state updates.
    public func updateContent(_ newContent: String) {
        content = newContent
        updatedAt = Date()
        lastAccessedAt = Date()
    }

    /// Toggles the pinned state of the note and updates timestamps.
    /// Audit & Compliance: Logs pin/unpin events for compliance and monitoring.
    /// Analytics: Tracks user prioritization and pinning trends.
    /// Business: Supports user workflow customization and dashboard display.
    /// UI/Workflow: Updates badge and dashboard states accordingly.
    public func togglePin() {
        pinned.toggle()
        updatedAt = Date()
        lastAccessedAt = Date()
    }

    /// Updates the last accessed timestamp to now.
    /// Audit & Compliance: Captures access events for security and compliance.
    /// Analytics: Measures note usage frequency and relevance.
    /// Business: Supports workflow prioritization and notifications.
    /// UI/Workflow: Ensures UI reflects recent activity.
    public func markAccessed() {
        lastAccessedAt = Date()
    }
}

/// Service responsible for managing QuickNote entities with modularity, auditability, and business analytics.
/// Supports multi-user environments with comprehensive audit trails and tokenized data handling.
/// Implements async operations with robust error propagation for reliable workflows.
/// Designed to facilitate analytics, compliance, and scalable business reporting.
@MainActor
public final class QuickNoteAssistant: ObservableObject {

    // MARK: - Properties

    /// Shared singleton instance for convenience and centralized management.
    public static let shared = QuickNoteAssistant()

    private let context: ModelContext

    // MARK: - Initialization

    /// Initializes the assistant with a given ModelContext.
    /// - Parameter context: The ModelContext to use for data operations.
    /// Enables dependency injection for testing and modularity.
    public init(context: ModelContext = ModelContext()) {
        self.context = context
    }

    // MARK: - Public Methods

    /// Adds a new quick note asynchronously.
    /// - Parameters:
    ///   - content: Textual content of the note.
    ///   - owner: Optional linked dog owner.
    ///   - dog: Optional linked dog.
    ///   - appointment: Optional linked appointment.
    ///   - pinned: Whether the note should be pinned.
    ///   - category: Category of the note.
    ///   - createdBy: Optional identifier of the user creating the note.
    /// - Returns: The newly created QuickNote.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs creation events with user and timestamp.
    /// Analytics: Enables tracking of note creation trends and user activity.
    /// Business: Supports workflow initiation and dashboard updates.
    /// UI/Workflow: Ensures UI reflects new note immediately.
    public func addNote(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil
    ) async throws -> QuickNote {
        let note = QuickNote(
            content: content,
            pinned: pinned,
            category: category,
            createdBy: createdBy,
            owner: owner,
            dog: dog,
            appointment: appointment
        )
        context.insert(note)
        try await saveContext()
        auditLog(action: "Add Note", note: note)
        return note
    }

    /// Adds a new quick note synchronously.
    /// - Parameters:
    ///   - content: Textual content of the note.
    ///   - owner: Optional linked dog owner.
    ///   - dog: Optional linked dog.
    ///   - appointment: Optional linked appointment.
    ///   - pinned: Whether the note should be pinned.
    ///   - category: Category of the note.
    ///   - createdBy: Optional identifier of the user creating the note.
    /// - Returns: The newly created QuickNote.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs creation events with user and timestamp.
    /// Analytics: Enables tracking of note creation trends and user activity.
    /// Business: Supports workflow initiation and dashboard updates.
    /// UI/Workflow: Ensures UI reflects new note immediately.
    public func addNote(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil
    ) throws -> QuickNote {
        let note = QuickNote(
            content: content,
            pinned: pinned,
            category: category,
            createdBy: createdBy,
            owner: owner,
            dog: dog,
            appointment: appointment
        )
        context.insert(note)
        try saveContextSync()
        auditLog(action: "Add Note", note: note)
        return note
    }

    /// Fetches quick notes optionally filtered by owner, dog, appointment, or category.
    /// - Parameters:
    ///   - owner: Optional dog owner filter.
    ///   - dog: Optional dog filter.
    ///   - appointment: Optional appointment filter.
    ///   - category: Optional category filter.
    /// - Returns: An array of QuickNote objects sorted by pinned status and last accessed date.
    /// Audit & Compliance: Supports filtered retrieval for compliance reporting.
    /// Analytics: Enables segmented data analysis and trend reporting.
    /// Business: Supports dashboard and workflow filtering.
    /// UI/Workflow: Provides filtered data for contextual display.
    /// - Throws: Propagates errors from fetch operations.
    public func fetchNotes(
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        category: QuickNoteCategory? = nil
    ) throws -> [QuickNote] {
        let fetchDescriptor = FetchDescriptor<QuickNote>()
        let notes = try context.fetch(fetchDescriptor)

        return notes.filter { note in
            (owner == nil || note.owner?.id == owner?.id) &&
            (dog == nil || note.dog?.id == dog?.id) &&
            (appointment == nil || note.appointment?.id == appointment?.id) &&
            (category == nil || note.category == category!)
        }
        .sorted {
            if $0.pinned == $1.pinned {
                return $0.lastAccessedAt > $1.lastAccessedAt
            }
            return $0.pinned && !$1.pinned
        }
    }

    /// Convenience fetch method for pinned notes only.
    /// - Returns: An array of pinned QuickNote objects sorted by last accessed date.
    /// Audit & Compliance: Facilitates retrieval of high-priority notes.
    /// Analytics: Enables analysis of pinned note usage and trends.
    /// Business: Supports dashboard pinning workflows and UI badge display.
    /// UI/Workflow: Provides prioritized notes for quick user access.
    /// - Throws: Propagates errors from fetch operations.
    public func fetchPinnedNotes() throws -> [QuickNote] {
        try fetchNotes(category: nil)
            .filter { $0.pinned }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    /// Updates the content of a note asynchronously.
    /// - Parameters:
    ///   - note: The QuickNote to update.
    ///   - newContent: The new content string.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs content updates with user and timestamp.
    /// Analytics: Tracks modification frequency and engagement.
    /// Business: Supports collaborative editing workflows.
    /// UI/Workflow: Triggers UI refresh and state management.
    public func updateNote(
        _ note: QuickNote,
        newContent: String
    ) async throws {
        note.updateContent(newContent)
        try await saveContext()
        auditLog(action: "Update Note Content", note: note)
    }

    /// Updates the content of a note synchronously.
    /// - Parameters:
    ///   - note: The QuickNote to update.
    ///   - newContent: The new content string.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs content updates with user and timestamp.
    /// Analytics: Tracks modification frequency and engagement.
    /// Business: Supports collaborative editing workflows.
    /// UI/Workflow: Triggers UI refresh and state management.
    public func updateNote(
        _ note: QuickNote,
        newContent: String
    ) throws {
        note.updateContent(newContent)
        try saveContextSync()
        auditLog(action: "Update Note Content", note: note)
    }

    /// Toggles the pinned state of a note asynchronously.
    /// - Parameter note: The QuickNote to toggle pin.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Records pin/unpin actions for monitoring.
    /// Analytics: Supports analysis of user prioritization behavior.
    /// Business: Enables customized workflow and dashboard display.
    /// UI/Workflow: Updates UI badges and note prominence.
    public func togglePin(
        _ note: QuickNote
    ) async throws {
        note.togglePin()
        try await saveContext()
        auditLog(action: "Toggle Pin", note: note)
    }

    /// Toggles the pinned state of a note synchronously.
    /// - Parameter note: The QuickNote to toggle pin.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Records pin/unpin actions for monitoring.
    /// Analytics: Supports analysis of user prioritization behavior.
    /// Business: Enables customized workflow and dashboard display.
    /// UI/Workflow: Updates UI badges and note prominence.
    public func togglePin(
        _ note: QuickNote
    ) throws {
        note.togglePin()
        try saveContextSync()
        auditLog(action: "Toggle Pin", note: note)
    }

    /// Deletes a note asynchronously.
    /// - Parameter note: The QuickNote to delete.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs deletion events for traceability and compliance.
    /// Analytics: Tracks deletion trends and user behavior.
    /// Business: Supports cleanup workflows and data lifecycle management.
    /// UI/Workflow: Removes note from UI and updates state.
    public func deleteNote(
        _ note: QuickNote
    ) async throws {
        context.delete(note)
        try await saveContext()
        auditLog(action: "Delete Note", note: note)
    }

    /// Deletes a note synchronously.
    /// - Parameter note: The QuickNote to delete.
    /// - Throws: Propagates errors from context save operations.
    /// Audit & Compliance: Logs deletion events for traceability and compliance.
    /// Analytics: Tracks deletion trends and user behavior.
    /// Business: Supports cleanup workflows and data lifecycle management.
    /// UI/Workflow: Removes note from UI and updates state.
    public func deleteNote(
        _ note: QuickNote
    ) throws {
        context.delete(note)
        try saveContextSync()
        auditLog(action: "Delete Note", note: note)
    }

    // MARK: - Private Helpers

    /// Saves the ModelContext asynchronously.
    /// - Throws: Propagates errors from the save operation.
    private func saveContext() async throws {
        try await context.save()
    }

    /// Saves the ModelContext synchronously.
    /// - Throws: Propagates errors from the save operation.
    private func saveContextSync() throws {
        try context.save()
    }

    /// Stub for audit logging of note changes.
    /// Intended for integration with audit trails, compliance reporting, analytics, and Trust Center event monitoring.
    /// Captures critical user actions, timestamps, and note identifiers to support trustworthy data governance.
    /// - Parameters:
    ///   - action: Description of the action performed.
    ///   - note: The QuickNote involved in the action.
    private func auditLog(action: String, note: QuickNote) {
        // TODO: Implement audit trail logging integration here.
        // Example: AuditLogger.log(user: note.createdBy, action: action, noteId: note.id, timestamp: Date())
        print("[AuditLog] Action: \(action), Note ID: \(note.id), User: \(note.createdBy ?? "Unknown"), Timestamp: \(Date())")
    }
}
