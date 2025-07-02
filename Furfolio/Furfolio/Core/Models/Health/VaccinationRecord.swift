//  VaccinationRecord.swift
//  Furfolio Business Management
//
//  Created by mac on 6/19/25.
//  Updated for best practices and enhanced business management features.
//

import Foundation
import SwiftData

/**
 VaccinationRecord represents a modular, tokenized, and auditable vaccination record within Furfolio's business management ecosystem.

 Architecture:
 - Designed as a SwiftData @Model for seamless persistence.
 - Supports relationships to Dog and User models.
 - Tokenized badges for flexible UI and analytics integration.
 - Audit entries managed asynchronously for concurrency safety.

 Concurrency:
 - Audit logging uses an actor-based manager to ensure thread safety.
 - Async methods provided for audit operations.

 Audit/Analytics Hooks:
 - Badge tokens support compliance, risk scoring, and status tracking.
 - Audit entries capture detailed record history with localized timestamps.
 - Export functions for JSON serialization of records and audit logs.

 Diagnostics & Localization:
 - Accessibility labels and localized strings facilitate UI/UX.
 - Timestamp formatting respects locale settings.
 - Notes and tags support multi-language content.

 Accessibility:
 - Accessibility labels designed for VoiceOver.
 - Badge and status tokens support assistive technologies.

 Compliance:
 - Core vaccine detection and risk scoring support regulatory needs.
 - Verification status and adverse reaction tracking integrated.

 Preview/Testability:
 - Demo static instance provided for UI previews and testing.
 - Export functions enable data interchange and validation.
 */
 
@Model public struct VaccinationAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

@Model
public final class VaccinationRecord: Identifiable, ObservableObject {
    @Attribute(.unique)
    public var id: UUID
    public var vaccineType: VaccineType
    public var dateAdministered: Date
    public var expirationDate: Date
    public var lotNumber: String?
    public var manufacturer: String?
    public var clinic: String?
    public var veterinarian: String?
    public var isVerified: Bool?
    @Attribute(.externalStorage)
    public var notes: String?
    public var reminderDate: Date?
    public var tags: [String]
    @Relationship(deleteRule: .nullify, inverse: \Dog.vaccinationRecords)
    public var dog: Dog?
    @Relationship(deleteRule: .nullify)
    public var createdBy: User?

    // --- ENHANCEMENTS ---

    /// Status/badge tokens for UI and analytics
    public var badgeTokens: [String] = []

    public enum VaccinationBadge: String, CaseIterable, Codable {
        case overdue, expiringSoon, annual, core, compliance, adverseReaction, imported, verified
    }

