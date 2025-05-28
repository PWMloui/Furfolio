
//
//  FeedbackNote.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 16, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData


@MainActor
@Model
final class FeedbackNote: Identifiable, Hashable {
    
    /// Shared date formatter to avoid repeated allocations.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt
    }()
    
    // MARK: – Persistent Properties
    
    /// Unique identifier for the feedback note.
    @Attribute
    var id: UUID = UUID()                 // was `.init()`
    
    /// Date of the feedback note.
    @Attribute
    var date: Date = Date.now             // was `.now`
    
    /// Content of the feedback note.
    @Attribute(.required)
    var content: String
    
    /// Rating associated with the feedback note.
    @Attribute
    var rating: Int?
    
    /// Creation timestamp of the feedback note.
    @Attribute
    var createdAt: Date = Date.now        // was `.now`
    
    /// Last update timestamp of the feedback note.
    @Attribute
    var updatedAt: Date?
    
    /// The dog owner related to this feedback note.
    @Relationship(.required, deleteRule: .cascade)
    var dogOwner: DogOwner
    
    /// The appointment related to this feedback note.
    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?
    
    
    // MARK: – Initialization
    
    /// Initializes a FeedbackNote with trimmed content and validated rating.
    /// Designated initializer.
    init(
        content: String,
        rating: Int? = nil,
        owner: DogOwner,
        appointment: Appointment? = nil
    ) {
        self.content     = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let validRating  = (1...5).contains(rating ?? 0) ? rating : nil
        self.rating      = validRating
        self.dogOwner    = owner
        self.appointment = appointment
        // `date`, `createdAt` default to Date.now
    }
    
    /// Designated initializer for FeedbackNote model.
    init(
      id: UUID = UUID(),
      date: Date = Date.now,
      content: String,
      rating: Int? = nil,
      dogOwner: DogOwner,
      appointment: Appointment? = nil,
      createdAt: Date = Date.now,
      updatedAt: Date? = nil
    ) {
      self.id = id
      self.date = date
      self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
      let validRating = (1...5).contains(rating ?? 0) ? rating : nil
      self.rating = validRating
      self.dogOwner = dogOwner
      self.appointment = appointment
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
    
    
    // MARK: – Validation
    
    /// True when the content is non-empty.
    /// True if there's non-empty feedback text.
    var isValid: Bool {
        !content.isEmpty
    }
    
    /// True when the rating is within 1…5.
    /// True if rating is within 1…5.
    var hasValidRating: Bool {
        rating.map { (1...5).contains($0) } ?? false
    }
    
    
    // MARK: – Computed Properties
    
    @Transient
    /// “May 16, 2025”
    var formattedDate: String {
        date.formatted(.dateTime.month().day().year())
    }
    
    @Transient
    /// “⭐️⭐️⭐️” or nil if no rating.
    var ratingStars: String? {
        guard let r = rating, (1...5).contains(r) else { return nil }
        return String(repeating: "⭐️", count: r)
    }
    
    @Transient
    /// First 60 chars of content, with ellipsis if truncated.
    var contentPreview: String {
        if content.count > 60 {
            let idx = content.index(content.startIndex, offsetBy: 60)
            return String(content[..<idx]) + "…"
        }
        return content
    }
    
    @Transient
    /// “May 16, 2025 ⭐️⭐️ : Great service…”
    var summary: String {
        let stars = ratingStars.map { " \($0)" } ?? ""
        return "\(formattedDate)\(stars): \(contentPreview)"
    }
    
    @Transient
    /// Simple sentiment based on rating.
    var sentiment: String {
        guard let r = rating else { return "No rating" }
        switch r {
        case 1...2: return "Negative"
        case 3:     return "Neutral"
        case 4...5: return "Positive"
        default:    return "Unknown"
        }
    }
    
    
    // MARK: – Update
    
    /// Updates content, rating, and appointment, stamping `updatedAt`.
    /// Update content and/or rating. Stamps `updatedAt`.
    func update(
        content: String? = nil,
        rating: Int? = nil,
        appointment: Appointment? = nil
    ) {
        if let txt = content?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty {
            self.content = txt
        }
        if let r = rating, (1...5).contains(r) {
            self.rating = r
        }
        if let appt = appointment {
            self.appointment = appt
        }
        updatedAt = Date.now               // was `.now`
    }
    
    
    // MARK: – Convenience Creation
    
    /// Creates and inserts a FeedbackNote if valid, returning it or nil.
    /// Inserts a new FeedbackNote into the context.
    @discardableResult
    static func record(
        content: String,
        rating: Int? = nil,
        owner: DogOwner,
        appointment: Appointment? = nil,
        in context: ModelContext
    ) -> FeedbackNote? {
        let note = FeedbackNote(
            content: content,
            rating: rating,
            owner: owner,
            appointment: appointment
        )
        guard note.isValid else { return nil }
        context.insert(note)
        return note
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches FeedbackNotes all, newest first.
    /// All notes, newest first.
    static func fetchAll(in context: ModelContext) -> [FeedbackNote] {
        let desc = FetchDescriptor<FeedbackNote>(
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches FeedbackNotes for a specific owner.
    /// Notes for a specific owner.
    static func fetch(for owner: DogOwner, in context: ModelContext) -> [FeedbackNote] {
        let desc = FetchDescriptor<FeedbackNote>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches FeedbackNotes for a specific appointment.
    /// Notes for a specific appointment.
    static func fetch(for appointment: Appointment, in context: ModelContext) -> [FeedbackNote] {
        let desc = FetchDescriptor<FeedbackNote>(
            predicate: #Predicate { $0.appointment?.id == appointment.id },
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    
    // MARK: – Hashable
    
    static func ==(lhs: FeedbackNote, rhs: FeedbackNote) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


