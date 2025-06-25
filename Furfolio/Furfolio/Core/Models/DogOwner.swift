//
//  DogOwner.swift
//  Furfolio
//
//  Enhanced, unified, and ready for multi-user/offline-first/analytics.
//
import Foundation
import SwiftData
import SwiftUI

@Model
final class DogOwner: Identifiable, ObservableObject {
    @Attribute(.unique)
    var id: UUID

    @Published var ownerName: String
    @Published var email: String?
    @Published var address: String?
    @Published var phone: String?
    @Published var emergencyContact: String?
    @Published var notes: String?
    @Published var isActive: Bool
    @Published var role: String
    @Published var preferredContact: String?
    @Published var preferredLanguage: String?
    @Published var dateAdded: Date
    @Published var lastModified: Date
    @Published var lastModifiedBy: String?
    @Published var auditLog: [String]

    @Relationship(deleteRule: .cascade, inverse: \Dog.owner)
    @Published var dogs: [Dog]

    @Relationship(deleteRule: .cascade, inverse: \Appointment.owner)
    @Published var appointments: [Appointment]

    @Relationship(deleteRule: .cascade, inverse: \Charge.owner)
    @Published var charges: [Charge]

    @Published var badgeTypes: [String]

    // MARK: - Tag/Badge Tokenization

    enum OwnerBadgeType: String, CaseIterable, Codable {
        case loyal, friendly, atRisk, bigSpender, newClient, multiPet, feedbackChampion, platinum
    }

    var ownerBadges: [OwnerBadgeType] {
        badgeTypes.compactMap { OwnerBadgeType(rawValue: $0) }
    }
    func addBadge(_ badge: OwnerBadgeType) {
        if !badgeTypes.contains(badge.rawValue) { badgeTypes.append(badge.rawValue) }
    }
    func removeBadge(_ badge: OwnerBadgeType) {
        badgeTypes.removeAll { $0 == badge.rawValue }
    }
    func hasBadge(_ badge: OwnerBadgeType) -> Bool {
        badgeTypes.contains(badge.rawValue)
    }

    // MARK: - Analytics/Computed

    /// Total amount spent by this owner
    var totalSpent: Double {
        charges.reduce(0) { $0 + $1.amount }
    }
    /// Number of dogs
    var dogCount: Int { dogs.count }
    /// Average spend per appointment
    var averageSpendPerAppointment: Double {
        let completed = completedAppointments
        guard !completed.isEmpty else { return 0 }
        let relevantCharges = completed.flatMap { appt in
            charges.filter { $0.appointmentID == appt.id }
        }
        let total = relevantCharges.reduce(0) { $0 + $1.amount }
        return total / Double(completed.count)
    }
    /// Spend by year
    func spend(forYear year: Int) -> Double {
        charges.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.reduce(0) { $0 + $1.amount }
    }
    /// Appointments completed
    var completedAppointments: [Appointment] {
        appointments.filter { $0.status == .completed }
    }
    /// Most recent appointment date
    var lastAppointmentDate: Date? {
        appointments.sorted(by: { $0.date > $1.date }).first?.date
    }
    /// True if last appointment > 60 days ago
    var isRetentionRisk: Bool {
        guard let last = lastAppointmentDate else { return true }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0 > 60
    }
    /// Loyalty tier
    var loyaltyTier: String {
        switch totalSpent {
        case 0..<500: "Bronze"
        case 500..<2000: "Silver"
        case 2000..<5000: "Gold"
        default: "Platinum"
        }
    }
    /// Average interval between appointments (in days)
    var averageAppointmentInterval: Double? {
        let dates = appointments.map { $0.date }.sorted()
        guard dates.count > 1 else { return nil }
        let intervals = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 86400 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }
    /// True if any active dogs
    var hasActiveDogs: Bool {
        dogs.contains(where: { $0.isActive })
    }
    /// Display name for UI
    var displayName: String {
        ownerName.isEmpty ? "Unnamed Owner" : ownerName
    }

    // MARK: - Audit/Export

    /// Show most recent N audit log entries
    func recentAuditLog(_ count: Int = 3) -> [String] {
        Array(auditLog.suffix(count))
    }
    /// Export audit log as plain text
    var auditLogText: String {
        auditLog.joined(separator: "\n")
    }
    /// Export as JSON for compliance/integration
    func exportJSON() -> String? {
        struct OwnerExport: Codable {
            let id: UUID, ownerName: String, email: String?, phone: String?, address: String?
            let badgeTypes: [String], isActive: Bool, loyaltyTier: String, totalSpent: Double
        }
        let export = OwnerExport(
            id: id, ownerName: ownerName, email: email, phone: phone, address: address,
            badgeTypes: badgeTypes, isActive: isActive, loyaltyTier: loyaltyTier, totalSpent: totalSpent
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Accessibility

    var accessibilityLabel: String {
        """
        Owner profile for \(displayName).
        Loyalty tier: \(loyaltyTier).
        Total spent: $\(String(format: "%.0f", totalSpent)).
        Active dogs: \(dogCount).
        """
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        ownerName: String,
        email: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        emergencyContact: String? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        role: String = "Owner",
        preferredContact: String? = nil,
        preferredLanguage: String? = nil,
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        lastModifiedBy: String? = nil,
        auditLog: [String] = [],
        dogs: [Dog] = [],
        appointments: [Appointment] = [],
        charges: [Charge] = [],
        badgeTypes: [String] = []
    ) {
        self.id = id
        self.ownerName = ownerName
        self.email = email
        self.address = address
        self.phone = phone
        self.emergencyContact = emergencyContact
        self.notes = notes
        self.isActive = isActive
        self.role = role
        self.preferredContact = preferredContact
        self.preferredLanguage = preferredLanguage
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
        self.dogs = dogs
        self.appointments = appointments
        self.charges = charges
        self.badgeTypes = badgeTypes
    }

    // MARK: - Utility

    func addAuditLogEntry(_ entry: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(timestamp)] \(entry)")
        lastModified = Date()
    }
    func updateModification(user: String?) {
        lastModified = Date()
        lastModifiedBy = user
    }

    // MARK: - Previews

    static let preview = DogOwner(
        ownerName: "Jane Doe",
        email: "jane.doe@example.com",
        phone: "555-1234",
        emergencyContact: "John Doe - 555-5678",
        notes: "Prefers morning appointments.",
        isActive: true,
        role: "Owner",
        preferredContact: "email",
        preferredLanguage: "en",
        lastModifiedBy: "admin",
        auditLog: ["Created record on \(Date())"],
        dogs: [],
        appointments: [],
        charges: [],
        badgeTypes: [OwnerBadgeType.loyal.rawValue, OwnerBadgeType.friendly.rawValue]
    )

    static let previewAtRisk = DogOwner(
        ownerName: "Lisa Chen",
        email: "lisa.chen@email.com",
        phone: "555-7890",
        notes: "Last appointment >3 months ago.",
        isActive: true,
        role: "Owner",
        preferredContact: "sms",
        badgeTypes: [OwnerBadgeType.atRisk.rawValue, OwnerBadgeType.newClient.rawValue]
    )
}
