//
//  Pet.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 30, 2025 — added validation, birthday utilities, update method, Hashable, and preview data.
//

import Foundation

@MainActor
/// Represents a pet with identity, validation, and birthday utilities.
struct Pet: Codable, Identifiable, Hashable {
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
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  // MARK: – Computed Properties

  /// Age in whole years, if birthdate is known.
  var age: Int? {
    guard let bd = birthdate else { return nil }
    return calendar.dateComponents([.year], from: bd, to: Date.now).year
  }

  /// Formatted birthdate string, or “Unknown” if not set.
  var formattedBirthdate: String {
    guard let bd = birthdate else {
      return NSLocalizedString("Unknown", comment: "No birthdate available")
    }
    return dateFormatter.string(from: bd)
  }

  /// The next birthday date (this year or next), if birthdate is known.
  var nextBirthday: Date? {
    guard let bd = birthdate else { return nil }
    var comps = calendar.dateComponents([.month, .day], from: bd)
    comps.year = calendar.component(.year, from: Date.now)
    guard let candidate = calendar.date(from: comps) else { return nil }
    return candidate < Date.now
      ? calendar.date(byAdding: .year, value: 1, to: candidate)
      : candidate
  }

  /// Number of days until the next birthday, or nil if birthdate is unknown.
  var daysUntilNextBirthday: Int? {
    guard let next = nextBirthday else { return nil }
    return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date.now), to: next).day
  }

  /// A user‐friendly string for days until next birthday.
  var daysUntilNextBirthdayString: String? {
    guard let days = daysUntilNextBirthday else { return nil }
    return days == 0 ? NSLocalizedString("Today", comment: "Birthday is today")
      : String(format: NSLocalizedString("In %d day%@", comment: "Days until next birthday"), days, days == 1 ? "" : "s")
  }

  /// True if today is the pet’s birthday.
  var isBirthdayToday: Bool {
    guard let next = nextBirthday else { return false }
    return calendar.isDateInToday(next)
  }

  /// A brief, formatted summary of the pet's details.
  var summary: String {
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
    return parts.joined(separator: " • ")
  }

  // MARK: – Mutating Methods

  /// Updates pet fields with sanitized inputs.
  mutating func update(
    name: String? = nil,
    breed: String? = nil,
    birthdate: Date? = nil,
    specialInstructions: String? = nil
  ) {
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
