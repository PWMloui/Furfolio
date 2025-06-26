//
//  Notes.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import Foundation

// MARK: - Note Model

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
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

    // Add a note
    func add(_ note: Note) {
        notes.append(note)
        NoteAudit.record(action: "Add", note: note)
        save()
    }

    // Edit a note
    func edit(_ updated: Note) {
        if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
            notes[idx] = updated
            NoteAudit.record(action: "Edit", note: updated)
            save()
        }
    }

    // Delete a note (with undo)
    func delete(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            lastDeleted = (notes[idx], idx)
            notes.remove(at: idx)
            NoteAudit.record(action: "Delete", note: note)
            showUndo = true
            save()
        }
    }

    // Undo last delete
    func undoDelete() {
        if let last = lastDeleted {
            notes.insert(last.note, at: last.index)
            NoteAudit.record(action: "UndoDelete", note: last.note)
            lastDeleted = nil
            showUndo = false
            save()
        }
    }

    // Pin/unpin note
    func togglePin(_ note: Note) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isPinned.toggle()
            let action = notes[idx].isPinned ? "Pin" : "Unpin"
            NoteAudit.record(action: action, note: notes[idx])
            save()
        }
    }

    // Example stubs for cloud/SwiftData persistence
    func load() {
        // Load notes from storage/cloud
        // self.notes = ...
    }

    func save() {
        // Save notes to storage/cloud
    }
}

// MARK: - Notes Audit/Event Logging

struct NoteAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let noteID: UUID
    let summary: String

    init(action: String, note: Note) {
        self.timestamp = Date()
        self.action = action
        self.noteID = note.id
        self.summary = "[Note] \(action): '\(note.text.prefix(32))...' by \(note.author) at \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short))"
    }
}

final class NoteAudit {
    static private(set) var log: [NoteAuditEvent] = []

    static func record(action: String, note: Note) {
        let event = NoteAuditEvent(action: action, note: note)
        log.append(event)
        if log.count > 80 { log.removeFirst() }
    }

    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map(\.summary)
    }
}
public enum NoteAuditAdmin {
    public static func recentEvents(limit: Int = 6) -> [String] { NoteAudit.recentSummaries(limit: limit) }
}
