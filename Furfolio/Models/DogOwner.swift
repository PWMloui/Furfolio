//
//  DogOwner.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhancements for personalization, asynchronous processing, extended pet information, attachments, and record history.

import SwiftData
import Foundation
import UIKit

// MARK: - Nested Pet Model
struct Pet: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var breed: String
    var birthdate: Date?
    var specialInstructions: String?
    
    /// Returns the pet's age in years, if available.
    var age: Int? {
        guard let birthdate = birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year
    }
}

@Model
final class DogOwner: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerName: String
    // Retain primary pet fields for backward compatibility
    var dogName: String
    var breed: String
    var contactInfo: String
    var address: String
    @Attribute(.externalStorage) var dogImage: Data? // Store large data externally
    var notes: String
    var birthdate: Date? // Optional birthdate for the dog

    // Relationships
    @Relationship(deleteRule: .cascade) var appointments: [Appointment] = []
    @Relationship(deleteRule: .cascade) var charges: [Charge] = []
    
    // New: Extended pet information as an array of Pet models.
    @Attribute(.transformable(by: NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue))
    var pets: [Pet] = []
    
    // New: Additional owner information as an array of strings.
    @Attribute(.transformable(by: NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue))
    var emergencyContacts: [String] = []
    
    // New: Document attachments (e.g., scanned forms, records) stored as URLs.
    @Attribute(.transformable(by: NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue))
    var documentAttachments: [URL] = []
    
    // New: Record history/audit fields.
    var createdDate: Date?
    var updatedDate: Date?
    
    // MARK: - Initializer
    init(
        ownerName: String,
        dogName: String,
        breed: String,
        contactInfo: String,
        address: String,
        dogImage: Data? = nil,
        notes: String = "",
        birthdate: Date? = nil,
        emergencyContacts: [String] = [],
        documentAttachments: [URL] = []
    ) {
        self.id = UUID()
        self.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dogName = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contactInfo = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dogImage = dogImage
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.birthdate = birthdate
        self.emergencyContacts = emergencyContacts
        self.documentAttachments = documentAttachments
        self.createdDate = Date()
        self.updatedDate = nil
    }
    
    // MARK: - Computed Properties
    /// The most recent activity date (appointment or charge) for this owner.
    var lastActivityDate: Date? {
        let allDates = (charges.map { $0.date } + appointments.map { $0.date }).sorted(by: >)
        return allDates.first
    }

    /// Returns true if the owner has had no activity in the last 90 days.
    var isInactive: Bool {
        guard let last = lastActivityDate else { return true }
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        return last < ninetyDaysAgo
    }

    /// Loyalty status based on total number of appointments.
    var loyaltyStatus: String {
        switch appointments.count {
        case 0: return "New"
        case 1: return "🐾 First Timer"
        case 2...9: return "🔁 Monthly Regular"
        default: return "🥇 Loyal Client"
        }
    }
    
    /// A combined title for display purposes. If additional pets are available, their names are included.
    var displayTitle: String {
        let petNames: String
        if !pets.isEmpty {
            petNames = pets.map { $0.name }.joined(separator: ", ")
        } else {
            petNames = dogName
        }
        return "\(ownerName) - \(petNames)"
    }
    
    /// Returns the dog's (or primary pet's) birthdate formatted as "MM/DD/YYYY", or "Unknown" if not provided.
    var formattedBirthdate: String {
        guard let birthdate = birthdate else { return NSLocalizedString("Unknown", comment: "Birthdate unknown") }
        return birthdate.formatted(.dateTime.month().day().year())
    }
    
    /// Indicates whether the owner's essential fields are non-empty.
    var isValidOwner: Bool {
        !ownerName.isEmpty && !dogName.isEmpty && !breed.isEmpty
    }
    
    var hasUpcomingAppointments: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return appointments.contains { $0.date > today }
    }
    
    var nextAppointment: Appointment? {
        appointments
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
            .first
    }
    
    var totalCharges: Double {
        charges.reduce(0) { $0 + $1.amount }
    }
    
    var isActive: Bool {
        hasUpcomingAppointments || recentActivity
    }
    
    private var recentActivity: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return charges.contains { $0.date >= thirtyDaysAgo } ||
               appointments.contains { $0.date >= thirtyDaysAgo }
    }
    
    /// A searchable text that includes all key owner and pet details.
    var searchableText: String {
        var baseText = "\(ownerName) \(dogName) \(breed) \(contactInfo) \(address) \(notes)"
        if !emergencyContacts.isEmpty {
            baseText.append(" " + emergencyContacts.joined(separator: " "))
        }
        return baseText
    }
    
    var dogUIImage: UIImage? {
        guard let data = dogImage else { return nil }
        return UIImage(data: data)
    }
    
    /// Calculates the dog's age from the birthdate, if available.
    var age: Int? {
        guard let birthdate = birthdate else { return nil }
        return calculateAge(from: birthdate)
    }
    
    var pastAppointmentsCount: Int {
        appointments.filter { $0.date < Date() }.count
    }
    
    var upcomingAppointmentsCount: Int {
        appointments.filter { $0.date > Date() }.count
    }
    
    // MARK: - Methods
    
    /// Validates the dog image by checking file size, dimensions, and format.
    func isValidImage() -> Bool {
        guard let data = dogImage, let image = UIImage(data: data) else { return false }
        let maxSizeMB = 5.0
        let dataSizeMB = Double(data.count) / (1024.0 * 1024.0)
        let isValidSize = dataSizeMB <= maxSizeMB
        let isValidDimensions = image.size.width > 100 && image.size.height > 100
        let isValidFormat = (data.isJPEG || data.isPNG)
        return isValidSize && isValidDimensions && isValidFormat
    }
    
    /// Synchronously resizes the dog image to a specified width while maintaining aspect ratio.
    func resizeImage(targetWidth: CGFloat) -> Data? {
        guard let data = dogImage, let image = UIImage(data: data) else { return nil }
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        let newSize = CGSize(width: targetWidth, height: targetHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
    
    /// Asynchronously resizes the dog image using async/await, keeping the main thread free for smooth UI animations.
    func asyncResizeImage(targetWidth: CGFloat) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resizedData = self.resizeImage(targetWidth: targetWidth)
                continuation.resume(returning: resizedData)
            }
        }
    }
    
    /// Removes all past appointments from the owner's records.
    func removePastAppointments() {
        appointments.removeAll { $0.date < Date() }
    }
    
    /// Retrieves charges within a given date range.
    func chargesInDateRange(startDate: Date, endDate: Date) -> [Charge] {
        charges.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    /// Adds a new charge, logging the action for debugging and enabling UI feedback mechanisms.
    func addCharge(date: Date, type: Charge.ServiceType, amount: Double, notes: String = "") {
        guard amount > 0 else { return }
        let newCharge = Charge(date: date, type: type, amount: amount, dogOwner: self, notes: notes)
        charges.append(newCharge)
        print("Charge added: \(newCharge.formattedAmount) on \(newCharge.formattedDate)")
    }
    
    /// Adds a new appointment, ensuring that the date is in the future and logging the event.
    func addAppointment(date: Date, serviceType: Appointment.ServiceType, notes: String = "") {
        guard date > Date() else { return }
        let newAppointment = Appointment(date: date, dogOwner: self, serviceType: serviceType, notes: notes)
        appointments.append(newAppointment)
        print("Appointment added on \(newAppointment.formattedDate)")
    }
    
    /// Updates the owner's information with trimmed input, updates the record history, and logs the update for UI feedback.
    func updateInfo(
        ownerName: String,
        dogName: String,
        breed: String,
        contactInfo: String,
        address: String,
        dogImage: Data?,
        notes: String
    ) {
        self.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dogName = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contactInfo = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dogImage = dogImage
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedDate = Date()
        print("Owner info updated for \(displayTitle)")
    }
    
    /// Analyzes behavioral notes to provide a summary that the UI can use for personalized feedback.
    func analyzeBehavior() -> String {
        let lowercasedNotes = notes.lowercased()
        if lowercasedNotes.contains("anxious") {
            return NSLocalizedString("Pet appears anxious and may need additional care.", comment: "Behavioral analysis: Anxious pet")
        } else if lowercasedNotes.contains("aggressive") {
            return NSLocalizedString("Pet has shown signs of aggression. Handle with caution.", comment: "Behavioral analysis: Aggressive pet")
        } else if lowercasedNotes.contains("shy") {
            return NSLocalizedString("Pet appears shy and may need gentle handling.", comment: "Behavioral analysis: Shy pet")
        } else if lowercasedNotes.contains("playful") {
            return NSLocalizedString("Pet is playful and enjoys interactive playtime.", comment: "Behavioral analysis: Playful pet")
        } else if lowercasedNotes.contains("timid") {
            return NSLocalizedString("Pet is timid and may require extra patience.", comment: "Behavioral analysis: Timid pet")
        }
        return NSLocalizedString("No significant behavioral concerns noted.", comment: "Behavioral analysis: No issues")
    }
    
    /// Summarizes the owner's activity for quick reference in dashboards or detail views.
    func summarizeActivity() -> String {
        let summary = """
        Name: \(ownerName)
        Dog: \(dogName) (\(breed))
        Total Charges: \(totalCharges.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
        Upcoming Appointments: \(upcomingAppointmentsCount)
        Recent Activity: \(isActive ? "Active" : "Inactive")
        """
        return summary
    }
    
    // MARK: - Tagging (New Feature)
    
    /// Generates tags based on breed and behavioral notes to aid in categorization and UI filtering.
    var tags: [String] {
        var tagList = [String]()
        if breed.lowercased() == "bulldog" {
            tagList.append("Stubborn")
        }
        if notes.lowercased().contains("timid") {
            tagList.append("Timid")
        }
        return tagList
    }

    // MARK: - Pet Birthday Reminders
    /// Returns true if the (primary) pet has a birthday in the current month.
    var hasBirthdayThisMonth: Bool {
        guard let birthdate = birthdate else { return false }
        let now = Date()
        return Calendar.current.component(.month, from: birthdate) == Calendar.current.component(.month, from: now)
    }

    // MARK: - Customer Retention Alerts
    /// Returns true if the owner is at risk of churn (no activity in 60+ days).
    var retentionRisk: Bool {
        guard let last = lastActivityDate else { return true }
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? .distantPast
        return last < sixtyDaysAgo
    }

    // MARK: - Customer Lifetime Value Tag
    /// Returns a tag string if the owner's total charges are over $1000.
    var lifetimeValueTag: String? {
        return totalCharges > 1000 ? "💸 Top Spender" : nil
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the age (in years) of the dog from the given birthdate.
    private func calculateAge(from birthdate: Date) -> Int? {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
        return ageComponents.year
    }
}

extension Data {
    var isJPEG: Bool {
        // JPEG images start with bytes: 0xFF 0xD8 and end with 0xFF 0xD9
        return self.starts(with: [0xFF, 0xD8]) && self.suffix(2) == [0xFF, 0xD9]
    }
    
    var isPNG: Bool {
        // PNG images start with: 0x89 0x50 0x4E 0x47
        return self.starts(with: [0x89, 0x50, 0x4E, 0x47])
    }
}
