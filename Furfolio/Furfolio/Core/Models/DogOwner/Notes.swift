//
//  Notes.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Note Model

@Model
public struct Note: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var dateCreated: Date
    var dateModified: Date?
    var author: String
    var context: String?      // e.g. "Owner", "Pet", "Appointment"
    var tags: [String]        // for filtering/analytics
    var isPinned: Bool        // for favorites or highlights

    init(
        id: UUID = UUID(),
        text: String,
        dateCreated: Date = Date(),
        dateModified: Date? = nil,
        author: String,
        context: String? = nil,
        tags: [String] = [],
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.author = author
        self.context = context
        self.tags = tags
        self.isPinned = isPinned
    }
}

// MARK: - Example Usage

#if DEBUG
extension Note {
    static let example = Note(
        text: "Met with client, discussed grooming plan.",
        dateCreated: Date(),
        author: "Admin",
        context: "Owner",
        tags: ["important", "meeting"],
        isPinned: true
    )
    static let batch: [Note] = [
        Note.example,
        Note(
            text: "Called owner for appointment confirmation.",
            dateCreated: Date().addingTimeInterval(-3600 * 24),
            author: "Staff1",
            context: "Owner",
            tags: ["call"],
            isPinned: false
        ),
        Note(
            text: "Dog showed improvement in coat condition.",
            dateCreated: Date().addingTimeInterval(-3600 * 48),
            author: "Groomer2",
            context: "Pet",
            tags: ["health"],
            isPinned: false
        )
    ]
}
#endif

// MARK: - Notes CRUD & Management

final class NoteManager: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var lastDeleted: (note: Note, index: Int)?
    @Published var showUndo: Bool = false

    // Add a note asynchronously, recording audit log safely.
    func add(_ note: Note) async {
        notes.append(note)
        do {
            try await NoteAudit.record(action: "Add", note: note)
        } catch {
            // Handle audit logging error if needed
            print("Audit log failed on add: \(error)")
        }
        await save()
    }

    // Edit a note asynchronously, recording audit log safely.
    func edit(_ updated: Note) async {
        if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
            notes[idx] = updated
            do {
                try await NoteAudit.record(action: "Edit", note: updated)
            } catch {
                print("Audit log failed on edit: \(error)")
            }
            await save()
        }
    }

    // Delete a note asynchronously with undo support, recording audit log safely.
    func delete(_ note: Note) async {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            lastDeleted = (notes[idx], idx)
            notes.remove(at: idx)
            do {
                try await NoteAudit.record(action: "Delete", note: note)
            } catch {
                print("Audit log failed on delete: \(error)")
            }
            showUndo = true
            await save()
        }
    }

    // Undo last delete asynchronously, recording audit log safely.
    func undoDelete() async {
        if let last = lastDeleted {
            notes.insert(last.note, at: last.index)
            do {
                try await NoteAudit.record(action: "UndoDelete", note: last.note)
            } catch {
                print("Audit log failed on undoDelete: \(error)")
            }
            lastDeleted = nil
            showUndo = false
            await save()
        }
    }

    // Pin/unpin note asynchronously, recording audit log safely.
    func togglePin(_ note: Note) async {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isPinned.toggle()
            let actionKey = notes[idx].isPinned ? "Pin" : "Unpin"
            do {
                try await NoteAudit.record(action: actionKey, note: notes[idx])
            } catch {
                print("Audit log failed on togglePin: \(error)")
            }
            await save()
        }
    }

    // Example async stubs for cloud/SwiftData persistence
    /// Asynchronously load notes from storage or cloud.
    func load() async {
        // Placeholder for async load implementation
        // self.notes = ...
    }

    /// Asynchronously save notes to storage or cloud.
    func save() async {
        // Placeholder for async save implementation
    }

    // MARK: - Backward compatibility synchronous wrappers

    /// Synchronous wrapper for add.
    func addSync(_ note: Note) {
        Task {
            await add(note)
        }
    }

    /// Synchronous wrapper for edit.
    func editSync(_ updated: Note) {
        Task {
            await edit(updated)
        }
    }

    /// Synchronous wrapper for delete.
    func deleteSync(_ note: Note) {
        Task {
            await delete(note)
        }
    }

    /// Synchronous wrapper for undoDelete.
    func undoDeleteSync() {
        Task {
            await undoDelete()
        }
    }

    /// Synchronous wrapper for togglePin.
    func togglePinSync(_ note: Note) {
        Task {
            await togglePin(note)
        }
    }
}

