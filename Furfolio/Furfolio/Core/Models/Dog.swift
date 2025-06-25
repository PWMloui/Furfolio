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
    @Published var id: UUID

    @Attribute(.required)
    @Published var name: String

    @Published var breed: String?
    @Published var birthdate: Date?
    @Published var color: String?
    @Published var gender: String?
    @Published var notes: String?
    @Published var isActive: Bool

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \DogOwner.dogs)
    @Published var owner: DogOwner?

    @Relationship(deleteRule: .cascade, inverse: \Appointment.dog)
    @Published var appointments: [Appointment]

    @Relationship(deleteRule: .nullify, inverse: \Charge.dog)
    @Published var charges: [Charge]

    @Relationship(deleteRule: .cascade)
    @Published var vaccinationRecords: [VaccinationRecord]

    @Relationship(deleteRule: .cascade)
    @Published var behaviorLogs: [BehaviorLog]

    @Published var imageGallery: [Data]
    @Published var tags: [String]

    // MARK: - Metadata & Audit

    @Published var dateAdded: Date
    @Published var lastModified: Date
    @Published var lastModifiedBy: String?

    // MARK: - Tag Tokenization

    enum BusinessTag: String, CaseIterable, Codable {
        case loyal, aggressive, overdueVaccination, senior, puppy, birthdayThisMonth, specialNeeds, frequent, firstVisit
    }

    var businessTags: [BusinessTag] {
        tags.compactMap { BusinessTag(rawValue: $0) }
    }

    func addTag(_ tag: BusinessTag) {
        if !tags.contains(tag.rawValue) { tags.append(tag.rawValue) }
    }
    func removeTag(_ tag: BusinessTag) {
        tags.removeAll { $0 == tag.rawValue }
    }
    func hasTag(_ tag: BusinessTag) -> Bool {
        tags.contains(tag.rawValue)
    }

    // MARK: - Business Intelligence

    /// Calculate dog's age in years (rounded down)
    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year
    }

    /// Calculate dog's lifetime value (LTV) based on charges
    var lifetimeValue: Double {
        charges.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    /// Average appointment frequency in months
    var appointmentFrequencyMonths: Double? {
        guard appointments.count > 1 else { return nil }
        let sorted = appointments.compactMap { $0.date }.sorted()
        guard let first = sorted.first, let last = sorted.last, last > first else { return nil }
        let months = Double(Calendar.current.dateComponents([.month], from: first, to: last).month ?? 0)
        return months / Double(sorted.count - 1)
    }

    /// Loyalty score (simple heuristic for demo)
    var loyaltyScore: Double {
        var score = 0.0
        if hasTag(.loyal) { score += 1 }
        if let freq = appointmentFrequencyMonths, freq < 2.0 { score += 1 }
        if lifetimeValue > 500 { score += 1 }
        return score
    }

    // MARK: - Status & UI Convenience

    var thumbnailImage: Image? {
        guard let data = imageGallery.first, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var isBirthdayMonth: Bool {
        guard let birthdate else { return false }
        return Calendar.current.component(.month, from: birthdate) == Calendar.current.component(.month, from: Date())
    }

    var tagSummary: String {
        tags.joined(separator: ", ")
    }

    var isOverdueForVaccination: Bool {
        vaccinationRecords.contains { $0.isOverdue }
    }

    var hasRecentAggression: Bool {
        behaviorLogs.suffix(3).contains { $0.isAggressive }
    }

    var statusLabel: String {
        isActive ? (tags.first ?? "Active") : "Inactive"
    }

    // MARK: - Audit & Accessibility

    var auditSummary: String {
        "Last edited by \(lastModifiedBy ?? "unknown") on \(lastModified.formatted(.dateTime.month().day().year()))"
    }

    var accessibilityLabel: String {
        "Dog profile for \(name). \(isActive ? "Active." : "Inactive.") Age: \(age.map { String($0) } ?? "Unknown"). Breed: \(breed ?? "Unknown"). Loyalty score: \(loyaltyScore)."
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
        self.id = id
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.color = color
        self.gender = gender
        self.notes = notes
        self.isActive = isActive
        self.owner = owner
        self.appointments = appointments
        self.charges = charges
        self.vaccinationRecords = vaccinationRecords
        self.behaviorLogs = behaviorLogs
        self.imageGallery = imageGallery
        self.tags = tags
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
    }

    // MARK: - Profile Description

    var fullProfileDescription: String {
        """
        Name: \(name)
        Breed: \(breed ?? "Unknown")
        Age: \(age.map { String($0) } ?? "Unknown")
        Color: \(color ?? "Unknown")
        Gender: \(gender ?? "Unknown")
        Notes: \(notes ?? "")
        Owner: \(owner?.displayName ?? "No Owner")
        Active: \(isActive ? "Yes" : "No")
        Tags: \(tagSummary)
        Appointments: \(appointments.count)
        Charges: \(charges.count)
        LTV: $\(lifetimeValue)
        Loyalty Score: \(loyaltyScore)
        Vaccinations: \(vaccinationRecords.count)
        Behaviors: \(behaviorLogs.count)
        Added: \(dateAdded.formatted(.dateTime.month().day().year()))
        Last Modified: \(lastModified.formatted(.dateTime.month().day().year()))
        """
    }
}

// MARK: - Example Usage (for preview/testing)
#if DEBUG
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
#endif
