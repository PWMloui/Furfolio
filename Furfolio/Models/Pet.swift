//
//  Pet.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 30, 2025 — added validation, birthday utilities, update method, Hashable, and preview data.
//

import Foundation
import os

@MainActor
/// Represents a pet with identity, validation, and birthday utilities.
struct Pet: Codable, Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Pet")
  // MARK: – Dependencies
  private let calendar: Calendar
  private let dateFormatter: DateFormatter

  /// Creates a new Pet.
  init(
    id: UUID = .init(),
    name: String,
    breed: String,
    birthdate: Date? = nil,
    specialInstructions: String? = nil,
    calendar: Calendar = .current,
    dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      return fmt
    }()
  ) {
    self.id = id
    self.name = name
    self.breed = breed
    self.birthdate = birthdate
    self.specialInstructions = specialInstructions
    self.calendar = calendar
    self.dateFormatter = dateFormatter
        logger.log("Initialized Pet id: \(id), name: \(name), breed: \(breed), birthdate: \(String(describing: birthdate))")
  }

  // MARK: – Properties

  /// Unique identifier for this pet.
  /// Unique identifier for this pet.
  var id: UUID = .init()

  /// The pet’s given name.
  /// The pet’s given name.
  var name: String

  /// The breed or type of the pet.
  /// The breed or type of the pet.
  var breed: String

  /// Optional birthdate of the pet.
  /// Optional birthdate of the pet.
  var birthdate: Date?

  /// Any special care instructions or notes.
  /// Any special care instructions or notes.
  var specialInstructions: String?

  // MARK: – Validation

  /// Indicates whether the pet has valid non-empty name and breed.
  /// True if this pet has a non-empty name and breed.
  var isValid: Bool {
      logger.log("Validating Pet: name='\(name)', breed='\(breed)'")
    let result = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      logger.log("Validation result: \(result)") 
    return result
  }

  // MARK: – Computed Properties

  /// Age in whole years, if birthdate is known.
  var age: Int? {
      logger.log("Computing age for Pet id: \(id), birthdate: \(String(describing: birthdate))")
    guard let bd = birthdate else { return nil }
    let result = calendar.dateComponents([.year], from: bd, to: Date.now).year
      logger.log("Computed age: \(String(describing: result))")
    return result
  }

  /// Formatted birthdate string, or “Unknown” if not set.
  var formattedBirthdate: String {
      logger.log("Formatting birthdate for Pet id: \(id)")
    guard let bd = birthdate else {
      let result = NSLocalizedString("Unknown", comment: "No birthdate available")
        logger.log("Formatted birthdate: \(result)")
      return result
    }
    let result = dateFormatter.string(from: bd)
      logger.log("Formatted birthdate: \(result)")
    return result
  }

  /// The next birthday date (this year or next), if birthdate is known.
  var nextBirthday: Date? {
      logger.log("Calculating nextBirthday for Pet id: \(id)")
    guard let bd = birthdate else { return nil }
    var comps = calendar.dateComponents([.month, .day], from: bd)
    comps.year = calendar.component(.year, from: Date.now)
    guard let candidate = calendar.date(from: comps) else { return nil }
    let result = candidate < Date.now
      ? calendar.date(byAdding: .year, value: 1, to: candidate)
      : candidate
      logger.log("Next birthday: \(String(describing: result))")
    return result
  }

  /// Number of days until the next birthday, or nil if birthdate is unknown.
  var daysUntilNextBirthday: Int? {
      logger.log("Calculating daysUntilNextBirthday for Pet id: \(id)")
    guard let next = nextBirthday else { return nil }
    let result = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date.now), to: next).day
      logger.log("Days until next birthday: \(String(describing: result))")
    return result
  }

  /// A user‐friendly string for days until next birthday.
  var daysUntilNextBirthdayString: String? {
      logger.log("Generating daysUntilNextBirthdayString for Pet id: \(id)")
    guard let days = daysUntilNextBirthday else { return nil }
    let result = days == 0 ? NSLocalizedString("Today", comment: "Birthday is today")
      : String(format: NSLocalizedString("In %d day%@", comment: "Days until next birthday"), days, days == 1 ? "" : "s")
      logger.log("Days until next birthday string: \(result)")
    return result
  }

  /// True if today is the pet’s birthday.
  var isBirthdayToday: Bool {
      logger.log("Checking if birthday is today for Pet id: \(id)")
    guard let next = nextBirthday else { return false }
    let result = calendar.isDateInToday(next)
      logger.log("Is birthday today: \(result)")
    return result
  }

  /// A brief, formatted summary of the pet's details.
  var summary: String {
      logger.log("Generating summary for Pet id: \(id)")
    var parts: [String] = []
    parts.append("\(name) (\(breed))")
    if let bd = birthdate {
      parts.append("Born \(formattedBirthdate)")
    }
    if let a = age {
      parts.append("\(a) year\(a == 1 ? "" : "s") old")
    }
    if let instr = specialInstructions, !instr.isEmpty {
      parts.append(instr)
    }
    let result = parts.joined(separator: " • ")
      logger.log("Generated summary: \(result)")
    return result
  }

  // MARK: – Mutating Methods

  /// Updates pet fields with sanitized inputs.
  mutating func update(
    name: String? = nil,
    breed: String? = nil,
    birthdate: Date? = nil,
    specialInstructions: String? = nil
  ) {
      logger.log("Updating Pet id: \(id) with provided fields")
    if let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
      self.name = n
    }
    if let b = breed?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty {
      self.breed = b
    }
    if let bd = birthdate {
      self.birthdate = bd
    }
    if let instr = specialInstructions {
      self.specialInstructions = instr.trimmingCharacters(in: .whitespacesAndNewlines)
    }
      logger.log("Updated Pet: name=\(name), breed=\(breed), birthdate=\(String(describing: birthdate))")
  }

  // MARK: – Preview Data

  #if DEBUG
  static let sample = Pet(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    name: "Rex",
    breed: "Labrador",
    birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date.now),
    specialInstructions: "Loves belly rubs and long walks"
  )
  #endif
}
