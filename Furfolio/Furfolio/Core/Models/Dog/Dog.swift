//
//  Dog.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated & enhanced for business intelligence, modularity, accessibility, and export.
//  Author: senpai + ChatGPT
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Dog: Identifiable, ObservableObject {
    // MARK: - Core Properties

    @Attribute(.unique)
    @Published private var _id: UUID

    @Attribute(.required)
    @Published private var _name: String

    @Published private var _breed: String?
    @Published private var _birthdate: Date?
    @Published private var _color: String?
    @Published private var _gender: String?
    @Published private var _notes: String?
    @Published private var _isActive: Bool

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \DogOwner.dogs)
    @Published var owner: DogOwner?

    @Relationship(deleteRule: .cascade, inverse: \Appointment.dog)
    @Published private var _appointments: [Appointment]

    @Relationship(deleteRule: .nullify, inverse: \Charge.dog)
    @Published private var _charges: [Charge]

    @Relationship(deleteRule: .cascade)
    @Published private var _vaccinationRecords: [VaccinationRecord]

    @Relationship(deleteRule: .cascade)
    @Published private var _behaviorLogs: [BehaviorLog]

    @Published private var _imageGallery: [Data]
    @Published private var _tags: [String]

    // MARK: - Metadata & Audit

    @Published private var _dateAdded: Date
    @Published private var _lastModified: Date
    @Published private var _lastModifiedBy: String?

    // MARK: - Audit Log Entry

    struct AuditEntry: Codable, Identifiable {
        let id = UUID()
        let date: Date
        let event: String
    }

    // MARK: - Audit Log Storage & Concurrency

    /// Actor to serialize audit logging operations safely for concurrency.
    private actor AuditLogger {
        private(set) var auditEntries: [AuditEntry] = []

        /// Adds a new audit entry asynchronously.
        /// - Parameter event: The localized event description string.
        func logEvent(_ event: String) {
            let entry = AuditEntry(date: Date(), event: event)
            auditEntries.append(entry)
        }

        /// Retrieves all audit entries asynchronously.
        func getAuditEntries() -> [AuditEntry] {
            auditEntries
        }
    }

    private let auditLogger = AuditLogger()

    // MARK: - BusinessTag Enum

    enum BusinessTag: String, CaseIterable, Codable {
        case loyal, aggressive, overdueVaccination, senior, puppy, birthdayThisMonth, specialNeeds, frequent, firstVisit
    }

    // MARK: - Public Properties with Async Audit Logging

    var id: UUID {
        _id
    }

    var name: String {
        get { _name }
        set {
            if _name != newValue {
                _name = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Name", comment: "Property name"), newValue: newValue)
                }
            }
        }
    }

    var breed: String? {
        get { _breed }
        set {
            if _breed != newValue {
                _breed = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Breed", comment: "Property name"), newValue: newValue ?? NSLocalizedString("None", comment: "No value"))
                }
            }
        }
    }

    var birthdate: Date? {
        get { _birthdate }
        set {
            if _birthdate != newValue {
                _birthdate = newValue
                Task {
                    let newValString = newValue?.formatted(.dateTime.month().day().year()) ?? NSLocalizedString("None", comment: "No value")
                    await logPropertyChange(propertyName: NSLocalizedString("Birthdate", comment: "Property name"), newValue: newValString)
                }
            }
        }
    }

    var color: String? {
        get { _color }
        set {
            if _color != newValue {
                _color = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Color", comment: "Property name"), newValue: newValue ?? NSLocalizedString("None", comment: "No value"))
                }
            }
        }
    }

    var gender: String? {
        get { _gender }
        set {
            if _gender != newValue {
                _gender = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Gender", comment: "Property name"), newValue: newValue ?? NSLocalizedString("None", comment: "No value"))
                }
            }
        }
    }

    var notes: String? {
        get { _notes }
        set {
            if _notes != newValue {
                _notes = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Notes", comment: "Property name"), newValue: newValue ?? "")
                }
            }
        }
    }

    var isActive: Bool {
        get { _isActive }
        set {
            if _isActive != newValue {
                _isActive = newValue
                Task {
                    await logPropertyChange(propertyName: NSLocalizedString("Active Status", comment: "Property name"), newValue: newValue ? NSLocalizedString("Active", comment: "Status") : NSLocalizedString("Inactive", comment: "Status"))
                }
            }
        }
    }

    var appointments: [Appointment] {
        get { _appointments }
        set {
            _appointments = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Appointments updated, total count: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var charges: [Charge] {
        get { _charges }
        set {
            _charges = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Charges updated, total count: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var vaccinationRecords: [VaccinationRecord] {
        get { _vaccinationRecords }
        set {
            _vaccinationRecords = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Vaccination records updated, total count: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var behaviorLogs: [BehaviorLog] {
        get { _behaviorLogs }
        set {
            _behaviorLogs = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Behavior logs updated, total count: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var imageGallery: [Data] {
        get { _imageGallery }
        set {
            _imageGallery = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Image gallery updated, total images: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var tags: [String] {
        get { _tags }
        set {
            _tags = newValue
            Task {
                await logAuditEvent(String(format: NSLocalizedString("Tags updated, total count: %d", comment: "Audit event"), newValue.count))
            }
        }
    }

    var dateAdded: Date {
        _dateAdded
    }

    var lastModified: Date {
        _lastModified
    }

    var lastModifiedBy: String? {
        _lastModifiedBy
    }

    // MARK: - Tag Tokenization

    var businessTags: [BusinessTag] {
        tags.compactMap { BusinessTag(rawValue: $0) }
    }

    /// Adds a business tag asynchronously with audit logging.
    /// - Parameter tag: The BusinessTag to add.
    func addTag(_ tag: BusinessTag) async {
        if !tags.contains(tag.rawValue) {
            _tags.append(tag.rawValue)
            await logAuditEvent(String(format: NSLocalizedString("Tag added: %@", comment: "Audit event for tag addition"), tag.rawValue))
        }
    }

    /// Removes a business tag asynchronously with audit logging.
    /// - Parameter tag: The BusinessTag to remove.
    func removeTag(_ tag: BusinessTag) async {
        if _tags.removeAll(where: { $0 == tag.rawValue }) > 0 {
            await logAuditEvent(String(format: NSLocalizedString("Tag removed: %@", comment: "Audit event for tag removal"), tag.rawValue))
        }
    }

    /// Checks if a tag exists.
    /// - Parameter tag: The BusinessTag to check.
    /// - Returns: Boolean indicating presence of tag.
    func hasTag(_ tag: BusinessTag) -> Bool {
        tags.contains(tag.rawValue)
    }

    // MARK: - Business Intelligence

    /// Calculate dog's age in years (rounded down)
    @Attribute(.transient)
    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year
    }

    /// Calculate dog's lifetime value (LTV) based on charges
    @Attribute(.transient)
    var lifetimeValue: Double {
        charges.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    /// Average appointment frequency in months
    @Attribute(.transient)
    var appointmentFrequencyMonths: Double? {
        guard appointments.count > 1 else { return nil }
        let sorted = appointments.compactMap { $0.date }.sorted()
        guard let first = sorted.first, let last = sorted.last, last > first else { return nil }
        let months = Double(Calendar.current.dateComponents([.month], from: first, to: last).month ?? 0)
        return months / Double(sorted.count - 1)
    }

    /// Loyalty score (simple heuristic for demo)
    @Attribute(.transient)
    var loyaltyScore: Double {
        var score = 0.0
        if hasTag(.loyal) { score += 1 }
        if let freq = appointmentFrequencyMonths, freq < 2.0 { score += 1 }
        if lifetimeValue > 500 { score += 1 }
        return score
    }

    // MARK: - Status & UI Convenience

    @Attribute(.transient)
    var thumbnailImage: Image? {
        guard let data = imageGallery.first, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    @Attribute(.transient)
    var isBirthdayMonth: Bool {
        guard let birthdate else { return false }
        return Calendar.current.component(.month, from: birthdate) == Calendar.current.component(.month, from: Date())
    }

    @Attribute(.transient)
    var tagSummary: String {
        tags.joined(separator: ", ")
    }

    @Attribute(.transient)
    var isOverdueForVaccination: Bool {
        vaccinationRecords.contains { $0.isOverdue }
    }

    @Attribute(.transient)
    var hasRecentAggression: Bool {
        behaviorLogs.suffix(3).contains { $0.isAggressive }
    }

    @Attribute(.transient)
    var statusLabel: String {
        isActive ? (tags.first ?? NSLocalizedString("Active", comment: "Status label")) : NSLocalizedString("Inactive", comment: "Status label")
    }

    // MARK: - Audit & Accessibility

    @Attribute(.transient)
    var auditSummary: String {
        String(format: NSLocalizedString("Last edited by %@ on %@", comment: "Audit summary"),
               lastModifiedBy ?? NSLocalizedString("unknown", comment: "Unknown user"),
               lastModified.formatted(.dateTime.month().day().year()))
    }

    @Attribute(.transient)
    var accessibilityLabel: String {
        String(format: NSLocalizedString("Dog profile for %@. %@ Age: %@. Breed: %@. Loyalty score: %.1f.", comment: "Accessibility label"),
               name,
               isActive ? NSLocalizedString("Active.", comment: "Active status") : NSLocalizedString("Inactive.", comment: "Inactive status"),
               age.map { String($0) } ?? NSLocalizedString("Unknown", comment: "Unknown age"),
               breed ?? NSLocalizedString("Unknown", comment: "Unknown breed"),
               loyaltyScore)
    }

    // MARK: - Data Export

    func exportJSON() -> String? {
        struct DogExport: Codable {
            let id: UUID
            let name: String
            let breed: String?
            let age: Int?
            let color: String?
            let gender: String?
            let tags: [String]
            let isActive: Bool
            let dateAdded: Date
            let lastModified: Date
        }
        let export = DogExport(
            id: id, name: name, breed: breed, age: age, color: color, gender: gender,
            tags: tags, isActive: isActive, dateAdded: dateAdded, lastModified: lastModified
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(export) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    // MARK: - Audit Logging Methods

    /// Logs a generic audit event asynchronously.
    /// - Parameter event: The localized event description.
    func logAuditEvent(_ event: String) async {
        await auditLogger.logEvent(event)
    }

    /// Logs a property change asynchronously with property name and new value.
    /// - Parameters:
    ///   - propertyName: Localized name of the property.
    ///   - newValue: New value description.
    func logPropertyChange(propertyName: String, newValue: String) async {
        let event = String(format: NSLocalizedString("Property '%@' changed to '%@'", comment: "Audit event for property change"), propertyName, newValue)
        await logAuditEvent(event)
    }

    /// Adds an appointment asynchronously with audit logging.
    /// - Parameter appointment: The Appointment to add.
    func addAppointment(_ appointment: Appointment) async {
        _appointments.append(appointment)
        await logAuditEvent(String(format: NSLocalizedString("Appointment added on %@", comment: "Audit event"), appointment.date?.formatted(.dateTime.month().day().year()) ?? NSLocalizedString("Unknown date", comment: "Unknown date")))
    }

    /// Removes an appointment asynchronously with audit logging.
    /// - Parameter appointment: The Appointment to remove.
    func removeAppointment(_ appointment: Appointment) async {
        if let index = _appointments.firstIndex(where: { $0.id == appointment.id }) {
            _appointments.remove(at: index)
            await logAuditEvent(String(format: NSLocalizedString("Appointment removed on %@", comment: "Audit event"), appointment.date?.formatted(.dateTime.month().day().year()) ?? NSLocalizedString("Unknown date", comment: "Unknown date")))
        }
    }

    /// Adds a charge asynchronously with audit logging.
    /// - Parameter charge: The Charge to add.
    func addCharge(_ charge: Charge) async {
        _charges.append(charge)
        await logAuditEvent(String(format: NSLocalizedString("Charge added: $%.2f", comment: "Audit event"), charge.amount ?? 0))
    }

    /// Removes a charge asynchronously with audit logging.
    /// - Parameter charge: The Charge to remove.
    func removeCharge(_ charge: Charge) async {
        if let index = _charges.firstIndex(where: { $0.id == charge.id }) {
            _charges.remove(at: index)
            await logAuditEvent(String(format: NSLocalizedString("Charge removed: $%.2f", comment: "Audit event"), charge.amount ?? 0))
        }
    }

    /// Adds a vaccination record asynchronously with audit logging.
    /// - Parameter record: The VaccinationRecord to add.
    func addVaccinationRecord(_ record: VaccinationRecord) async {
        _vaccinationRecords.append(record)
        await logAuditEvent(String(format: NSLocalizedString("Vaccination record added: %@", comment: "Audit event"), record.vaccineName ?? NSLocalizedString("Unknown vaccine", comment: "Unknown vaccine")))
    }

    /// Removes a vaccination record asynchronously with audit logging.
    /// - Parameter record: The VaccinationRecord to remove.
    func removeVaccinationRecord(_ record: VaccinationRecord) async {
        if let index = _vaccinationRecords.firstIndex(where: { $0.id == record.id }) {
            _vaccinationRecords.remove(at: index)
            await logAuditEvent(String(format: NSLocalizedString("Vaccination record removed: %@", comment: "Audit event"), record.vaccineName ?? NSLocalizedString("Unknown vaccine", comment: "Unknown vaccine")))
        }
    }

    /// Adds a behavior log asynchronously with audit logging.
    /// - Parameter log: The BehaviorLog to add.
    func addBehaviorLog(_ log: BehaviorLog) async {
        _behaviorLogs.append(log)
        await logAuditEvent(String(format: NSLocalizedString("Behavior log added: %@", comment: "Audit event"), log.description ?? NSLocalizedString("No description", comment: "No description")))
    }

    /// Removes a behavior log asynchronously with audit logging.
    /// - Parameter log: The BehaviorLog to remove.
    func removeBehaviorLog(_ log: BehaviorLog) async {
        if let index = _behaviorLogs.firstIndex(where: { $0.id == log.id }) {
            _behaviorLogs.remove(at: index)
            await logAuditEvent(String(format: NSLocalizedString("Behavior log removed: %@", comment: "Audit event"), log.description ?? NSLocalizedString("No description", comment: "No description")))
        }
    }

    /// Adds image data asynchronously with audit logging.
    /// - Parameter imageData: The image data to add.
    func addImageData(_ imageData: Data) async {
        _imageGallery.append(imageData)
        await logAuditEvent(NSLocalizedString("Image added to gallery", comment: "Audit event"))
    }

    /// Removes image data asynchronously with audit logging.
    /// - Parameter imageData: The image data to remove.
    func removeImageData(_ imageData: Data) async {
        if let index = _imageGallery.firstIndex(of: imageData) {
            _imageGallery.remove(at: index)
            await logAuditEvent(NSLocalizedString("Image removed from gallery", comment: "Audit event"))
        }
    }

    /// Asynchronously returns the audit entries as a JSON string.
    /// - Returns: JSON string of audit entries or nil on failure.
    func exportAuditLog() async -> String? {
        let entries = await auditLogger.getAuditEntries()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(entries) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Asynchronously returns a summary of profile changes for audit.
    /// - Returns: A string summarizing key profile properties.
    func auditProfileSummary() async -> String {
        let summary = """
        \(NSLocalizedString("Name", comment: "Property name")): \(name)
        \(NSLocalizedString("Breed", comment: "Property name")): \(breed ?? NSLocalizedString("None", comment: "No value"))
        \(NSLocalizedString("Birthdate", comment: "Property name")): \(birthdate?.formatted(.dateTime.month().day().year()) ?? NSLocalizedString("None", comment: "No value"))
        \(NSLocalizedString("Color", comment: "Property name")): \(color ?? NSLocalizedString("None", comment: "No value"))
        \(NSLocalizedString("Gender", comment: "Property name")): \(gender ?? NSLocalizedString("None", comment: "No value"))
        \(NSLocalizedString("Active Status", comment: "Property name")): \(isActive ? NSLocalizedString("Active", comment: "Status") : NSLocalizedString("Inactive", comment: "Status"))
        """
        await logAuditEvent(String(format: NSLocalizedString("Profile summary accessed:\n%@", comment: "Audit event"), summary))
        return summary
    }

    // MARK: - Snapshot for History/Undo

    struct Snapshot: Codable {
        let date: Date
        let name: String
        let breed: String?
        let color: String?
        let isActive: Bool
    }

    func snapshot() -> Snapshot {
        Snapshot(date: lastModified, name: name, breed: breed, color: color, isActive: isActive)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        breed: String? = nil,
        birthdate: Date? = nil,
        color: String? = nil,
        gender: String? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        owner: DogOwner? = nil,
        appointments: [Appointment] = [],
        charges: [Charge] = [],
        vaccinationRecords: [VaccinationRecord] = [],
        behaviorLogs: [BehaviorLog] = [],
        imageGallery: [Data] = [],
        tags: [String] = [],
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        lastModifiedBy: String? = nil
    ) {
        self._id = id
        self._name = name
        self._breed = breed
        self._birthdate = birthdate
        self._color = color
        self._gender = gender
        self._notes = notes
        self._isActive = isActive
        self.owner = owner
        self._appointments = appointments
        self._charges = charges
        self._vaccinationRecords = vaccinationRecords
        self._behaviorLogs = behaviorLogs
        self._imageGallery = imageGallery
        self._tags = tags
        self._dateAdded = dateAdded
        self._lastModified = lastModified
        self._lastModifiedBy = lastModifiedBy
    }

    // MARK: - Profile Description

    @Attribute(.transient)
    var fullProfileDescription: String {
        """
        \(NSLocalizedString("Name", comment: "Label")): \(name)
        \(NSLocalizedString("Breed", comment: "Label")): \(breed ?? NSLocalizedString("Unknown", comment: "Unknown value"))
        \(NSLocalizedString("Age", comment: "Label")): \(age.map { String($0) } ?? NSLocalizedString("Unknown", comment: "Unknown value"))
        \(NSLocalizedString("Color", comment: "Label")): \(color ?? NSLocalizedString("Unknown", comment: "Unknown value"))
        \(NSLocalizedString("Gender", comment: "Label")): \(gender ?? NSLocalizedString("Unknown", comment: "Unknown value"))
        \(NSLocalizedString("Notes", comment: "Label")): \(notes ?? "")
        \(NSLocalizedString("Owner", comment: "Label")): \(owner?.displayName ?? NSLocalizedString("No Owner", comment: "No owner"))
        \(NSLocalizedString("Active", comment: "Label")): \(isActive ? NSLocalizedString("Yes", comment: "Yes") : NSLocalizedString("No", comment: "No"))
        \(NSLocalizedString("Tags", comment: "Label")): \(tagSummary)
        \(NSLocalizedString("Appointments", comment: "Label")): \(appointments.count)
        \(NSLocalizedString("Charges", comment: "Label")): \(charges.count)
        \(NSLocalizedString("LTV", comment: "Label")): $\(lifetimeValue)
        \(NSLocalizedString("Loyalty Score", comment: "Label")): \(loyaltyScore)
        \(NSLocalizedString("Vaccinations", comment: "Label")): \(vaccinationRecords.count)
        \(NSLocalizedString("Behaviors", comment: "Label")): \(behaviorLogs.count)
        \(NSLocalizedString("Added", comment: "Label")): \(dateAdded.formatted(.dateTime.month().day().year()))
        \(NSLocalizedString("Last Modified", comment: "Label")): \(lastModified.formatted(.dateTime.month().day().year()))
        """
    }
}

// MARK: - Example Usage (for preview/testing)
#if DEBUG
import XCTest

extension Dog {
    static var preview: Dog {
        Dog(
            name: "Baxter",
            breed: "Golden Retriever",
            birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
            color: "Golden",
            gender: "Male",
            notes: "Friendly, loves water.",
            tags: [BusinessTag.loyal.rawValue, BusinessTag.birthdayThisMonth.rawValue],
            imageGallery: [],
            isActive: true
        )
    }
    static var previewSenior: Dog {
        Dog(
            name: "Sasha",
            breed: "Poodle",
            birthdate: Calendar.current.date(byAdding: .year, value: -12, to: Date()),
            color: "White",
            gender: "Female",
            notes: "Needs special attention. Senior client.",
            tags: [BusinessTag.senior.rawValue, BusinessTag.specialNeeds.rawValue],
            isActive: true
        )
    }
    static var previewAggressive: Dog {
        Dog(
            name: "Rocky",
            breed: "Bulldog",
            birthdate: Calendar.current.date(byAdding: .year, value: -5, to: Date()),
            color: "Brown",
            gender: "Male",
            notes: "Recent aggression reported.",
            tags: [BusinessTag.aggressive.rawValue],
            isActive: true
        )
    }
}

/// SwiftUI PreviewProvider demonstrating async audit logging usage.
struct Dog_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dog Preview")
            .task {
                let dog = Dog.preview
                await dog.addTag(.frequent)
                await dog.removeTag(.loyal)
                dog.name = "Baxter Updated"
                _ = await dog.auditProfileSummary()
                if let auditLogJSON = await dog.exportAuditLog() {
                    print("Audit Log JSON:\n\(auditLogJSON)")
                }
            }
    }
}
#endif
