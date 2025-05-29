//
//  DogAllergyProfile.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData
import os

/// Severity levels for dog allergies.
enum AllergySeverity: Int, Codable, CaseIterable, Identifiable {
  case mild = 0
  case moderate = 1
  case severe = 2

  /// Unique identifier for Identifiable conformance.
  var id: Int { rawValue }

  /// Localized description for display.
  var localized: String {
    switch self {
    case .mild: return NSLocalizedString("Mild", comment: "Allergy severity")
    case .moderate: return NSLocalizedString("Moderate", comment: "Allergy severity")
    case .severe: return NSLocalizedString("Severe", comment: "Allergy severity")
    }
  }

  /// Emoji icon representing the severity.
  var icon: String {
    switch self {
    case .mild: return "😊"
    case .moderate: return "😐"
    case .severe: return "😷"
    }
  }
}

@MainActor
@Model
final class DogAllergyProfile: Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
  
  // MARK: — Persisted Properties

  /// Unique identifier for this profile.
  @Attribute
  var id: UUID = UUID()

  /// Name of the allergen triggering the profile.
  @Attribute
  var allergen: String

  /// Severity level of the allergy.
  @Attribute
  var severity: AllergySeverity = AllergySeverity.mild

  /// Optional notes about the allergy.
  @Attribute
  var notes: String?

  /// Date when the allergy was diagnosed.
  @Attribute
  var dateDiagnosed: Date = Date.now

  /// Profile creation timestamp.
  @Attribute
  var createdAt: Date = Date.now

  /// Profile last-updated timestamp.
  @Attribute
  var updatedAt: Date?

  /// The dog owner associated with this allergy profile.
  @Relationship(deleteRule: .cascade)
  var dogOwner: DogOwner

  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current

  /// Shared date formatter for display.
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()
    
    
  // MARK: — Initialization

  /// Initializes a DogAllergyProfile with trimmed inputs.
  init(
    allergen: String,
    severity: AllergySeverity = AllergySeverity.mild,
    notes: String? = nil,
    dateDiagnosed: Date = Date.now,
    dogOwner: DogOwner
  ) {
    self.allergen      = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
    self.severity      = severity
    self.notes         = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dateDiagnosed = dateDiagnosed
    self.dogOwner      = dogOwner
    logger.log("Initialized DogAllergyProfile id: \(id), allergen: \(allergen), severity: \(severity.rawValue)")
  }

  /// Designated initializer for DogAllergyProfile.
  init(
    id: UUID = UUID(),
    allergen: String,
    severity: AllergySeverity = .mild,
    notes: String? = nil,
    dateDiagnosed: Date = Date.now,
    dogOwner: DogOwner,
    createdAt: Date = Date.now,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.allergen = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
    self.severity = severity
    self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dateDiagnosed = dateDiagnosed
    self.dogOwner = dogOwner
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    logger.log("Initialized DogAllergyProfile id: \(id), allergen: \(allergen), severity: \(severity.rawValue)")
  }
    
    
    // MARK: — Convenience Presets
    
    /// Common seasonal pollen allergy
    static func pollenAllergy(for owner: DogOwner) -> DogAllergyProfile {
        let note = NSLocalizedString("Typical seasonal pollen allergy.", comment: "")
        return DogAllergyProfile(
            allergen: "Pollen",
            severity: AllergySeverity.moderate,
            notes: note,
            dateDiagnosed: Date.now,
            dogOwner: owner
        )
    }
    
    /// Food‐based allergy, specifying the food item
    static func foodAllergy(for owner: DogOwner, food: String) -> DogAllergyProfile {
        let trimmedFood = food.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = String(
            format: NSLocalizedString("Avoid %@ in diet.", comment: ""),
            trimmedFood
        )
        return DogAllergyProfile(
            allergen: trimmedFood,
            severity: AllergySeverity.mild,
            notes: note,
            dateDiagnosed: Date.now,
            dogOwner: owner
        )
    }
    
    
  // MARK: — Computed Properties

  @Transient
  var formattedDiagnosisDate: String {
    Self.dateFormatter.string(from: dateDiagnosed)
  }

  @Transient
  var daysSinceDiagnosisString: String {
    let days = Self.calendar.dateComponents(
      [.day],
      from: dateDiagnosed,
      to: Date.now
    ).day ?? 0
    return days == 0 ? "Today" : "\(days) day\(days == 1 ? "" : "s") ago"
  }

  @Transient
  var summary: String {
    var parts = ["\(severity.icon) \(allergen) (\(severity.localized))"]
    if let notes, !notes.isEmpty {
      parts.append(notes)
    }
    return parts.joined(separator: ": ")
  }

  @Transient
  var isValid: Bool {
    !allergen.isEmpty
  }
    
    
    // MARK: — Update
    
    /// Updates this profile’s properties and sets `updatedAt` to now.
    func update(
        allergen: String,
        severity: AllergySeverity,
        notes: String?
    ) {
        logger.log("Updating DogAllergyProfile \(id): allergen=\(allergen), severity=\(severity.rawValue), notes=\(notes ?? "nil")")
        self.allergen  = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
        self.severity  = severity
        self.notes     = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date.now
        logger.log("Updated DogAllergyProfile \(id) at \(updatedAt!)")
    }
    
    
    // MARK: — Convenience Creation
    
    /// Creates and inserts a new DogAllergyProfile in the context.
    @discardableResult
    static func create(
        allergen: String,
        severity: AllergySeverity = AllergySeverity.mild,
        notes: String? = nil,
        dateDiagnosed: Date = Date.now,
        for dogOwner: DogOwner,
        in context: ModelContext
    ) -> DogAllergyProfile {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
        logger.log("Creating DogAllergyProfile: allergen=\(allergen), severity=\(severity.rawValue)")
        let profile = DogAllergyProfile(
            allergen: allergen,
            severity: severity,
            notes: notes,
            dateDiagnosed: dateDiagnosed,
            dogOwner: dogOwner
        )
        context.insert(profile)
        logger.log("Created DogAllergyProfile id: \(profile.id)")
        return profile
    }
    
    
    // MARK: — Fetch Helpers
    
    /// Fetches all DogAllergyProfiles, newest first.
    static func fetchAll(in context: ModelContext) -> [DogAllergyProfile] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
        logger.log("Fetching all DogAllergyProfiles")
        let desc = FetchDescriptor<DogAllergyProfile>(
            sortBy: [ SortDescriptor(\DogAllergyProfile.dateDiagnosed, order: .reverse) ]
        )
        do {
            let results = try context.fetch(desc)
            logger.log("Fetched \(results.count) DogAllergyProfiles")
            return results
        } catch {
            logger.error("DogAllergyProfile.fetchAll failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetches all profiles for a given owner, newest first.
    static func fetch(for owner: DogOwner, in context: ModelContext) -> [DogAllergyProfile] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
        logger.log("Fetching DogAllergyProfiles for owner \(owner.id)")
        let desc = FetchDescriptor<DogAllergyProfile>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [ SortDescriptor(\DogAllergyProfile.dateDiagnosed, order: .reverse) ]
        )
        do {
            let results = try context.fetch(desc)
            logger.log("Fetched \(results.count) DogAllergyProfiles for owner \(owner.id)")
            return results
        } catch {
            logger.error("DogAllergyProfile.fetch(for:) failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches the first profile matching the trimmed allergen.
    static func fetch(allergen: String, in context: ModelContext) -> DogAllergyProfile? {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
        let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.log("Fetching DogAllergyProfile for allergen \(trimmed)")
        let desc = FetchDescriptor<DogAllergyProfile>(
            predicate: #Predicate { $0.allergen == trimmed },
            sortBy: [ SortDescriptor(\DogAllergyProfile.dateDiagnosed, order: .reverse) ]
        )
        let results = (try? context.fetch(desc))
        if let count = results?.count {
            logger.log("Fetched \(count) DogAllergyProfiles for allergen \(trimmed)")
        } else {
            logger.log("No DogAllergyProfiles found for allergen \(trimmed)")
        }
        return results?.first
    }
    
    /// Fetches profiles matching the given severity.
    static func fetch(severity: AllergySeverity, in context: ModelContext) -> [DogAllergyProfile] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogAllergyProfile")
        logger.log("Fetching DogAllergyProfiles with severity \(severity.rawValue)")
        let desc = FetchDescriptor<DogAllergyProfile>(
            predicate: #Predicate { $0.severity == severity },
            sortBy: [ SortDescriptor(\DogAllergyProfile.dateDiagnosed, order: .reverse) ]
        )
        do {
            let results = try context.fetch(desc)
            logger.log("Fetched \(results.count) DogAllergyProfiles with severity \(severity.rawValue)")
            return results
        } catch {
            logger.error("DogAllergyProfile.fetch(severity:) failed: \(error.localizedDescription)")
            return []
        }
    }
    
    
    // MARK: — Hashable
    
    static func == (lhs: DogAllergyProfile, rhs: DogAllergyProfile) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
}


// MARK: — Preview Data

#if DEBUG
import SwiftUI

extension DogAllergyProfile {
    static var samplePollen: DogAllergyProfile {
        .pollenAllergy(for: sampleOwner)
    }
    static var sampleFood: DogAllergyProfile {
        .foodAllergy(for: sampleOwner, food: "Chicken")
    }
    private static var sampleOwner: DogOwner {
        DogOwner(
            ownerName: "Jane Doe",
            dogName: "Rex",
            breed: "Labrador",
            contactInfo: "jane@example.com",
            address: "123 Bark St."
        )
    }
}
#endif
