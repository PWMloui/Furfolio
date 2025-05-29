//
//  DogOwner.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 7, 2025 — fixed default‐value qualifiers, removed invalid `dogImage` references, added `dogImage` UIImage wrapper.
//

import Foundation
import SwiftData
import UIKit
import os

@MainActor
@Model
final class DogOwner: Identifiable, Hashable, Encodable {

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogOwner")

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

  /// Number of visits required to achieve "Loyal Client" status.
  @Attribute
  var loyaltyThreshold: Int = 10

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
    loyaltyThreshold: Int = 10,
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
    self.loyaltyThreshold    = loyaltyThreshold
    self.pets                = pets
    self.emergencyContacts   = emergencyContacts
    self.documentAttachments = documentAttachments
    self.updatedDate         = nil
    logger.log("Initialized DogOwner id: \(id), ownerName: \(ownerName), dogName: \(dogName)")
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
    loyaltyThreshold: Int = 10,
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
    self.loyaltyThreshold = loyaltyThreshold
    self.pets = pets
    self.emergencyContacts = emergencyContacts
    self.documentAttachments = documentAttachments
    self.createdDate = createdDate
    self.updatedDate = updatedDate
    logger.log("Initialized DogOwner id: \(id), ownerName: \(ownerName), dogName: \(dogName)")
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
    logger.log("Computing isInactive for DogOwner \(id)")
    guard let last = lastActivityDate else { return true }
    let cutoff = Self.calendar.date(byAdding: .day, value: -90, to: Date.now) ?? .distantPast
    return last < cutoff
  }

  /// Loyalty status based on appointment count; controlled by loyaltyThreshold cut-off.
  @Transient
  var loyaltyStatus: String {
    logger.log("Computing loyaltyStatus for DogOwner \(id), appointmentsCount: \(appointments.count)")
    switch appointments.count {
    case 0:      return "New"
    case 1:      return "🐾 First Timer"
    case 2..<loyaltyThreshold:  return "🔁 Regular"
    default:                 return "🥇 Loyal Client"
    }
  }

  /// Display title combining owner and pet names.
  @Transient
  var displayTitle: String {
    logger.log("Computing displayTitle for DogOwner \(id)")
    let names = pets.isEmpty
      ? dogName
      : pets.map(\.name).joined(separator: ", ")
    return "\(ownerName) – \(names)"
  }

  /// Formatted birthdate or “Unknown”.
  @Transient
  var formattedBirthdate: String {
    logger.log("Computing formattedBirthdate for DogOwner \(id)")
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
    logger.log("Validating image for DogOwner \(id)")
    return ImageValidator.isAcceptableImage(dogImageData)
  }

  /// Synchronously resizes the stored image data to the given width.
  func resizeImage(to width: CGFloat) -> Data? {
    ImageProcessor.resize(data: dogImageData, targetWidth: width)
  }

  /// Asynchronously resizes the stored image data to the given width.
  func resizeImageAsync(to width: CGFloat) async -> Data? {
    logger.log("resizeImageAsync called for DogOwner \(id), targetWidth: \(width)")
    return await ImageProcessor.resizeAsync(data: dogImageData, targetWidth: width)
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
    logger.log("Updating DogOwner \(id): ownerName=\(ownerName), dogName=\(dogName), breed=\(breed), contactInfo=\(contactInfo), address=\(address), notes=\(notes)")
    self.ownerName    = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogName      = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.breed        = breed.trimmingCharacters(in: .whitespacesAndNewlines)
    self.contactInfo  = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
    self.address      = address.trimmingCharacters(in: .whitespacesAndNewlines)
    self.dogImageData = dogImageData
    self.notes        = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    self.updatedDate  = Date.now
    logger.log("Updated DogOwner \(id) at \(updatedDate!)")
  }

  func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(ownerName, forKey: .ownerName)
      try container.encode(dogName, forKey: .dogName)
      try container.encode(breed, forKey: .breed)
      try container.encode(contactInfo, forKey: .contactInfo)
      try container.encodeIfPresent(email, forKey: .email)
      try container.encode(address, forKey: .address)
      try container.encode(notes, forKey: .notes)
      try container.encodeIfPresent(birthdate, forKey: .birthdate)
      try container.encode(loyaltyThreshold, forKey: .loyaltyThreshold)
      try container.encode(pets, forKey: .pets)
      try container.encode(emergencyContacts, forKey: .emergencyContacts)
      try container.encode(documentAttachments, forKey: .documentAttachments)
  }

  private enum CodingKeys: String, CodingKey {
      case id, ownerName, dogName, breed, contactInfo, email, address,
           notes, birthdate, loyaltyThreshold, pets, emergencyContacts, documentAttachments
  }

  // MARK: – Hashable

  static func == (lhs: DogOwner, rhs: DogOwner) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

#if DEBUG
import SwiftUI

extension DogOwner {
    /// Sample DogOwner for SwiftUI previews.
    static var sample: DogOwner {
        DogOwner(
            ownerName: "Jane Doe",
            dogName: "Buddy",
            breed: "Golden Retriever",
            contactInfo: "555-1234",
            email: "jane.doe@example.com",
            address: "123 Main Street, Hometown",
            dogImageData: nil,
            notes: "Loves fetch and belly rubs.",
            birthdate: Date(timeIntervalSince1970: 1_600_000_000),
            loyaltyThreshold: 10,
            pets: [],
            emergencyContacts: ["555-5678"],
            documentAttachments: []
        )
    }
}

struct DogOwner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Owner: \(DogOwner.sample.ownerName)")
            Text("Dog: \(DogOwner.sample.dogName)")
            Text("Breed: \(DogOwner.sample.breed)")
            Text("Contact: \(DogOwner.sample.contactInfo)")
            Text("Email: \(DogOwner.sample.email ?? "-")")
            Text("Address: \(DogOwner.sample.address)")
            Text("Notes: \(DogOwner.sample.notes)")
        }
        .padding()
        .previewDisplayName("DogOwner Sample Preview")
    }
}
#endif
