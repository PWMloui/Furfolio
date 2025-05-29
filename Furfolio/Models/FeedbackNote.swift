
//
//  FeedbackNote.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 16, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData
import os


@MainActor
@Model
final class FeedbackNote: Identifiable, Hashable {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FeedbackNote")
    
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
        logger.log("Initialized FeedbackNote id: \(id), contentPreview: \(contentPreview), rating: \(rating ?? -1)")
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
      logger.log("Initialized FeedbackNote id: \(id), contentPreview: \(contentPreview), rating: \(rating ?? -1)")
    }
    
    
    // MARK: – Validation
    
    /// True when the content is non-empty.
    /// True if there's non-empty feedback text.
    var isValid: Bool {
        let valid = !content.isEmpty
        logger.log("isValid check: \(valid) for content length: \(content.count)")
        return valid
    }
    
    /// True when the rating is within 1…5.
    /// True if rating is within 1…5.
    var hasValidRating: Bool {
        let valid = rating.map { (1...5).contains($0) } ?? false
        logger.log("hasValidRating check: \(valid) for rating: \(rating ?? -1)")
        return valid
    }
    
    
    // MARK: – Computed Properties
    
    @Transient
    /// “May 16, 2025”
    var formattedDate: String {
        logger.log("Accessing formattedDate for FeedbackNote \(id)")
        let result = date.formatted(.dateTime.month().day().year())
        logger.log("formattedDate: \(result)")
        return result
    }

    @Transient
    /// “⭐️⭐️⭐️” or nil if no rating.
    var ratingStars: String? {
        logger.log("Accessing ratingStars for FeedbackNote \(id)")
        guard let r = rating, (1...5).contains(r) else {
            logger.log("ratingStars: nil")
            return nil
        }
        let stars = String(repeating: "⭐️", count: r)
        logger.log("ratingStars: \(stars)")
        return stars
    }

    @Transient
    /// First 60 chars of content, with ellipsis if truncated.
    var contentPreview: String {
        logger.log("Accessing contentPreview for FeedbackNote \(id)")
        let preview: String
        if content.count > 60 {
            let idx = content.index(content.startIndex, offsetBy: 60)
            preview = String(content[..<idx]) + "…"
        } else {
            preview = content
        }
        logger.log("contentPreview: \(preview)")
        return preview
    }

    @Transient
    /// “May 16, 2025 ⭐️⭐️ : Great service…”
    var summary: String {
        logger.log("Accessing summary for FeedbackNote \(id)")
        let stars = ratingStars.map { " \($0)" } ?? ""
        let result = "\(formattedDate)\(stars): \(contentPreview)"
        logger.log("summary: \(result)")
        return result
    }

    @Transient
    /// Simple sentiment based on rating.
    var sentiment: String {
        logger.log("Accessing sentiment for FeedbackNote \(id)")
        guard let r = rating else {
            logger.log("sentiment: No rating")
            return "No rating"
        }
        let result: String
        switch r {
        case 1...2: result = "Negative"
        case 3:     result = "Neutral"
        case 4...5: result = "Positive"
        default:    result = "Unknown"
        }
        logger.log("sentiment: \(result)")
        return result
    }
    
    
    // MARK: – Update
    
    /// Updates content, rating, and appointment, stamping `updatedAt`.
    /// Update content and/or rating. Stamps `updatedAt`.
    func update(
        content: String? = nil,
        rating: Int? = nil,
        appointment: Appointment? = nil
    ) {
        logger.log("Updating FeedbackNote \(id): newContentPreview: \(contentPreview), newRating: \(rating ?? -1)")
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
        logger.log("Updated FeedbackNote \(id) at \(updatedAt!)")
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
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FeedbackNote")
        logger.log("Recording FeedbackNote with contentPreview: \(String(content.prefix(20)))")
        let note = FeedbackNote(
            content: content,
            rating: rating,
            owner: owner,
            appointment: appointment
        )
        guard note.isValid else { return nil }
        context.insert(note)
        logger.log("Inserted FeedbackNote id: \(note.id)")
        return note
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches FeedbackNotes all, newest first.
    /// All notes, newest first.
    static func fetchAll(in context: ModelContext) -> [FeedbackNote] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FeedbackNote")
        logger.log("Fetching FeedbackNotes (filter: all)")
        let desc = FetchDescriptor<FeedbackNote>(
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) FeedbackNotes")
        return results
    }
    
    /// Fetches FeedbackNotes for a specific owner.
    /// Notes for a specific owner.
    static func fetch(for owner: DogOwner, in context: ModelContext) -> [FeedbackNote] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FeedbackNote")
        logger.log("Fetching FeedbackNotes (filter: owner/\(owner.id))")
        let desc = FetchDescriptor<FeedbackNote>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) FeedbackNotes")
        return results
    }
    
    /// Fetches FeedbackNotes for a specific appointment.
    /// Notes for a specific appointment.
    static func fetch(for appointment: Appointment, in context: ModelContext) -> [FeedbackNote] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FeedbackNote")
        logger.log("Fetching FeedbackNotes (filter: appointment/\(appointment.id))")
        let desc = FetchDescriptor<FeedbackNote>(
            predicate: #Predicate { $0.appointment?.id == appointment.id },
            sortBy: [ SortDescriptor(\FeedbackNote.date, order: .reverse) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) FeedbackNotes")
        return results
    }
    
    
    // MARK: – Hashable
    
    static func ==(lhs: FeedbackNote, rhs: FeedbackNote) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


