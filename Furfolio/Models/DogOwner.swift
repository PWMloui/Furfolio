//
//  DogOwner.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 7, 2025 — fixed default‐value qualifiers, removed invalid `dogImage` references, added `dogImage` UIImage wrapper.
//

import Foundation
import SwiftData

// TODO: Centralize transformer registration in PersistenceController and move computed logic into a ViewModel for testability.
@MainActor
@Model
final class DogOwner: Identifiable, Hashable {
  
  // MARK: – Transformer Names
  
  private static let petArrayTransformerName    = "PetArrayTransformer"
  private static let stringArrayTransformerName = "StringArrayTransformer"
  private static let urlArrayTransformerName    = "URLArrayTransformer"

  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current

  /// Shared formatter for date display.
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()
  
  // MARK: – Persistent Properties

  /// Unique identifier for the owner.
  @Attribute
  var id: UUID = UUID()

  /// Owner’s full name.
  @Attribute
  var ownerName: String

  /// Dog’s name.
  @Attribute
  var dogName: String

  /// Dog’s breed.
  @Attribute
  var breed: String

  /// Contact information for the owner.
  @Attribute
  var contactInfo: String

  /// Owner’s email address.
  @Attribute
  var email: String?

  /// Owner’s address.
  @Attribute
  var address: String

  /// Image data for the dog’s photo.
  @Attribute(.externalStorage)
  var dogImageData: Data?

  /// Additional notes about the owner or dog.
  @Attribute
  var notes: String

  /// Dog’s birthdate.
  @Attribute
  var birthdate: Date?

  @Relationship(deleteRule: .cascade)
  var appointments: [Appointment] = []

  @Relationship(deleteRule: .cascade)
  var charges: [Charge] = []

  /// List of additional pets owned.
  @Attribute(.transformable(by: petArrayTransformerName))
  var pets: [Pet] = []

  /// Emergency contact phone numbers.
  @Attribute(.transformable(by: stringArrayTransformerName))
  var emergencyContacts: [String] = []

  /// Attached document URLs.
  @Attribute(.transformable(by: urlArrayTransformerName))
  var documentAttachments: [URL] = []

  /// Date this record was created.
  @Attribute
  var createdDate: Date = Date.now

  /// Date this record was last updated.
  @Attribute
  var updatedDate: Date?

  // MARK: – Initialization

  init(
    ownerName: String,
    dogName: String,
    breed: String,
    contactInfo: String,
    email: String? = nil,
    address: String,
    dogImageData: Data? = nil,
    notes: String = "",
    birthdate: Date? = nil,
    pets: [Pet] = [],
    emergencyContacts: [String] = [],
    documentAttachments: [URL] = []
  ) {
    self.ownerName           = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogName             = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.breed               = breed.trimmingCharacters(in: .whitespacesAndNewlines)
    self.contactInfo         = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    self.email               = email
    self.address             = address.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogImageData        = dogImageData
    self.notes               = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    self.birthdate           = birthdate
    self.pets                = pets
    self.emergencyContacts   = emergencyContacts
    self.documentAttachments = documentAttachments
    self.updatedDate         = nil
  }

  /// Designated initializer for DogOwner.
  init(
    id: UUID = UUID(),
    ownerName: String,
    dogName: String,
    breed: String,
    contactInfo: String,
    email: String? = nil,
    address: String,
    dogImageData: Data? = nil,
    notes: String = "",
    birthdate: Date? = nil,
    pets: [Pet] = [],
    emergencyContacts: [String] = [],
    documentAttachments: [URL] = [],
    createdDate: Date = Date.now,
    updatedDate: Date? = nil
  ) {
    self.id = id
    self.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogName = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
    self.contactInfo = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    self.email = email
    self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogImageData = dogImageData
    self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    self.birthdate = birthdate
    self.pets = pets
    self.emergencyContacts = emergencyContacts
    self.documentAttachments = documentAttachments
    self.createdDate = createdDate
    self.updatedDate = updatedDate
  }

  // MARK: – Computed Properties

  /// UIImage wrapper for the stored image data.
  @Transient
  var dogImage: UIImage? {
    guard let data = dogImageData else { return nil }
    return UIImage(data: data)
  }

  /// Most recent date from appointments or charges.
  @Transient
  var lastActivityDate: Date? {
    (appointments.map(\.date) + charges.map(\.date)).max()
  }

  /// True if no activity in the past 90 days.
  @Transient
  var isInactive: Bool {
    guard let last = lastActivityDate else { return true }
    let cutoff = Self.calendar.date(byAdding: .day, value: -90, to: Date.now) ?? .distantPast
    return last < cutoff
  }

