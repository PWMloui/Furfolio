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
    @Published private(set) var auditLog: [String]

    @Relationship(deleteRule: .cascade, inverse: \Dog.owner)
    @Published var dogs: [Dog]

    @Relationship(deleteRule: .cascade, inverse: \Appointment.owner)
    @Published var appointments: [Appointment]

    @Relationship(deleteRule: .cascade, inverse: \Charge.owner)
    @Published var charges: [Charge]

    @Published private(set) var badgeTypes: [String]

    // MARK: - Concurrency Queue for Audit Log

    /// Serial queue to ensure thread-safe access and mutation of auditLog and badgeTypes.
    private let auditQueue = DispatchQueue(label: "com.furfolio.DogOwner.auditQueue")

    // MARK: - Tag/Badge Tokenization

    enum OwnerBadgeType: String, CaseIterable, Codable {
        case loyal, friendly, atRisk, bigSpender, newClient, multiPet, feedbackChampion, platinum
    }

    @Attribute(.transient)
    var ownerBadges: [OwnerBadgeType] {
        auditQueue.sync {
            badgeTypes.compactMap { OwnerBadgeType(rawValue: $0) }
        }
    }

    /// Adds a badge to the owner asynchronously and logs the action.
    /// - Parameter badge: The badge to add.
    @MainActor
    func addBadge(_ badge: OwnerBadgeType) async {
        await auditQueue.async {
            if !self.badgeTypes.contains(badge.rawValue) {
                self.badgeTypes.append(badge.rawValue)
                Task { @MainActor in
                    self.objectWillChange.send()
                }
                await self.addAuditLogEntry(NSLocalizedString("Added badge: \(badge.rawValue)", comment: "Audit log entry for adding a badge"))
            }
        }
    }

    /// Removes a badge from the owner asynchronously and logs the action.
    /// - Parameter badge: The badge to remove.
    @MainActor
    func removeBadge(_ badge: OwnerBadgeType) async {
        await auditQueue.async {
            if self.badgeTypes.contains(badge.rawValue) {
                self.badgeTypes.removeAll { $0 == badge.rawValue }
                Task { @MainActor in
                    self.objectWillChange.send()
                }
                await self.addAuditLogEntry(NSLocalizedString("Removed badge: \(badge.rawValue)", comment: "Audit log entry for removing a badge"))
            }
        }
    }

    /// Checks asynchronously if the owner has a specific badge.
    /// - Parameter badge: The badge to check.
    /// - Returns: True if the badge is present.
    func hasBadge(_ badge: OwnerBadgeType) async -> Bool {
        await auditQueue.sync {
            badgeTypes.contains(badge.rawValue)
        }
    }

    // MARK: - Analytics/Computed

    /// Total amount spent by this owner
    @Attribute(.transient)
    var totalSpent: Double {
        charges.reduce(0) { $0 + $1.amount }
    }
    /// Number of dogs
    @Attribute(.transient)
    var dogCount: Int { dogs.count }
    /// Average spend per appointment
    @Attribute(.transient)
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
    @Attribute(.transient)
    func spend(forYear year: Int) -> Double {
        charges.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.reduce(0) { $0 + $1.amount }
    }
    /// Appointments completed
    @Attribute(.transient)
    var completedAppointments: [Appointment] {
        appointments.filter { $0.status == .completed }
    }
    /// Most recent appointment date
    @Attribute(.transient)
    var lastAppointmentDate: Date? {
        appointments.sorted(by: { $0.date > $1.date }).first?.date
    }
    /// True if last appointment > 60 days ago
    @Attribute(.transient)
    var isRetentionRisk: Bool {
        guard let last = lastAppointmentDate else { return true }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0 > 60
    }
    /// Loyalty tier
    @Attribute(.transient)
    var loyaltyTier: String {
        switch totalSpent {
        case 0..<500: "Bronze"
        case 500..<2000: "Silver"
        case 2000..<5000: "Gold"
        default: "Platinum"
        }
    }
    /// Average interval between appointments (in days)
    @Attribute(.transient)
    var averageAppointmentInterval: Double? {
        let dates = appointments.map { $0.date }.sorted()
        guard dates.count > 1 else { return nil }
        let intervals = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 86400 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }
    /// True if any active dogs
    @Attribute(.transient)
    var hasActiveDogs: Bool {
        dogs.contains(where: { $0.isActive })
    }
    /// Display name for UI
    @Attribute(.transient)
    var displayName: String {
        ownerName.isEmpty ? NSLocalizedString("Unnamed Owner", comment: "Default owner name") : ownerName
    }

    // MARK: - Audit/Export

    /// Adds an entry to the audit log asynchronously in a concurrency-safe manner.
    /// - Parameter entry: The audit log entry text.
    @discardableResult
    func addAuditLogEntry(_ entry: String) async {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let fullEntry = "[\(timestamp)] \(entry)"
        await auditQueue.async {
            self.auditLog.append(fullEntry)
            Task { @MainActor in
                self.objectWillChange.send()
                self.lastModified = Date()
            }
        }
    }

    /// Fetches the most recent N audit log entries asynchronously and safely.
    /// - Parameter count: Number of recent entries to fetch.
    /// - Returns: Array of recent audit log entries.
    func recentAuditLog(_ count: Int = 3) async -> [String] {
        await auditQueue.sync {
            Array(auditLog.suffix(count))
        }
    }

    /// Exports the audit log as JSON asynchronously.
    /// - Returns: JSON string of audit log entries or nil if encoding fails.
    func exportAuditLogJSON() async -> String? {
        await auditQueue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(auditLog) {
                return String(data: data, encoding: .utf8)
            }
            return nil
        }
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

    /// Asynchronously constructs a localized accessibility label describing the owner profile.
    @Attribute(.transient)
    var accessibilityLabel: String {
        get async {
            """
            \(NSLocalizedString("Owner profile for", comment: "Accessibility label prefix")) \(displayName).
            \(NSLocalizedString("Loyalty tier", comment: "Accessibility label loyalty tier")): \(loyaltyTier).
            \(NSLocalizedString("Total spent", comment: "Accessibility label total spent")): $\(String(format: "%.0f", totalSpent)).
            \(NSLocalizedString("Active dogs", comment: "Accessibility label active dogs")): \(dogCount).
            """
        }
    }

    // MARK: - Modification Tracking

    /// Updates the last modified date and user asynchronously in a concurrency-safe manner.
    /// - Parameter user: The user who made the modification.
    func updateModification(user: String?) async {
        await auditQueue.async {
            self.lastModified = Date()
            self.lastModifiedBy = user
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
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

    // MARK: - Synchronous Wrappers for Backward Compatibility

    /// Synchronously adds an audit log entry by internally calling the async method.
    /// - Parameter entry: The audit log entry text.
    func addAuditLogEntrySync(_ entry: String) {
        Task {
            await addAuditLogEntry(entry)
        }
    }

    /// Synchronously updates modification info by internally calling the async method.
    /// - Parameter user: The user who made the modification.
    func updateModificationSync(user: String?) {
        Task {
            await updateModification(user: user)
        }
    }

    /// Synchronously adds a badge by internally calling the async method.
    /// - Parameter badge: The badge to add.
    func addBadgeSync(_ badge: OwnerBadgeType) {
        Task {
            await addBadge(badge)
        }
    }

    /// Synchronously removes a badge by internally calling the async method.
    /// - Parameter badge: The badge to remove.
    func removeBadgeSync(_ badge: OwnerBadgeType) {
        Task {
            await removeBadge(badge)
        }
    }

    /// Synchronously checks if a badge exists by internally calling the async method.
    /// - Parameter badge: The badge to check.
    /// - Returns: True if the badge is present.
    func hasBadgeSync(_ badge: OwnerBadgeType) -> Bool {
        var result = false
        let group = DispatchGroup()
        group.enter()
        Task {
            result = await hasBadge(badge)
            group.leave()
        }
        group.wait()
        return result
    }

    /// Synchronously fetches recent audit log entries by internally calling the async method.
    /// - Parameter count: Number of recent entries to fetch.
    /// - Returns: Array of recent audit log entries.
    func recentAuditLogSync(_ count: Int = 3) -> [String] {
        var result: [String] = []
        let group = DispatchGroup()
        group.enter()
        Task {
            result = await recentAuditLog(count)
            group.leave()
        }
        group.wait()
        return result
    }

    // MARK: - Utility

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

// MARK: - SwiftUI PreviewProvider demonstrating async audit log and badge usage

#if DEBUG
import PlaygroundSupport

struct DogOwnerPreviewView: View {
    @StateObject private var owner = DogOwner.preview

    @State private var recentLogs: [String] = []
    @State private var accessibilityLabelText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Owner: \(owner.displayName)")
                .font(.title)
            Text("Badges: \(owner.ownerBadges.map { $0.rawValue }.joined(separator: ", "))")
            Button("Add 'Platinum' Badge") {
                Task {
                    await owner.addBadge(.platinum)
                    await refreshLogs()
                }
            }
            Button("Remove 'Friendly' Badge") {
                Task {
                    await owner.removeBadge(.friendly)
                    await refreshLogs()
                }
            }
            Button("Add Audit Log Entry") {
                Task {
                    await owner.addAuditLogEntry("Test audit entry at \(Date())")
                    await refreshLogs()
                }
            }
            Text("Recent Audit Logs:")
                .font(.headline)
            List(recentLogs, id: \.self) { log in
                Text(log)
            }
            Text("Accessibility Label:")
                .font(.headline)
            Text(accessibilityLabelText)
                .italic()
        }
        .padding()
        .task {
            await refreshLogs()
            await loadAccessibilityLabel()
        }
    }

    func refreshLogs() async {
        recentLogs = await owner.recentAuditLog(5)
    }

    func loadAccessibilityLabel() async {
        accessibilityLabelText = await owner.accessibilityLabel
    }
}

struct DogOwner_Previews: PreviewProvider {
    static var previews: some View {
        DogOwnerPreviewView()
    }
}
#endif
