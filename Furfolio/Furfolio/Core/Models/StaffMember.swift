//
//  StaffMember.swift
//  Furfolio
//
//  Enhanced: Audit, BI, tokenization, security, analytics, export, accessibility.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData

@available(iOS 18.0, *)
@Model
final class StaffMember: Identifiable, ObservableObject {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var name: String
    var role: StaffRole

    // MARK: - Contact Info
    var email: String?
    var phone: String?

    // MARK: - Employment
    var isActive: Bool
    var dateJoined: Date
    var lastActiveAt: Date?
    var isArchived: Bool

    // MARK: - Access & Security
    var lastPasswordChange: Date?
    var mfaEnabled: Bool
    var complianceTrainingDate: Date?

    // MARK: - Badges/Tags (Tokenization)
    var badgeTokens: [String]
    enum StaffBadge: String, CaseIterable, Codable {
        case certified, bilingual, remote, firstAid, mentor, atRisk, longTerm, recentlyJoined
    }
    var badges: [StaffBadge] { badgeTokens.compactMap { StaffBadge(rawValue: $0) } }
    func addBadge(_ badge: StaffBadge) { if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) } }
    func removeBadge(_ badge: StaffBadge) { badgeTokens.removeAll { $0 == badge.rawValue } }
    func hasBadge(_ badge: StaffBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \Business.staff)
    var business: Business?

    // MARK: - Audit Log
    var auditLog: [String]

    func addAudit(_ entry: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(stamp)] \(entry)")
    }
    func recentAudit(_ count: Int = 3) -> [String] { Array(auditLog.suffix(count)) }

    // MARK: - Analytics & Business Intelligence

    /// Returns true if the staff member holds an owner role (RBAC, workflow, UI badge logic).
    var isOwner: Bool { role == .owner }
    /// Returns true if the staff member is a groomer (analytics, business logic).
    var isGroomer: Bool { role == .groomer }
    /// Display-friendly role title.
    var roleDisplayName: String { role.displayName }
    /// Number of years with the company.
    var yearsAtCompany: Int {
        Calendar.current.dateComponents([.year], from: dateJoined, to: Date()).year ?? 0
    }
    /// Returns true if lastActiveAt is in the last 14 days (for reporting).
    var isRecentlyActive: Bool {
        guard let last = lastActiveAt else { return false }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 100 < 14
    }
    /// Streak (days) of continuous activity (simple demo logic).
    var activityStreak: Int? {
        guard let last = lastActiveAt else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
    /// Returns a short status string for dashboard badges.
    var quickStatus: String {
        if !isActive { return "Inactive" }
        if isArchived { return "Archived" }
        if isRecentlyActive { return "Active" }
        return "Idle"
    }
    /// Demo: Basic risk score for BI (compliance, inactivity, etc.)
    var riskScore: Int {
        var score = 0
        if !mfaEnabled { score += 1 }
        if (lastPasswordChange == nil) || ((lastPasswordChange ?? .distantPast) < Calendar.current.date(byAdding: .month, value: -12, to: Date())!) { score += 1 }
        if !isActive || isArchived { score += 1 }
        if let training = complianceTrainingDate, training < Calendar.current.date(byAdding: .year, value: -1, to: Date())! { score += 1 }
        if !isRecentlyActive { score += 1 }
        if hasBadge(.atRisk) { score += 1 }
        return score
    }

    // MARK: - Accessibility
    var accessibilityLabel: String {
        "\(name), \(roleDisplayName). \(isActive ? "Active." : "Inactive.") Risk score: \(riskScore)."
    }

    // MARK: - Export
    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID, name: String, role: String, email: String?, phone: String?, isActive: Bool, dateJoined: Date, lastActiveAt: Date?, isArchived: Bool, mfaEnabled: Bool, riskScore: Int, badgeTokens: [String]
        }
        let export = Export(
            id: id, name: name, role: role.rawValue, email: email, phone: phone, isActive: isActive, dateJoined: dateJoined,
            lastActiveAt: lastActiveAt, isArchived: isArchived, mfaEnabled: mfaEnabled, riskScore: riskScore, badgeTokens: badgeTokens
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String,
        role: StaffRole,
        email: String? = nil,
        phone: String? = nil,
        isActive: Bool = true,
        dateJoined: Date = Date(),
        lastActiveAt: Date? = nil,
        isArchived: Bool = false,
        business: Business? = nil,
        lastPasswordChange: Date? = nil,
        mfaEnabled: Bool = false,
        complianceTrainingDate: Date? = nil,
        badgeTokens: [String] = [],
        auditLog: [String] = []
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.isActive = isActive
        self.dateJoined = dateJoined
        self.lastActiveAt = lastActiveAt
        self.isArchived = isArchived
        self.business = business
        self.lastPasswordChange = lastPasswordChange
        self.mfaEnabled = mfaEnabled
        self.complianceTrainingDate = complianceTrainingDate
        self.badgeTokens = badgeTokens
        self.auditLog = auditLog
    }

    // MARK: - Sample/Preview

    static let sample = StaffMember(
        name: "Jane Doe",
        role: .groomer,
        email: "jane.doe@example.com",
        phone: "555-123-4567",
        isActive: true,
        dateJoined: Date(timeIntervalSinceNow: -86400 * 365 * 4),
        lastActiveAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        isArchived: false,
        lastPasswordChange: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
        mfaEnabled: true,
        complianceTrainingDate: Calendar.current.date(byAdding: .month, value: -10, to: Date()),
        badgeTokens: ["certified", "mentor"],
        auditLog: ["[01/01/2022, 09:00 AM] Created profile."]
    )
}

// MARK: - StaffRole (RBAC, Tokenized, Auditable Staff Roles)
enum StaffRole: String, Codable, Sendable, CaseIterable {
    case owner
    case groomer
    case admin
    case receptionist
    case assistant
    case other

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .groomer: return "Groomer"
        case .admin: return "Admin"
        case .receptionist: return "Receptionist"
        case .assistant: return "Assistant"
        case .other: return "Other"
        }
    }
}
