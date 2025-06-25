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
///
/// Extension points:
/// - UI: Integrate with badge/category logic and apply design tokens for color, typography, and spacing.
///   // TODO: Apply design tokens to badge/category UI logic when presenting notes in the UI.
///   // TODO: If any user-facing string is displayed in badge/category or error reporting, localize all such strings.
/// - Logging: Extend for centralized logging (see auditLog) and diagnostics.
/// - Analytics: Extend for business analytics and Trust Center event reporting.
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

/**
 QuickNoteAssistant
 ==================
 Service responsible for managing QuickNote entities with modularity, auditability, and business analytics.
 Supports multi-user environments with comprehensive audit trails and tokenized data handling.
 Implements async operations with robust error propagation for reliable workflows.
 Designed to facilitate analytics, compliance, and scalable business reporting.
 
 Extension points:
 - UI: Extend for business dashboards, filtering, and localized error/status reporting.
   // TODO: Localize any user-facing strings in future UI logic (e.g., badge/category labels, error reporting).
 - Logging: When a centralized logger (e.g., AppLogger or diagnostics engine) is introduced, migrate auditLog to use it.
 - Analytics: Integrate with Trust Center and business analytics platforms for event reporting.

 ## Concurrency & SwiftData Compatibility
 - All async methods are marked `@MainActor` to ensure SwiftUI/SwiftData safety.
 - All context usages are private; use the provided getter for debugging.
 - Only call async methods from the main thread or SwiftUI views.

 ## Dependency Injection & Testing
 - Use `QuickNoteAssistant.shared` for production.
 - For testing/previews, you may inject a testable ModelContext via `init(context:)`.
 - Use `QuickNoteAssistant.shared(with:)` to obtain a shared assistant using a custom context.

 ## Audit Logging & Analytics
 - All create, update, pin, and delete actions trigger audit logging.
 - You may plug in an external logger/analytics via the `externalAuditHandler` closure.
 - // TODO: Log audit events to Trust Center or business analytics platform, not just via print/externalAuditHandler.

 ## Fetching & Sorting
 - Fetch methods use SwiftData predicates for performance.
 - Supports sorting by pinned, created, updated, and accessed date.
 - `fetchAllNotes` returns all notes.
   // TODO: Add paging support or additional filtering as needed for large datasets.
*/
@MainActor
public final class QuickNoteAssistant: ObservableObject {

    // MARK: - Properties

    /// Shared singleton instance for convenience and centralized management.
    public static let shared: QuickNoteAssistant = {
        QuickNoteAssistant()
    }()

    /// Returns a shared assistant using the provided context (for previews/tests), or the standard context.
    public static func shared(with context: ModelContext) -> QuickNoteAssistant {
        // Always returns a new instance with the given context (for testability).
        QuickNoteAssistant(context: context)
    }

    /// The ModelContext used for all operations. Private for encapsulation.
    private let context: ModelContext

    /// Optional external audit/analytics closure, called on every create, update, pin, or delete.
    /// Hook for analytics, logging, or event reporting.
    public var externalAuditHandler: ((_ action: String, _ note: QuickNote) -> Void)?

    // MARK: - Initialization

    /// Initializes the assistant with a given ModelContext.
    /// - Parameter context: The ModelContext to use for data operations.
    /// Enables dependency injection for testing and modularity.
    public init(context: ModelContext = ModelContext()) {
        self.context = context
    }

    /// Returns the current ModelContext (for debugging/inspection only).
    public var currentContext: ModelContext { context }

    // MARK: - Public Methods

    /// Adds a new quick note asynchronously. (MainActor)
    /// - Parameters: See sync version.
    /// - Returns: The newly created QuickNote.
    /// - Throws: Propagates errors from context save operations.
    /// - Audit/Analytics: Triggers audit logging and external handler.
    @MainActor
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

