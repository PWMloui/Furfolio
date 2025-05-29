//
//  PetGalleryImage.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — fully qualified defaults, fixed thumbnail resizing, and corrected preview.
//

import Foundation
import SwiftData
import UIKit
import os
@MainActor

@Model
final class PetGalleryImage: Identifiable, Hashable {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryImage")
    
    // MARK: – Transformer Name
    
    static let stringArrayTransformerName = "StringArrayTransformer"
    
    // MARK: – Persistent Properties
    
    /// Unique identifier for this gallery image.
    @Attribute(.required)
    var id: UUID = UUID()                             // was `.init()`
    
    /// Raw image data, stored externally.
    @Attribute(.externalStorage)
    var imageData: Data?
    
    /// Optional caption for the image.
    @Attribute
    var caption: String?
    
    /// Date when the image was added.
    @Attribute(.required)
    var dateAdded: Date = Date()                    // was `.now`
    
    /// Last-updated timestamp.
    @Attribute
    var updatedAt: Date? = nil
    
    /// Tags associated with this image.
    @Attribute(.required, .transformable(by: PetGalleryImage.stringArrayTransformerName))
    var tags: [String] = []
    
    /// The dog owner related to this image.
    @Relationship(deleteRule: .cascade)
    var dogOwner: DogOwner
    
    /// Associated appointment, if any.
    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?
    
    
    // MARK: – Initialization
    
    init(
      imageData: Data?,
      caption: String? = nil,
      tags: [String] = [],
      owner: DogOwner,
      appointment: Appointment? = nil
    ) {
      self.imageData   = imageData
      self.caption     = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.tags        = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      self.dogOwner    = owner
      self.appointment = appointment
      logger.log("Initialized PetGalleryImage id: \(id), caption: \(caption ?? "nil"), tags: \(tags)")
    }
    
    /// Designated initializer for PetGalleryImage.
    init(
      id: UUID = UUID(),
      imageData: Data?,
      caption: String? = nil,
      tags: [String] = [],
      dogOwner: DogOwner,
      appointment: Appointment? = nil,
      dateAdded: Date = Date(),
      updatedAt: Date? = nil
    ) {
      self.id = id
      self.imageData = imageData
      self.caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.tags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      self.dogOwner = dogOwner
      self.appointment = appointment
      self.dateAdded = dateAdded
      self.updatedAt = updatedAt
      logger.log("Initialized PetGalleryImage id: \(id), dateAdded: \(dateAdded)")
    }
    
    
    // MARK: – Computed Properties
    
    /// UIImage representation of stored imageData.
    @Transient
    var uiImage: UIImage? {
        logger.log("Accessing uiImage for PetGalleryImage id: \(id)")
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
    
    /// Thumbnail resized to 200px width.
    @Transient
    var thumbnail: UIImage? {
        logger.log("Generating thumbnail for PetGalleryImage id: \(id)")
        guard let data = imageData,
              let resizedData = ImageProcessor.resize(data: data, targetWidth: 200),
              let img = UIImage(data: resizedData)
        else { return nil }
        return img
    }
    
    
    // MARK: – Tag Management
    
    /// Adds a trimmed tag if not already present, stamping `updatedAt`.
    func addTag(_ tag: String) {
        logger.log("Adding tag to PetGalleryImage \(id): \(tag)")
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
        updatedAt = Date()                         // was `.now`
        logger.log("Tags now: \(tags)")
    }
    
    /// Removes the specified tag, stamping `updatedAt`.
    func removeTag(_ tag: String) {
        logger.log("Removing tag from PetGalleryImage \(id): \(tag)")
        tags.removeAll { $0 == tag }
        updatedAt = Date()
        logger.log("Tags now: \(tags)")
    }
    
    /// Clears all tags and updates `updatedAt`.
    func clearTags() {
        logger.log("Clearing tags for PetGalleryImage \(id)")
        tags.removeAll()
        updatedAt = Date()
        logger.log("Tags cleared")
    }
    
    
    // MARK: – Updates
    
    /// Updates the caption text, trimming whitespace and stamping `updatedAt`.
    func update(caption: String?) {
        logger.log("Updating caption for PetGalleryImage \(id): \(caption ?? "nil")")
        self.caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = Date()
        logger.log("UpdatedAt stamped: \(updatedAt!)")
    }
    
    /// Updates the associated appointment and stamps `updatedAt`.
    func update(appointment: Appointment?) {
        logger.log("Updating appointment for PetGalleryImage \(id): \(String(describing: appointment?.id))")
        self.appointment = appointment
        updatedAt = Date()
        logger.log("UpdatedAt stamped: \(updatedAt!)")
    }
    
    
    // MARK: – Convenience Creation
    
    /// Creates and inserts a new PetGalleryImage entry into the context.
    @discardableResult
    static func record(
      imageData: Data?,
      caption: String? = nil,
      tags: [String] = [],
      owner: DogOwner,
      appointment: Appointment? = nil,
      in context: ModelContext
    ) -> PetGalleryImage {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryImage")
      logger.log("Recording PetGalleryImage for owner \(owner.id)")
      let entry = PetGalleryImage(
        imageData: imageData,
        caption: caption,
        tags: tags,
        owner: owner,
        appointment: appointment
      )
      context.insert(entry)
      logger.log("Recorded PetGalleryImage id: \(entry.id)")
      return entry
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches all gallery images for the given owner, sorted newest first.
    static func fetchAll(
      for owner: DogOwner,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryImage")
      logger.log("Fetching all PetGalleryImage for owner \(owner.id)")
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate { $0.dogOwner.id == owner.id },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      let result = (try? context.fetch(desc)) ?? []
      logger.log("Fetched \(result.count) images")
      return result
    }
    
    /// Fetches all images for a specific appointment, newest first.
    static func fetch(
      for appointment: Appointment,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryImage")
      logger.log("Fetching images for appointment \(appointment.id)")
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate { $0.appointment?.id == appointment.id },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      let result = (try? context.fetch(desc)) ?? []
      logger.log("Fetched \(result.count) images")
      return result
    }
    
    /// Fetches images in a date range for the owner, newest first.
    static func fetch(
      in range: ClosedRange<Date>,
      for owner: DogOwner,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryImage")
      logger.log("Fetching images in range \(range.lowerBound)–\(range.upperBound) for owner \(owner.id)")
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate {
          $0.dogOwner.id == owner.id &&
          $0.dateAdded >= range.lowerBound &&
          $0.dateAdded <= range.upperBound
        },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      let result = (try? context.fetch(desc)) ?? []
      logger.log("Fetched \(result.count) images")
      return result
    }
    
    
    // MARK: – Hashable
    
    static func == (lhs: PetGalleryImage, rhs: PetGalleryImage) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


// MARK: – Preview Data

#if DEBUG
extension PetGalleryImage {
    static var sample: PetGalleryImage {
        let owner = DogOwner.sample
        // Use PNG data from a system symbol
        let data = UIImage(systemName: "photo")?.pngData()
        let entry = PetGalleryImage(
            imageData: data,
            caption: "Before grooming",
            tags: ["Before", "Test"],
            owner: owner,
            appointment: nil
        )
        entry.dateAdded = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: Date()                        // was `.now`
        ) ?? Date()
        return entry
    }
}
#endif