    public var badges: [VaccinationBadge] {
        badgeTokens.compactMap { VaccinationBadge(rawValue: $0) }
    }
    public func addBadge(_ badge: VaccinationBadge) {
        if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) }
    }
    public func removeBadge(_ badge: VaccinationBadge) {
        badgeTokens.removeAll { $0 == badge.rawValue }
    }
    public func hasBadge(_ badge: VaccinationBadge) -> Bool {
        badgeTokens.contains(badge.rawValue)
    }

    /// Audit log for compliance and record history managed asynchronously
    public func addAudit(_ entry: String) async {
        let localizedEntry = NSLocalizedString(entry, comment: "Audit log entry")
        let auditEntry = VaccinationAuditEntry(timestamp: Date(), entry: localizedEntry)
        await VaccinationRecordAuditManager.shared.add(auditEntry)
    }
    public func recentAuditEntries(limit: Int = 3) async -> [VaccinationAuditEntry] {
        await VaccinationRecordAuditManager.shared.recent(limit: limit)
    }
    public func exportAuditLogJSON() async -> String {
        await VaccinationRecordAuditManager.shared.exportJSON()
    }

    // --- COMPUTED PROPERTIES ---

    /// Expired if today is past expiration.
    @Attribute(.transient)
    public var isExpired: Bool {
        Date() > expirationDate
    }

    /// Due soon if within 30 days.
    @Attribute(.transient)
    public var isDueSoon: Bool {
        let thirtyDays = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expirationDate <= thirtyDays && !isExpired
    }

    /// Days until expiration (negative if overdue).
    @Attribute(.transient)
    public var daysUntilExpiration: Int? {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }

    /// Days since administered (for adverse event tracking, etc.).
    @Attribute(.transient)
    public var daysSinceAdministered: Int? {
        Calendar.current.dateComponents([.day], from: dateAdministered, to: Date()).day
    }

    /// Is this a core vaccine (for compliance dashboards)?
    @Attribute(.transient)
    public var isCoreVaccine: Bool {
        switch vaccineType {
        case .rabies, .parvo, .distemper, .hepatitis: true
        default: false
        }
    }

    /// Was an adverse reaction recorded?
    @Attribute(.transient)
    public var isAdverseReaction: Bool {
        notes?.localizedCaseInsensitiveContains("reaction") == true || hasBadge(.adverseReaction)
    }

    /// Was this record imported? (badge or tag)
    @Attribute(.transient)
    public var isImported: Bool {
        hasBadge(.imported) || tags.contains(where: { $0.lowercased().contains("import") })
    }

    /// Computed compliance/risk score (demo logic: overdue=3, not verified=1, core=1, adverse=2, expiringSoon=1)
    @Attribute(.transient)
    public var riskScore: Int {
        var score = 0
        if isExpired { score += 3 }
        if isDueSoon { score += 1 }
        if isCoreVaccine { score += 1 }
        if isAdverseReaction { score += 2 }
        if isVerified != true { score += 1 }
        if hasBadge(.imported) { score += 1 }
        return score
    }

    /// Accessibility label for VoiceOver or UI display.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        "\(vaccineType.label) vaccine. \(isExpired ? NSLocalizedString("Expired.", comment: "Accessibility expired") : (isDueSoon ? NSLocalizedString("Due soon.", comment: "Accessibility due soon") : NSLocalizedString("Up to date.", comment: "Accessibility up to date"))) \(isVerified == true ? NSLocalizedString("Verified.", comment: "Accessibility verified") : "") \(isCoreVaccine ? NSLocalizedString("Core vaccine.", comment: "Accessibility core vaccine") : "")"
    }

    // --- FILTERS (for UI/analytics) ---

    public static func filterOverdue(_ records: [VaccinationRecord]) -> [VaccinationRecord] {
        records.filter { $0.isExpired || $0.hasBadge(.overdue) }
    }
    public static func filterExpiringSoon(_ records: [VaccinationRecord]) -> [VaccinationRecord] {
        records.filter { $0.isDueSoon || $0.hasBadge(.expiringSoon) }
    }
    public static func filterAdverseReactions(_ records: [VaccinationRecord]) -> [VaccinationRecord] {
        records.filter { $0.isAdverseReaction }
    }

    // --- EXPORT ---

    public func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID
            let vaccineType: String
            let dateAdministered: Date
            let expirationDate: Date
            let lotNumber: String?
            let manufacturer: String?
            let clinic: String?
            let veterinarian: String?
            let isVerified: Bool?
            let tags: [String]
            let badgeTokens: [String]
            let dogID: UUID?
            let createdBy: UUID?
        }
        let export = Export(
            id: id, vaccineType: vaccineType.rawValue, dateAdministered: dateAdministered, expirationDate: expirationDate,
            lotNumber: lotNumber, manufacturer: manufacturer, clinic: clinic, veterinarian: veterinarian,
            isVerified: isVerified, tags: tags, badgeTokens: badgeTokens, dogID: dog?.id, createdBy: createdBy?.id
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // --- INIT ---

    public init(
        id: UUID = UUID(),
        vaccineType: VaccineType,
        dateAdministered: Date,
        expirationDate: Date,
        lotNumber: String? = nil,
        manufacturer: String? = nil,
        clinic: String? = nil,
        veterinarian: String? = nil,
        isVerified: Bool? = nil,
        notes: String? = nil,
        reminderDate: Date? = nil,
        tags: [String] = [],
        dog: Dog? = nil,
        createdBy: User? = nil,
        badgeTokens: [String] = [],
        auditLog: [String] = []
    ) {
        self.id = id
        self.vaccineType = vaccineType
        self.dateAdministered = dateAdministered
        self.expirationDate = expirationDate
        self.lotNumber = lotNumber
        self.manufacturer = manufacturer
        self.clinic = clinic
        self.veterinarian = veterinarian
        self.isVerified = isVerified
        self.notes = notes
        self.reminderDate = reminderDate
        self.tags = tags
        self.dog = dog
        self.createdBy = createdBy
        self.badgeTokens = badgeTokens
    }

    // --- PREVIEW/DEMO ---

    public static let demo = VaccinationRecord(
        vaccineType: .rabies,
        dateAdministered: Date(timeIntervalSinceNow: -31536000),
        expirationDate: Date(timeIntervalSinceNow: -5 * 24 * 3600), // Expired 5 days ago
        lotNumber: "DEF999",
        manufacturer: "PetHealth Labs",
        clinic: "Good Dog Vets",
        veterinarian: "Dr. Lee",
        isVerified: false,
        notes: "Mild reaction: swelling at injection site.",
        reminderDate: nil,
        tags: ["Annual", "Imported"],
        badgeTokens: [VaccinationBadge.overdue.rawValue, VaccinationBadge.core.rawValue, VaccinationBadge.adverseReaction.rawValue]
    )
}

public actor VaccinationRecordAuditManager {
    private var buffer: [VaccinationAuditEntry] = []
    private let maxEntries = 100
    public static let shared = VaccinationRecordAuditManager()

    public func add(_ entry: VaccinationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int) -> [VaccinationAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(buffer),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "[]"
    }
}
