//
//  PetGalleryImage.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — fully qualified defaults, fixed thumbnail resizing, and corrected preview.
//

import Foundation
import SwiftData
// TODO: Mark required fields with @Attribute(.required) and compute heavy properties as .transient for SwiftData optimization
import UIKit
// TODO: Centralize transformer registration in PersistenceController and move heavy computation into a ViewModel for testability.
@MainActor

@Model
final class PetGalleryImage: Identifiable, Hashable {
    
    /// Shared calendar and date formatter to avoid repeated allocations.
    private static let calendar = Calendar.current
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt
    }()
    
    // MARK: – Transformer Name
    
    static let stringArrayTransformerName = "StringArrayTransformer"
    
    // MARK: – Persistent Properties
    
    /// Unique identifier for this gallery image.
    @Attribute
    var id: UUID = UUID()                             // was `.init()`
    
    /// Raw image data, stored externally.
    @Attribute(.externalStorage)
    var imageData: Data?
    
    /// Optional caption for the image.
    @Attribute
    var caption: String?
    
    /// Date when the image was added.
    @Attribute
    var dateAdded: Date = Date.now                    // was `.now`
    
    /// Last-updated timestamp.
    @Attribute
    var updatedAt: Date? = nil
    
    /// Tags associated with this image.
    @Attribute(.transformable(by: PetGalleryImage.stringArrayTransformerName))
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
    }
    
    /// Designated initializer for PetGalleryImage.
    init(
      id: UUID = UUID(),
      imageData: Data?,
      caption: String? = nil,
      tags: [String] = [],
      dogOwner: DogOwner,
      appointment: Appointment? = nil,
      dateAdded: Date = Date.now,
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
    }
    
    
    // MARK: – Computed Properties
    
    /// UIImage representation of stored imageData.
    @Transient
    var uiImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
    
    /// Thumbnail resized to 200px width.
    @Transient
    var thumbnail: UIImage? {
        guard let data = imageData,
              let resizedData = ImageProcessor.resize(data: data, targetWidth: 200),
              let img = UIImage(data: resizedData)
        else { return nil }
        return img
    }
    
    
    // MARK: – Tag Management
    
    /// Adds a trimmed tag if not already present, stamping `updatedAt`.
    func addTag(_ tag: String) {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
        updatedAt = Date.now                         // was `.now`
    }
    
    /// Removes the specified tag, stamping `updatedAt`.
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = Date.now
    }
    
    /// Clears all tags and updates `updatedAt`.
    func clearTags() {
        tags.removeAll()
        updatedAt = Date.now
    }
    
    
    // MARK: – Updates
    
    /// Updates the caption text, trimming whitespace and stamping `updatedAt`.
    func update(caption: String?) {
        self.caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = Date.now
    }
    
    /// Updates the associated appointment and stamps `updatedAt`.
    func update(appointment: Appointment?) {
        self.appointment = appointment
        updatedAt = Date.now
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
      let entry = PetGalleryImage(
        imageData: imageData,
        caption: caption,
        tags: tags,
        owner: owner,
        appointment: appointment
      )
      context.insert(entry)
      return entry
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches all gallery images for the given owner, sorted newest first.
    static func fetchAll(
      for owner: DogOwner,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate { $0.dogOwner.id == owner.id },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches all images for a specific appointment, newest first.
    static func fetch(
      for appointment: Appointment,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate { $0.appointment?.id == appointment.id },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches images in a date range for the owner, newest first.
    static func fetch(
      in range: ClosedRange<Date>,
      for owner: DogOwner,
      in context: ModelContext
    ) -> [PetGalleryImage] {
      let desc = FetchDescriptor<PetGalleryImage>(
        predicate: #Predicate {
          $0.dogOwner.id == owner.id &&
          $0.dateAdded >= range.lowerBound &&
          $0.dateAdded <= range.upperBound
        },
        sortBy: [ SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse) ]
      )
      return (try? context.fetch(desc)) ?? []
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
            to: Date.now                        // was `.now`
        ) ?? Date.now
        return entry
    }
}
#endif