// MARK: - Notes Audit/Event Logging

/// Represents a single audit event for note operations.
struct NoteAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let noteID: UUID
    let summary: String

    /// Initializes an audit event with localized summary.
    /// - Parameters:
    ///   - action: The action performed on the note.
    ///   - note: The note involved in the action.
    init(action: String, note: Note) {
        self.timestamp = Date()
        self.action = action
        self.noteID = note.id

        let actionLocalized = NSLocalizedString(action, comment: "Note audit action")
        let prefixText = note.text.prefix(32)
        let authorLocalized = NSLocalizedString(note.author, comment: "Note author")
        let dateString = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)

        self.summary = String(
            format: NSLocalizedString("[Note] %@: '%@...' by %@ at %@", comment: "Audit event summary format"),
            actionLocalized,
            prefixText,
            authorLocalized,
            dateString
        )
    }
}

/// Actor to manage concurrency-safe audit log operations.
actor NoteAudit {
    private static var log: [NoteAuditEvent] = []

    /// Records an audit event asynchronously.
    /// - Parameters:
    ///   - action: The action performed on the note.
    ///   - note: The note involved.
    /// - Throws: An error if logging fails (currently unused, placeholder).
    static func record(action: String, note: Note) async throws {
        let event = NoteAuditEvent(action: action, note: note)
        await self.append(event: event)
    }

    /// Appends an event to the log in a concurrency-safe manner.
    /// - Parameter event: The audit event to append.
    private static func append(event: NoteAuditEvent) {
        log.append(event)
        if log.count > 80 {
            log.removeFirst()
        }
    }

    /// Returns recent audit summaries asynchronously.
    /// - Parameter limit: The maximum number of summaries to return.
    /// - Returns: An array of audit summary strings.
    static func recentSummaries(limit: Int = 6) async -> [String] {
        Array(log.suffix(limit).map(\.summary))
    }

    // MARK: - Backward compatibility synchronous wrappers

    /// Synchronous wrapper for record (fire-and-forget).
    static func recordSync(action: String, note: Note) {
        Task {
            try? await record(action: action, note: note)
        }
    }

    /// Synchronous wrapper for recentSummaries.
    static func recentSummariesSync(limit: Int = 6) -> [String] {
        // Warning: This is not concurrency safe if called from multiple threads.
        // Prefer using recentSummaries(limit:) async.
        return Array(log.suffix(limit).map(\.summary))
    }
}

/// Administrative interface for note audit logs.
public enum NoteAuditAdmin {
    /// Retrieves recent audit event summaries asynchronously.
    /// - Parameter limit: Maximum number of events to retrieve.
    /// - Returns: Array of summary strings.
    public static func recentEvents(limit: Int = 6) async -> [String] {
        await NoteAudit.recentSummaries(limit: limit)
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async audit logging

#if DEBUG
struct NoteAuditPreviewView: View {
    @StateObject private var manager = NoteManager()
    @State private var auditSummaries: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audit Log Summaries")
                .font(.headline)
            List(auditSummaries, id: \.self) { summary in
                Text(summary)
                    .accessibilityLabel(Text(summary))
            }
            Button("Add Example Note and Log Audit") {
                Task {
                    let newNote = Note(
                        text: "Preview note for audit logging.",
                        author: "PreviewUser"
                    )
                    await manager.add(newNote)
                    auditSummaries = await NoteAudit.recentSummaries()
                }
            }
            .padding(.top)
        }
        .padding()
        .task {
            auditSummaries = await NoteAudit.recentSummaries()
        }
    }
}

struct NoteAuditPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NoteAuditPreviewView()
    }
}
#endif
