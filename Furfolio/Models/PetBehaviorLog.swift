//
//  PetBehaviorLog.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData

// TODO: Centralize transformer registration in PersistenceController and move validation/formatting logic into a ViewModel for testability.
@MainActor
@Model
final class PetBehaviorLog: Identifiable, Hashable {
  
  /// Shared calendar and formatter to avoid repeated allocations.
  private static let calendar = Calendar.current
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
  }()
  
  // MARK: – Persistent Properties
  
  /// Unique identifier for this behavior log entry.
  @Attribute
  var id: UUID = UUID()
  
  /// Date and time when this behavior was logged.
  @Attribute
  var dateLogged: Date = Date.now
  
  /// The log message describing the behavior.
  @Attribute
  var note: String
  
  /// Optional emoji tag categorizing the behavior.
  @Attribute
  var tagEmoji: String?
  
  /// Associated appointment, if any.
  @Relationship(deleteRule: .nullify)
  var appointment: Appointment?
  
  /// Owner of the dog for this log entry.
  @Relationship(deleteRule: .cascade)
  var dogOwner: DogOwner
  
  /// Record creation timestamp.
  @Attribute
  var createdAt: Date = Date.now
  
  /// Record last-updated timestamp.
  @Attribute
  var updatedAt: Date?
  
  
  // MARK: – Initialization
  
  init(
    note: String,
    tagEmoji: String? = nil,
    dateLogged: Date = Date.now,
    appointment: Appointment? = nil,
    owner: DogOwner
  ) {
    self.note        = note.trimmingCharacters(in: .whitespacesAndNewlines)
    self.tagEmoji    = tagEmoji
    self.dateLogged  = dateLogged
    self.appointment = appointment
    self.dogOwner    = owner
    // `createdAt` default of Date.now applies
  }
  
  /// Designated initializer for PetBehaviorLog.
  init(
    id: UUID = UUID(),
    note: String,
    tagEmoji: String? = nil,
    dateLogged: Date = Date.now,
    appointment: Appointment? = nil,
    dogOwner: DogOwner,
    createdAt: Date = Date.now,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    self.tagEmoji = tagEmoji
    self.dateLogged = dateLogged
    self.appointment = appointment
    self.dogOwner = dogOwner
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
    
    
  // MARK: – Computed Properties
  
  @Transient
  /// “May 30, 2025 at 3:45 PM”
  var formattedDate: String {
    dateLogged.formatted(
      .dateTime
        .month(.wide)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()
    )
  }
  
  @Transient
  /// “2 hours ago”, “yesterday”, etc.
  var relativeDate: String {
    Self.relativeFormatter.localizedString(for: dateLogged, relativeTo: Date.now)
  }
  
  @Transient
  /// “[May 30, 2025 at 3:45 PM] Played fetch 🟢”
  var summary: String {
    var s = "[\(formattedDate)] \(note)"
    if let tag = tagEmoji {
      s += " \(tag)"
    }
    return s
  }
    
    
    // MARK: – Mutating
    
    /// Updates the note and/or tag, stamping `updatedAt`.
    /// Update the note and/or tag, stamping `updatedAt`
    func update(note: String? = nil, tagEmoji: String? = nil) {
        if let newNote = note?.trimmingCharacters(in: .whitespacesAndNewlines), !newNote.isEmpty {
            self.note = newNote
        }
        if let newTag = tagEmoji {
            self.tagEmoji = newTag
        }
        self.updatedAt = Date.now                // was `.now`
    }
    
    
    // MARK: – Creation
    
    /// Creates and inserts a new PetBehaviorLog entry.
    /// Inserts a new log entry.
    @discardableResult
    static func record(
        note: String,
        tagEmoji: String? = nil,
        owner: DogOwner,
        appointment: Appointment? = nil,
        in context: ModelContext
    ) -> PetBehaviorLog {
        let entry = PetBehaviorLog(
            note: note,
            tagEmoji: tagEmoji,
            dateLogged: Date.now,                // was `.now`
            appointment: appointment,
            owner: owner
        )
        context.insert(entry)
        return entry
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches all logs for an owner, newest first.
    /// All logs for an owner, newest first.
    static func fetchAll(
        for owner: DogOwner,
        in context: ModelContext
    ) -> [PetBehaviorLog] {
        let descriptor = FetchDescriptor<PetBehaviorLog>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [SortDescriptor(\PetBehaviorLog.dateLogged, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ PetBehaviorLog.fetchAll failed:", error)
            return []
        }
    }
    
    /// Fetches logs for a specific appointment, newest first.
    /// Logs for a specific appointment.
    static func fetch(
        for appointment: Appointment,
        in context: ModelContext
    ) -> [PetBehaviorLog] {
        let descriptor = FetchDescriptor<PetBehaviorLog>(
            predicate: #Predicate { $0.appointment?.id == appointment.id },
            sortBy: [SortDescriptor(\PetBehaviorLog.dateLogged, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ PetBehaviorLog.fetch(for:) failed:", error)
            return []
        }
    }
    
    /// Fetches logs in a date range for an owner, newest first.
    /// Logs in a date range for an owner.
    static func fetch(
        in range: ClosedRange<Date>,
        for owner: DogOwner,
        in context: ModelContext
    ) -> [PetBehaviorLog] {
        let descriptor = FetchDescriptor<PetBehaviorLog>(
            predicate: #Predicate {
                $0.dogOwner.id == owner.id &&
                $0.dateLogged >= range.lowerBound &&
                $0.dateLogged <= range.upperBound
            },
            sortBy: [SortDescriptor(\PetBehaviorLog.dateLogged, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ PetBehaviorLog.fetch(in:for:) failed:", error)
            return []
        }
    }
    
    
    // MARK: – Hashable
    
    static func == (lhs: PetBehaviorLog, rhs: PetBehaviorLog) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
    // MARK: – Formatters
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    
    
    // MARK: – Preview Data
    
    #if DEBUG
    static var sample: PetBehaviorLog {
        let owner = DogOwner.sample
        return PetBehaviorLog(
            note: "Sample behavior logged",
            tagEmoji: "🟢",
            dateLogged: Calendar.current.date(
                byAdding: .hour,
                value: -3,
                to: Date.now                // was `.now`
            )!,
            appointment: nil,
            owner: owner
        )
    }
    #endif
}
