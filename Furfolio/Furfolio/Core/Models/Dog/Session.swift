//
//  Session.swift
//  Furfolio
//
//  Enhanced for auditing, security analytics, compliance, and extensibility.
//

import Foundation
import SwiftData

@available(iOS 18.0, *)
@Model
final class Session: Identifiable, ObservableObject {
    
    // MARK: - Identity & User

    @Attribute(.unique)
    var id: UUID
    var userID: String

    // MARK: - Role-based Access

    enum StaffRole: String, Codable, Sendable, CaseIterable {
        case owner, assistant, admin, unknown
    }
    var staffRole: StaffRole?

    // MARK: - Session Metadata & Security

    var deviceInfo: String?
    var ipAddress: String?
    var location: String?
    var sessionToken: String?
    var notes: String?

    // Strongly-typed session context
    enum SessionType: String, Codable, CaseIterable {
        case device, user, automation, api, unknown
    }
    var sessionType: SessionType = .user

    // Session status for analytics
    enum Status: String, Codable, CaseIterable {
        case active, expired, ended, locked, revoked
    }
    var status: Status {
        if let endedAt { return .ended }
        if isExpired(maxDuration: Self.defaultSessionTimeout) { return .expired }
        return .active
    }

    // Trusted device flag (biometrics/known device)
    var isTrustedDevice: Bool = false

    // 2FA Method (for audit/security review)
    enum TwoFactorMethod: String, Codable, CaseIterable {
        case none, sms, email, authenticator, hardwareKey
    }
    var twoFactorMethod: TwoFactorMethod = .none

    // Session security risk score (simple demo—expand with ML as needed)
    var riskScore: Int {
        var score = 0
        if !isTrustedDevice { score += 1 }
        if twoFactorMethod == .none { score += 1 }
        if staffRole == .unknown { score += 2 }
        if badges.contains(.highRisk) { score += 2 }
        return score
    }

    // MARK: - Session State

    var startedAt: Date
    var endedAt: Date?
    var lastActivityAt: Date?

    // MARK: - Tokenized/Segmented Badges

    enum SessionBadge: String, CaseIterable, Codable {
        case remote, privileged, mobile, automation, highRisk, complianceReview, expired
    }
    var badgeTokens: [String] = []
    var badges: [SessionBadge] { badgeTokens.compactMap { SessionBadge(rawValue: $0) } }
    func addBadge(_ badge: SessionBadge) { if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) } }
    func removeBadge(_ badge: SessionBadge) { badgeTokens.removeAll { $0 == badge.rawValue } }
    func hasBadge(_ badge: SessionBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    // MARK: - Audit Trail

    var auditLog: [String] = []
    func addAudit(_ entry: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(stamp)] \(entry)")
    }
    func recentAudit(_ count: Int = 3) -> [String] { Array(auditLog.suffix(count)) }

    // MARK: - Session Control

    var isActive: Bool { endedAt == nil && !isExpired(maxDuration: Self.defaultSessionTimeout) }
    static let defaultSessionTimeout: TimeInterval = 3600 * 8

    func endSession(note: String? = nil) {
        objectWillChange.send()
        self.endedAt = Date()
        self.lastActivityAt = self.endedAt
        addAudit("Session ended" + (note != nil ? ": \(note!)" : ""))
    }

    func isExpired(maxDuration: TimeInterval) -> Bool {
        guard let ended = endedAt else {
            return Date().timeIntervalSince(startedAt) > maxDuration
        }
        return ended.timeIntervalSince(startedAt) > maxDuration
    }

    // MARK: - Export

    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID
            let userID: String
            let staffRole: String?
            let sessionType: String
            let status: String
            let startedAt: Date
            let endedAt: Date?
            let lastActivityAt: Date?
            let ipAddress: String?
            let location: String?
            let isTrustedDevice: Bool
            let twoFactorMethod: String
            let badgeTokens: [String]
            let riskScore: Int
            let notes: String?
        }
        let export = Export(
            id: id, userID: userID, staffRole: staffRole?.rawValue,
            sessionType: sessionType.rawValue, status: status.rawValue,
            startedAt: startedAt, endedAt: endedAt, lastActivityAt: lastActivityAt,
            ipAddress: ipAddress, location: location, isTrustedDevice: isTrustedDevice,
            twoFactorMethod: twoFactorMethod.rawValue, badgeTokens: badgeTokens, riskScore: riskScore,
            notes: notes
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Accessibility

    var accessibilityLabel: String {
        "Session for \(userID). Status: \(status.rawValue). Role: \(staffRole?.rawValue ?? "unknown"). Started at \(DateFormatter.localizedString(from: startedAt, dateStyle: .medium, timeStyle: .short)). \(isTrustedDevice ? "Trusted device." : "Untrusted device."). Risk score: \(riskScore)."
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        userID: String,
        staffRole: StaffRole? = nil,
        deviceInfo: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        sessionToken: String? = nil,
        ipAddress: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        sessionType: SessionType = .user,
        lastActivityAt: Date? = nil,
        isTrustedDevice: Bool = false,
        twoFactorMethod: TwoFactorMethod = .none,
        badgeTokens: [String] = [],
        auditLog: [String] = []
    ) {
        self.id = id
        self.userID = userID
        self.staffRole = staffRole
        self.deviceInfo = deviceInfo
        self.startedAt = startedAt ?? Date()
        self.endedAt = endedAt
        self.sessionToken = sessionToken
        self.ipAddress = ipAddress
        self.location = location
        self.notes = notes
        self.sessionType = sessionType
        self.lastActivityAt = lastActivityAt
        self.isTrustedDevice = isTrustedDevice
        self.twoFactorMethod = twoFactorMethod
        self.badgeTokens = badgeTokens
        self.auditLog = auditLog
    }

    // MARK: - Preview/Test

    static let preview: Session = {
        let s = Session(
            userID: "demoUser",
            staffRole: .admin,
            deviceInfo: "iPad Pro",
            startedAt: Date().addingTimeInterval(-3000),
            ipAddress: "192.168.1.5",
            sessionType: .user,
            isTrustedDevice: true,
            twoFactorMethod: .authenticator,
            badgeTokens: [SessionBadge.privileged.rawValue]
        )
        s.addAudit("Session started.")
        return s
    }()
}
