//
//  User.swift
//  Furfolio
//
//  Enhanced for analytics, BI, security, badge tokenization, accessibility, and export.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

/**
 User
 ----
 A SwiftData @Model representing an application user in Furfolio, with full async audit logging, badge tokenization, and diagnostics.

 - **Architecture**: SwiftData @Model class conforming to Identifiable and ObservableObject for SwiftUI.
 - **Concurrency & Audit**: Records all state changes via `UserAuditManager` actor asynchronously.
 - **Localization & Accessibility**: Exposes `accessibilityLabel` for VoiceOver and supports localized display.
 - **Diagnostics & Export**: Provides methods to fetch and export audit logs for troubleshooting and BI.
 */

/// A single audit record for User state changes.
public struct UserAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let action: String
    public let actor: UUID?

    public init(id: UUID = UUID(), timestamp: Date = Date(), action: String, actor: UUID? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.actor = actor
    }
}

/// Concurrency-safe actor for logging User audit events.
public actor UserAuditManager {
    private var buffer: [UserAuditEntry] = []
    private let maxEntries = 200
    public static let shared = UserAuditManager()

    /// Add a new audit entry, trimming old entries beyond maxEntries.
    public func add(_ entry: UserAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [UserAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

@available(iOS 18.0, *)
@Model
final class User: Identifiable, ObservableObject {
    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var username: String
    var email: String?
    var phone: String?
    var role: UserRole
    var isActive: Bool
    var isArchived: Bool
    var isSuspended: Bool
    var mfaEnabled: Bool
    var passwordLastChanged: Date?
    var verified: Bool
    var complianceAcceptedAt: Date?
    var lastLoginAt: Date?
    var loginStreak: Int
    var dateCreated: Date
    var lastModified: Date
    var profileImageData: Data?
    @Relationship(deleteRule: .nullify, inverse: \Business.staff)
    var business: Business?
    @Relationship(deleteRule: .nullify)
    var staffRecord: StaffMember?
    var tags: [String]
    var badgeTokens: [String]

    // MARK: - Type-safe badge tokens for segmentation/analytics/UI

    enum UserBadge: String, CaseIterable, Codable {
        case mfa, trusted, onboarding, compliance, suspended, archived, powerUser, multiBusiness, risk
    }
    var badges: [UserBadge] { badgeTokens.compactMap { UserBadge(rawValue: $0) } }
    func addBadge(_ badge: UserBadge) {
        if !badgeTokens.contains(badge.rawValue) {
            badgeTokens.append(badge.rawValue)
            Task { await addAudit("Added badge \(badge.rawValue)") }
        }
    }
    func removeBadge(_ badge: UserBadge) {
        badgeTokens.removeAll { $0 == badge.rawValue }
        Task { await addAudit("Removed badge \(badge.rawValue)") }
    }
    func hasBadge(_ badge: UserBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        username: String,
        email: String? = nil,
        phone: String? = nil,
        role: UserRole = .owner,
        isActive: Bool = true,
        isArchived: Bool = false,
        isSuspended: Bool = false,
        mfaEnabled: Bool = false,
        passwordLastChanged: Date? = nil,
        verified: Bool = false,
        complianceAcceptedAt: Date? = nil,
        lastLoginAt: Date? = nil,
        loginStreak: Int = 0,
        dateCreated: Date = Date(),
        lastModified: Date = Date(),
        profileImageData: Data? = nil,
        business: Business? = nil,
        staffRecord: StaffMember? = nil,
        tags: [String] = [],
        badgeTokens: [String] = []
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.phone = phone
        self.role = role
        self.isActive = isActive
        self.isArchived = isArchived
        self.isSuspended = isSuspended
        self.mfaEnabled = mfaEnabled
        self.passwordLastChanged = passwordLastChanged
        self.verified = verified
        self.complianceAcceptedAt = complianceAcceptedAt
        self.lastLoginAt = lastLoginAt
        self.loginStreak = loginStreak
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.profileImageData = profileImageData
        self.business = business
        self.staffRecord = staffRecord
        self.tags = tags
        self.badgeTokens = badgeTokens
    }

    // MARK: - Computed

    var displayName: String { username }
    var profileImage: UIImage? { profileImageData.flatMap { UIImage(data: $0) } }
    var roleLabel: String { role.label }
    var roleIcon: String { role.icon }
    var isEnabled: Bool { isActive && !isSuspended && !isArchived }
    var isVerified: Bool { verified }
    var yearsWithBusiness: Int {
        guard let business else { return 0 }
        return Calendar.current.dateComponents([.year], from: business.dateCreated, to: Date()).year ?? 0
    }
    var daysSinceLastLogin: Int? {
        guard let last = lastLoginAt else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
    var riskScore: Int {
        var score = 0
        if !mfaEnabled { score += 1 }
        if !isVerified { score += 1 }
        if isSuspended || isArchived { score += 2 }
        if let pwdAge = passwordLastChanged, pwdAge < Calendar.current.date(byAdding: .month, value: -12, to: Date())! { score += 1 }
        if hasBadge(.risk) { score += 1 }
        return score
    }
    var accessibilityLabel: String {
        "\(displayName), \(roleLabel). \(isEnabled ? "Active." : "Inactive.") \(isSuspended ? "Suspended." : "") Risk score: \(riskScore)."
    }
    var lastAuditSummary: String {
        "Audit log is asynchronous and accessed separately."
    }
    var isMultiBusiness: Bool { hasBadge(.multiBusiness) || tags.contains("multiBusiness") }
    var isPowerUser: Bool { hasBadge(.powerUser) || loginStreak > 30 }
    var isCompliant: Bool { complianceAcceptedAt != nil }
    var isOnboarding: Bool { hasBadge(.onboarding) }
    var isTrusted: Bool { mfaEnabled && isVerified && !isSuspended && !isArchived }

    // MARK: - State/Helpers

    func enable() {
        Task {
            isActive = true
            isSuspended = false
            await addAudit("User enabled")
        }
    }
    func disable() {
        Task {
            isActive = false
            await addAudit("User disabled")
        }
    }
    func suspend() {
        Task {
            isSuspended = true
            addBadge(.suspended)
            await addAudit("User suspended")
        }
    }
    func unsuspend() {
        Task {
            isSuspended = false
            removeBadge(.suspended)
            await addAudit("User unsuspended")
        }
    }
    func archive() {
        Task {
            isArchived = true
            addBadge(.archived)
            await addAudit("User archived")
        }
    }
    func unarchive() {
        Task {
            isArchived = false
            removeBadge(.archived)
            await addAudit("User unarchived")
        }
    }
    func escalateRole(to newRole: UserRole) {
        Task {
            role = newRole
            await addAudit("Role escalated to \(newRole.label)")
        }
    }
    func acceptCompliance() {
        Task {
            complianceAcceptedAt = Date()
            addBadge(.compliance)
            await addAudit("Accepted compliance agreement")
        }
    }
    func updatePassword() {
        Task {
            passwordLastChanged = Date()
            await addAudit("Password updated")
        }
    }
    func verify() {
        Task {
            verified = true
            await addAudit("User verified")
        }
    }

    // MARK: - Export/Reporting

    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID
            let username: String
            let email: String?
            let phone: String?
            let role: String
            let isActive: Bool
            let isArchived: Bool
            let isSuspended: Bool
            let mfaEnabled: Bool
            let verified: Bool
            let complianceAcceptedAt: Date?
            let lastLoginAt: Date?
            let loginStreak: Int
            let badgeTokens: [String]
            let riskScore: Int
        }
        let export = Export(
            id: id, username: username, email: email, phone: phone, role: role.rawValue,
            isActive: isActive, isArchived: isArchived, isSuspended: isSuspended,
            mfaEnabled: mfaEnabled, verified: verified, complianceAcceptedAt: complianceAcceptedAt,
            lastLoginAt: lastLoginAt, loginStreak: loginStreak, badgeTokens: badgeTokens, riskScore: riskScore
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Sample Data

    static var sample: User {
        User(
            username: "furfolio_owner",
            email: "owner@furfolio.com",
            phone: "555-123-4567",
            role: .owner,
            isActive: true,
            isArchived: false,
            isSuspended: false,
            mfaEnabled: true,
            verified: true,
            complianceAcceptedAt: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            lastLoginAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            loginStreak: 42,
            badgeTokens: [UserBadge.mfa.rawValue, UserBadge.powerUser.rawValue]
        )
    }

    static var suspended: User {
        User(
            username: "furfolio_suspended",
            email: "suspended@furfolio.com",
            role: .staff,
            isActive: false,
            isArchived: false,
            isSuspended: true,
            mfaEnabled: false,
            verified: false,
            badgeTokens: [UserBadge.suspended.rawValue, UserBadge.risk.rawValue]
        )
    }

    static var archived: User {
        User(
            username: "archived_admin",
            email: "archived@furfolio.com",
            role: .admin,
            isActive: false,
            isArchived: true,
            isSuspended: false,
            mfaEnabled: false,
            verified: false,
            badgeTokens: [UserBadge.archived.rawValue]
        )
    }
}

// MARK: - Async Audit Methods

public extension User {
    /// Log a user action asynchronously.
    func addAudit(_ action: String, actor: User? = nil) async {
        let entry = UserAuditEntry(action: NSLocalizedString(action, comment: ""), actor: actor?.id)
        await UserAuditManager.shared.add(entry)
        lastModified = Date()
    }

    /// Fetch recent audit entries.
    func recentAuditEntries(limit: Int = 20) async -> [UserAuditEntry] {
        await UserAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as JSON.
    func exportAuditLogJSON() async -> String {
        await UserAuditManager.shared.exportJSON()
    }
}

// MARK: - UserRole Enum (same as before)
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case owner, admin, groomer, receptionist, staff, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .groomer: return "Groomer"
        case .receptionist: return "Receptionist"
        case .staff: return "Staff"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .owner: return "person.crop.circle.fill.badge.star"
        case .admin: return "person.2.crop.square.stack.fill"
        case .groomer: return "scissors"
        case .receptionist: return "phone"
        case .staff: return "person"
        case .custom: return "person.crop.circle"
        }
    }
}

// MARK: - UserAuditLog (same as before)
struct UserAuditLog: Codable {
    let action: String
    let date: Date
    let actorID: UUID?
}
