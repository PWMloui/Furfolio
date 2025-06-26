//
//  QuickNoteAssistant.swift
//  Furfolio
//
//  Cleaned 2025: Streamlined, Production-Ready
//

import Foundation
import SwiftData

// MARK: - QuickNote Model

@Model
public final class QuickNote: Identifiable, ObservableObject {
    @Attribute(.unique) public var id: UUID
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastAccessedAt: Date
    public var pinned: Bool
    public var category: QuickNoteCategory
    public var createdBy: String?
    
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.quickNotes)
    public weak var owner: DogOwner?
    @Relationship(deleteRule: .nullify, inverse: \Dog.quickNotes)
    public weak var dog: Dog?
    @Relationship(deleteRule: .nullify, inverse: \Appointment.quickNotes)
    public weak var appointment: Appointment?

    public var sortingKey: (Bool, Date) { (pinned, lastAccessedAt) }

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
    
    public func updateContent(_ newContent: String) {
        content = newContent
        updatedAt = Date()
        lastAccessedAt = Date()
    }
    public func togglePin() {
        pinned.toggle()
        updatedAt = Date()
        lastAccessedAt = Date()
    }
    public func markAccessed() {
        lastAccessedAt = Date()
    }
}

// MARK: - QuickNoteAssistant

@MainActor
public final class QuickNoteAssistant: ObservableObject {
    public static let shared = QuickNoteAssistant()
    public static func shared(with context: ModelContext) -> QuickNoteAssistant {
        QuickNoteAssistant(context: context)
    }
    
    private let context: ModelContext
    public var externalAuditHandler: ((_ action: String, _ note: QuickNote) -> Void)?
    
    public init(context: ModelContext = ModelContext()) {
        self.context = context
    }
    
    // MARK: - CRUD
    
    public func addNote(
        content: String,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        pinned: Bool = false,
        category: QuickNoteCategory = .general,
        createdBy: String? = nil
    ) throws -> QuickNote {
        let note = QuickNote(content: content, pinned: pinned, category: category, createdBy: createdBy, owner: owner, dog: dog, appointment: appointment)
        context.insert(note)
        try context.save()
        auditLog("Add Note", note)
        return note
    }
    
    public func updateNote(_ note: QuickNote, newContent: String) throws {
        note.updateContent(newContent)
        try context.save()
        auditLog("Update Note Content", note)
    }
    
    public func togglePin(_ note: QuickNote) throws {
        note.togglePin()
        try context.save()
        auditLog("Toggle Pin", note)
    }
    
    public func deleteNote(_ note: QuickNote) throws {
        context.delete(note)
        try context.save()
        auditLog("Delete Note", note)
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
    
    // MARK: - Audit
    
    private func auditLog(_ action: String, _ note: QuickNote) {
        print("[AuditLog] \(action), Note ID: \(note.id), User: \(note.createdBy ?? "Unknown"), Timestamp: \(Date())")
        externalAuditHandler?(action, note)
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