  /// Loyalty status based on appointment count.
  @Transient
  var loyaltyStatus: String {
    switch appointments.count {
    case 0:      return "New"
    case 1:      return "🐾 First Timer"
    case 2...9:  return "🔁 Monthly Regular"
    default:     return "🥇 Loyal Client"
    }
  }

  /// Display title combining owner and pet names.
  @Transient
  var displayTitle: String {
    let names = pets.isEmpty
      ? dogName
      : pets.map(\.name).joined(separator: ", ")
    return "\(ownerName) – \(names)"
  }

  /// Formatted birthdate or “Unknown”.
  @Transient
  var formattedBirthdate: String {
    guard let bd = birthdate else { return NSLocalizedString("Unknown", comment: "") }
    return Self.dateFormatter.string(from: bd)
  }

  /// Valid if essential fields are nonempty.
  @Transient
  var isValidOwner: Bool {
    !ownerName.isEmpty && !dogName.isEmpty && !breed.isEmpty
  }

  /// Count of past appointments.
  @Transient
  var pastAppointmentsCount: Int {
    appointments.filter { $0.date < Date.now }.count
  }

  /// Count of upcoming appointments.
  @Transient
  var upcomingAppointmentsCount: Int {
    appointments.filter { $0.date > Date.now }.count
  }

  /// Total charges across all visits.
  @Transient
  var totalCharges: Double {
    charges.reduce(0) { $0 + $1.amount }
  }

  /// Formatted currency string for total charges.
  @Transient
  var formattedTotalCharges: String {
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = Locale.current
    return fmt.string(from: NSNumber(value: totalCharges)) ?? "\(totalCharges)"
  }

  /// True if the owner has an upcoming appointment or recent activity.
  @Transient
  var isActive: Bool {
    upcomingAppointmentsCount > 0 || hasRecentActivity
  }
  private var hasRecentActivity: Bool {
    let since30 = Self.calendar.date(byAdding: .day, value: -30, to: Date.now) ?? .distantPast
    return appointments.contains { $0.date >= since30 }
      || charges.contains { $0.date >= since30 }
  }

  /// Lowercased searchable text.
  @Transient
  var searchableText: String {
    var text = [ownerName, dogName, breed, contactInfo, address, notes]
      .joined(separator: " ")
    if !emergencyContacts.isEmpty {
      text += " " + emergencyContacts.joined(separator: " ")
    }
    return text.lowercased()
  }

  /// URL to open Apple Maps for the address.
  @Transient
  var mapURL: URL? {
    let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return URL(string: "https://maps.apple.com/?address=\(encoded)")
  }

  /// Alias for the owner's pets array, for backward compatibility.
  @Transient
  var dogs: [Pet] {
    pets
  }

  // MARK: – Instance Methods

  /// Validates the stored dog image using `ImageValidator`.
  func isValidImage() -> Bool {
    ImageValidator.isAcceptableImage(dogImageData)
  }

  /// Synchronously resizes the stored image data to the given width.
  func resizeImage(to width: CGFloat) -> Data? {
    ImageProcessor.resize(data: dogImageData, targetWidth: width)
  }

  /// Asynchronously resizes the stored image data to the given width.
  func resizeImageAsync(to width: CGFloat) async -> Data? {
    await ImageProcessor.asyncResize(data: dogImageData, targetWidth: width)
  }

  /// Updates owner and dog information, trims inputs, and sets `updatedDate` to now.
  func updateInfo(
    ownerName: String,
    dogName: String,
    breed: String,
    contactInfo: String,
    address: String,
    dogImageData: Data?,
    notes: String
  ) {
    self.ownerName    = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogName      = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.breed        = breed.trimmingCharacters(in: .whitespacesAndNewlines)
    self.contactInfo  = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    self.address      = address.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogImageData = dogImageData
    self.notes        = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    self.updatedDate  = Date.now
  }

  // ... rest of methods unchanged ...

  // MARK: – Hashable

  static func == (lhs: DogOwner, rhs: DogOwner) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}


// MARK: – Preview Data

#if DEBUG
import SwiftUI
extension DogOwner {
    static var sample: DogOwner {
        let owner = DogOwner(
            ownerName: "Jane Doe",
            dogName: "Rex",
            breed: "Labrador",
            contactInfo: "jane@example.com",
            address: "123 Bark St."
        )
        owner.charges = [ Charge.sample ]
        let sampleAppt = Appointment(
            date: Date.now,
            dogOwner: owner,
            serviceType: .basic,
            notes: "Sample appointment"
        )
        owner.appointments = [ sampleAppt ]
        return owner
    }
}
#endif