    /// Fetches quick notes optionally filtered and sorted.
    /// - Parameters:
    ///   - owner: Optional dog owner filter.
    ///   - dog: Optional dog filter.
    ///   - appointment: Optional appointment filter.
    ///   - category: Optional category filter.
    ///   - sortBy: Sorting criteria (`pinned`, `createdAt`, `updatedAt`, `lastAccessedAt`).
    ///   - ascending: Sort order (default: descending for dates, pinned first).
    /// - Returns: Array of QuickNote objects.
    /// - Throws: Propagates errors from fetch operations.
    public func fetchNotes(
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        category: QuickNoteCategory? = nil,
        sortBy: QuickNoteSort = .pinnedThenAccessed,
        ascending: Bool? = nil
    ) throws -> [QuickNote] {
        var predicates: [Predicate<QuickNote>] = []
        if let owner = owner {
            predicates.append(#Predicate { $0.owner?.id == owner.id })
        }
        if let dog = dog {
            predicates.append(#Predicate { $0.dog?.id == dog.id })
        }
        if let appointment = appointment {
            predicates.append(#Predicate { $0.appointment?.id == appointment.id })
        }
        if let category = category {
            predicates.append(#Predicate { $0.category == category })
        }
        let predicate: Predicate<QuickNote>? = predicates.isEmpty ? nil :
            predicates.dropFirst().reduce(predicates.first!) { $0 && $1 }

        let sortDescriptors: [SortDescriptor<QuickNote>]
        switch sortBy {
        case .pinnedThenAccessed:
            // Pinned first, then by lastAccessedAt descending.
            sortDescriptors = [
                SortDescriptor(\.pinned, order: .reverse),
                SortDescriptor(\.lastAccessedAt, order: .reverse)
            ]
        case .createdAt:
            sortDescriptors = [
                SortDescriptor(\.createdAt, order: ascending == true ? .forward : .reverse)
            ]
        case .updatedAt:
            sortDescriptors = [
                SortDescriptor(\.updatedAt, order: ascending == true ? .forward : .reverse)
            ]
        case .lastAccessedAt:
            sortDescriptors = [
                SortDescriptor(\.lastAccessedAt, order: ascending == true ? .forward : .reverse)
            ]
        case .pinnedOnly:
            sortDescriptors = [
                SortDescriptor(\.pinned, order: .reverse)
            ]
        }

        let fetchDescriptor = FetchDescriptor<QuickNote>(
            predicate: predicate,
            sortBy: sortDescriptors
        )
        return try context.fetch(fetchDescriptor)
    }

    /// Fetches all notes, optionally paged (future).
    /// - Returns: All QuickNote objects.
    /// - Throws: Propagates errors from fetch operations.
    public func fetchAllNotes() throws -> [QuickNote] {
        // TODO: Add paging support or additional filtering for large datasets.
        try fetchNotes()
    }

    /// Convenience fetch method for pinned notes only.
    /// - Returns: An array of pinned QuickNote objects sorted by last accessed date.
    /// Audit & Compliance: Facilitates retrieval of high-priority notes.
    /// Analytics: Enables analysis of pinned note usage and trends.
    /// Business: Supports dashboard pinning workflows and UI badge display.
    /// UI/Workflow: Provides prioritized notes for quick user access.
    /// - Throws: Propagates errors from fetch operations.
    public func fetchPinnedNotes() throws -> [QuickNote] {
        try fetchNotes(sortBy: .pinnedThenAccessed).filter { $0.pinned }
    }

    /// Updates the content of a note asynchronously. (MainActor)
    /// - Parameters: See sync version.
    /// - Throws: Propagates errors from context save operations.
    /// - Audit/Analytics: Triggers audit logging and external handler.
    @MainActor
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

    /// Toggles the pinned state of a note asynchronously. (MainActor)
    /// - Parameter note: The QuickNote to toggle pin.
    /// - Throws: Propagates errors from context save operations.
    /// - Audit/Analytics: Triggers audit logging and external handler.
    @MainActor
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

    /// Deletes a note asynchronously. (MainActor)
    /// - Parameter note: The QuickNote to delete.
    /// - Throws: Propagates errors from context save operations.
    /// - Audit/Analytics: Triggers audit logging and external handler.
    @MainActor
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

    /// Handles audit logging and triggers the external audit/analytics hook if provided.
    /// - Parameters:
    ///   - action: Description of the action performed.
    ///   - note: The QuickNote involved in the action.
    private func auditLog(action: String, note: QuickNote) {
        // Internal audit log (can be replaced with a real logger)
        // TODO: Migrate to centralized AppLogger or diagnostics engine when available.
        // TODO: Log audit events to Trust Center or business analytics platform, not just via print/externalAuditHandler.
        print("[AuditLog] Action: \(action), Note ID: \(note.id), User: \(note.createdBy ?? "Unknown"), Timestamp: \(Date())")
        // Call external audit/analytics handler if provided
        externalAuditHandler?(action, note)
    }
}

/// Sorting options for QuickNote fetches.
public enum QuickNoteSort {
    case pinnedThenAccessed
    case createdAt
    case updatedAt
    case lastAccessedAt
    case pinnedOnly
}

// MARK: - Audit Logging Protocol for DI

public protocol AuditLogger {
    func log(action: String, note: QuickNote, actor: String?, businessID: String?)
}

/// A no-op audit logger (default for previews/tests)
public struct NullAuditLogger: AuditLogger {
    public init() {}
    public func log(action: String, note: QuickNote, actor: String?, businessID: String?) { }
}

// MARK: - QuickNoteAssistant

@MainActor
public final class QuickNoteAssistant: ObservableObject {
    // MARK: - Published for UI
    @Published public private(set) var lastActionStatus: QuickNoteActionStatus?
    @Published public private(set) var diagnosticsSummary: String = ""
    
    // MARK: - Dependencies (DI)
    private let context: ModelContext
    private let auditLogger: AuditLogger
    private let businessID: String?

    /// Notification name for cross-module updates (widgets, dashboards, etc).
    public static let notesDidChangeNotification = Notification.Name("QuickNoteAssistantNotesDidChange")
    
    // MARK: - Init (Inject for test/preview)
    public init(
        context: ModelContext = ModelContext(),
        auditLogger: AuditLogger = NullAuditLogger(),
        businessID: String? = nil
    ) {
        self.context = context
        self.auditLogger = auditLogger
        self.businessID = businessID
    }
    
    // MARK: - Diagnostics Snapshot
    /// Returns a summary of note health for admin dashboards.
    public func diagnosticsSnapshot() -> [String: Any] {
        var result: [String: Any] = [:]
        do {
            let all = try fetchAllNotes()
            result["totalNotes"] = all.count
            result["pinnedNotes"] = all.filter { $0.pinned }.count
            result["recentlyUpdated"] = all.filter { $0.updatedAt > Date().addingTimeInterval(-7*86400) }.count
            result["orphans"] = all.filter { $0.owner == nil && $0.dog == nil && $0.appointment == nil }.count
            result["categories"] = Dictionary(grouping: all, by: { $0.category }).mapValues { $0.count }
        } catch {
            result["error"] = error.localizedDescription
        }
        return result
    }
    
    // MARK: - Diagnostics Summary
    private func updateDiagnosticsSummary() {
        let snap = diagnosticsSnapshot()
        diagnosticsSummary = "Notes: \(snap["totalNotes"] ?? 0), Pinned: \(snap["pinnedNotes"] ?? 0), Orphans: \(snap["orphans"] ?? 0)"
    }

    // MARK: - Note Actions

    /// Adds a new note (async).
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
        auditLogger.log(action: "Add", note: note, actor: createdBy, businessID: businessID)
        notifyChange()
        lastActionStatus = .success(message: NSLocalizedString("Note created.", comment: "Quick note created"))
        updateDiagnosticsSummary()
        return note
    }
    
    /// Adds a note (sync, thin wrapper)
    public func addNote(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil
    ) throws -> QuickNote {
        try awaitResult { try await self.addNote(content: content, owner: owner, dog: dog, appointment: appointment, pinned: pinned, category: category, createdBy: createdBy) }
    }

    /// Updates note content (async)
    public func updateNote(
        _ note: QuickNote,
        newContent: String,
        updatedBy: String? = nil
    ) async throws {
        note.updateContent(newContent)
        try await saveContext()
        auditLogger.log(action: "Update Content", note: note, actor: updatedBy, businessID: businessID)
        notifyChange()
        lastActionStatus = .success(message: NSLocalizedString("Note updated.", comment: "Quick note updated"))
        updateDiagnosticsSummary()
    }
    
    /// Updates note content (sync)
    public func updateNote(
        _ note: QuickNote,
        newContent: String,
        updatedBy: String? = nil
    ) throws {
        try awaitResult { try await self.updateNote(note, newContent: newContent, updatedBy: updatedBy) }
    }

    /// Toggles pin (async)
    public func togglePin(
        _ note: QuickNote,
        actor: String? = nil
    ) async throws {
        note.togglePin()
        try await saveContext()
        auditLogger.log(action: "Toggle Pin", note: note, actor: actor, businessID: businessID)
        notifyChange()
        lastActionStatus = .success(message: NSLocalizedString("Pin toggled.", comment: "Note pin toggled"))
        updateDiagnosticsSummary()
    }
    
    /// Toggles pin (sync)
    public func togglePin(
        _ note: QuickNote,
        actor: String? = nil
    ) throws {
        try awaitResult { try await self.togglePin(note, actor: actor) }
    }

    /// Deletes note (async)
    public func deleteNote(
        _ note: QuickNote,
        actor: String? = nil
    ) async throws {
        context.delete(note)
        try await saveContext()
        auditLogger.log(action: "Delete", note: note, actor: actor, businessID: businessID)
        notifyChange()
        lastActionStatus = .success(message: NSLocalizedString("Note deleted.", comment: "Note deleted"))
        updateDiagnosticsSummary()
    }
    
    /// Deletes note (sync)
    public func deleteNote(
        _ note: QuickNote,
        actor: String? = nil
    ) throws {
        try awaitResult { try await self.deleteNote(note, actor: actor) }
    }
    
    // MARK: - Fetching

    public func fetchNotes(
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        category: QuickNoteCategory? = nil,
        sortBy: QuickNoteSort = .pinnedThenAccessed,
        ascending: Bool? = nil
    ) throws -> [QuickNote] {
        var predicates: [Predicate<QuickNote>] = []
        if let owner = owner { predicates.append(#Predicate { $0.owner?.id == owner.id }) }
        if let dog = dog { predicates.append(#Predicate { $0.dog?.id == dog.id }) }
        if let appointment = appointment { predicates.append(#Predicate { $0.appointment?.id == appointment.id }) }
        if let category = category { predicates.append(#Predicate { $0.category == category }) }
        let predicate: Predicate<QuickNote>? = predicates.isEmpty ? nil : predicates.dropFirst().reduce(predicates.first!) { $0 && $1 }

        let sortDescriptors: [SortDescriptor<QuickNote>]
        switch sortBy {
        case .pinnedThenAccessed:
            sortDescriptors = [SortDescriptor(\.pinned, order: .reverse), SortDescriptor(\.lastAccessedAt, order: .reverse)]
        case .createdAt:
            sortDescriptors = [SortDescriptor(\.createdAt, order: ascending == true ? .forward : .reverse)]
        case .updatedAt:
            sortDescriptors = [SortDescriptor(\.updatedAt, order: ascending == true ? .forward : .reverse)]
        case .lastAccessedAt:
            sortDescriptors = [SortDescriptor(\.lastAccessedAt, order: ascending == true ? .forward : .reverse)]
        case .pinnedOnly:
            sortDescriptors = [SortDescriptor(\.pinned, order: .reverse)]
        }
        let fetchDescriptor = FetchDescriptor<QuickNote>(predicate: predicate, sortBy: sortDescriptors)
        return try context.fetch(fetchDescriptor)
    }

    public func fetchAllNotes() throws -> [QuickNote] {
        try fetchNotes()
    }

    public func fetchPinnedNotes() throws -> [QuickNote] {
        try fetchNotes(sortBy: .pinnedThenAccessed).filter { $0.pinned }
    }
    
    // MARK: - Private Helpers
    
    private func saveContext() async throws {
        try await context.save()
    }
    private func saveContextSync() throws {
        try context.save()
    }
    private func notifyChange() {
        objectWillChange.send()
        NotificationCenter.default.post(name: Self.notesDidChangeNotification, object: nil)
    }
    /// Helper: Await sync wrapper for async calls
    private func awaitResult<T>(_ block: @escaping () async throws -> T) throws -> T {
        var result: Result<T, Error>?
        let group = DispatchGroup()
        group.enter()
        Task {
            defer { group.leave() }
            do { result = .success(try await block()) }
            catch { result = .failure(error) }
        }
        group.wait()
        switch result {
            case .success(let value): return value
            case .failure(let error): throw error
            case .none: fatalError("Async result not set")
        }
    }
}

// MARK: - Action Status for UI

public enum QuickNoteActionStatus {
    case success(message: String)
    case failure(error: Error, message: String)
}
