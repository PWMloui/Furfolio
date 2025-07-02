//
//  QuickNoteAssistant.swift
//  Furfolio
//
//  Enhanced 2025: Audit/analytics-ready, role-aware, testable, business-compliant
//

import Foundation
import SwiftData

// MARK: - Audit/Analytics Protocols

public protocol QuickNoteAuditLogger {
    func log(event: QuickNoteAuditEvent)
}

public enum QuickNoteAuditEvent {
    case add(note: QuickNote, user: String, role: String?, timestamp: Date)
    case update(note: QuickNote, user: String, role: String?, before: QuickNote, after: QuickNote, timestamp: Date)
    case pinToggle(note: QuickNote, user: String, role: String?, before: Bool, after: Bool, timestamp: Date)
    case delete(note: QuickNote, user: String, role: String?, before: QuickNote, timestamp: Date)
    case error(noteID: UUID?, message: String, user: String?, role: String?, timestamp: Date)
    // Add .access or .search for analytics if desired
}

public protocol QuickNoteRoleProvider {
    var currentUser: String? { get }
    var currentRole: String? { get }
}
public struct DefaultQuickNoteRoleProvider: QuickNoteRoleProvider {
    public var currentUser: String? { nil }
    public var currentRole: String? { nil }
    public init() {}
}

// MARK: - QuickNoteAssistant

@MainActor
public final class QuickNoteAssistant: ObservableObject {
    // MARK: - Singleton & Initialization

    public static let shared = QuickNoteAssistant()

    public static func shared(with context: ModelContext) -> QuickNoteAssistant {
        QuickNoteAssistant(context: context)
    }

    private let context: ModelContext
    public var testMode: Bool = false
    public var auditLogger: QuickNoteAuditLogger?
    public var roleProvider: QuickNoteRoleProvider = DefaultQuickNoteRoleProvider()

    public init(context: ModelContext = ModelContext()) {
        self.context = context
    }

    // MARK: - CRUD (Sync)

    public func addNote(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil,
        tags: [String] = []
    ) throws -> QuickNote {
        let user = createdBy ?? roleProvider.currentUser ?? "Unknown"
        let role = roleProvider.currentRole
        let note = QuickNote(content: content, pinned: pinned, category: category, createdBy: user, tags: Array(tags.prefix(3)), owner: owner, dog: dog, appointment: appointment)
        context.insert(note)
        if !testMode {
            try context.save()
        }
        auditLogger?.log(event: .add(note: note, user: user, role: role, timestamp: Date()))
        return note
    }

    public func updateNote(_ note: QuickNote, newContent: String) throws {
        let user = note.createdBy ?? roleProvider.currentUser ?? "Unknown"
        let role = roleProvider.currentRole
        let beforeSnapshot = snapshot(note)
        note.updateContent(newContent)
        if !testMode {
            try context.save()
        }
        auditLogger?.log(event: .update(note: note, user: user, role: role, before: beforeSnapshot, after: snapshot(note), timestamp: Date()))
    }

    public func togglePin(_ note: QuickNote) throws {
        let user = note.createdBy ?? roleProvider.currentUser ?? "Unknown"
        let role = roleProvider.currentRole
        let beforePinned = note.pinned
        note.togglePin()
        if !testMode {
            try context.save()
        }
        auditLogger?.log(event: .pinToggle(note: note, user: user, role: role, before: beforePinned, after: note.pinned, timestamp: Date()))
    }

    public func deleteNote(_ note: QuickNote) throws {
        let user = note.createdBy ?? roleProvider.currentUser ?? "Unknown"
        let role = roleProvider.currentRole
        let beforeSnapshot = snapshot(note)
        if !testMode {
            context.delete(note)
            try context.save()
        }
        auditLogger?.log(event: .delete(note: note, user: user, role: role, before: beforeSnapshot, timestamp: Date()))
    }

    // MARK: - CRUD (Async)

    public func addNoteAsync(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil,
        tags: [String] = []
    ) async throws -> QuickNote {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let note = try addNote(content: content, owner: owner, dog: dog, appointment: appointment, pinned: pinned, category: category, createdBy: createdBy, tags: tags)
                continuation.resume(returning: note)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func updateNoteAsync(_ note: QuickNote, newContent: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try updateNote(note, newContent: newContent)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func togglePinAsync(_ note: QuickNote) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try togglePin(note)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func deleteNoteAsync(_ note: QuickNote) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try deleteNote(note)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Fetching

    public func fetchNotes(
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        category: QuickNoteCategory? = nil,
        sortBy: QuickNoteSort = .pinnedThenAccessed
    ) throws -> [QuickNote] {
        var predicates: [Predicate<QuickNote>] = []
        if let owner { predicates.append(#Predicate { $0.owner?.id == owner.id }) }
        if let dog { predicates.append(#Predicate { $0.dog?.id == dog.id }) }
        if let appointment { predicates.append(#Predicate { $0.appointment?.id == appointment.id }) }
        if let category { predicates.append(#Predicate { $0.category == category }) }
        let predicate = predicates.isEmpty ? nil : predicates.dropFirst().reduce(predicates.first!) { $0 && $1 }

        let sortDescriptors: [SortDescriptor<QuickNote>] = {
            switch sortBy {
                case .pinnedThenAccessed:
                    return [SortDescriptor(\.pinned, order: .reverse), SortDescriptor(\.lastAccessedAt, order: .reverse)]
                case .createdAt:
                    return [SortDescriptor(\.createdAt, order: .reverse)]
                case .updatedAt:
                    return [SortDescriptor(\.updatedAt, order: .reverse)]
                case .lastAccessedAt:
                    return [SortDescriptor(\.lastAccessedAt, order: .reverse)]
                case .pinnedOnly:
                    return [SortDescriptor(\.pinned, order: .reverse)]
            }
        }()
        let fetchDescriptor = FetchDescriptor<QuickNote>(predicate: predicate, sortBy: sortDescriptors)
        return try context.fetch(fetchDescriptor)
    }

    public func fetchAllNotes() throws -> [QuickNote] { try fetchNotes() }
    public func fetchPinnedNotes() throws -> [QuickNote] { try fetchNotes(sortBy: .pinnedThenAccessed).filter { $0.pinned } }

    public func searchNotes(query: String, user: String? = nil) throws -> [QuickNote] {
        let lowercasedQuery = query.lowercased()
        var predicates: [Predicate<QuickNote>] = []

        let contentPredicate = #Predicate<QuickNote> { note in
            note.content.lowercased().contains(lowercasedQuery) ||
            note.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }
        predicates.append(contentPredicate)
        if let user { predicates.append(#Predicate { $0.createdBy == user }) }
        let predicate = predicates.dropFirst().reduce(predicates.first!) { $0 && $1 }
        let fetchDescriptor = FetchDescriptor<QuickNote>(predicate: predicate)
        return try context.fetch(fetchDescriptor)
    }

    // MARK: - Helpers

    private func snapshot(_ note: QuickNote) -> QuickNote {
        QuickNote(
            id: note.id,
            content: note.content,
            contentHistory: note.contentHistory,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            lastAccessedAt: note.lastAccessedAt,
            pinned: note.pinned,
            category: note.category,
            createdBy: note.createdBy,
            tags: note.tags,
            owner: note.owner,
            dog: note.dog,
            appointment: note.appointment
        )
    }
}

// MARK: - Sorting Enum

public enum QuickNoteSort {
    case pinnedThenAccessed
    case createdAt
    case updatedAt
    case lastAccessedAt
    case pinnedOnly
}
