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
    
    // MARK: - Concurrency
    /// Serial queue for concurrency-safe audit log and badge mutation.
    private let auditQueue = DispatchQueue(label: "com.furfolio.session.auditQueue")
    
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
    @Attribute(.transient)
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
    @Attribute(.transient)
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
    @Attribute(.transient)
    var badges: [SessionBadge] { badgeTokens.compactMap { SessionBadge(rawValue: $0) } }
    
    /// Add a badge to the session asynchronously and log the audit entry.
    /// - Parameter badge: The badge to add.
    /// - Returns: Void
    /// - Concurrency: Safe via auditQueue.
    @discardableResult
    func addBadge(_ badge: SessionBadge) async -> Bool {
        await auditQueue.async(flags: .barrier) {
            if !self.badgeTokens.contains(badge.rawValue) {
                self.badgeTokens.append(badge.rawValue)
                let message = String(format: NSLocalizedString("Badge '%@' added.", comment: "Audit: badge added"), badge.rawValue)
                self._addAuditLocked(message)
            }
        }
        return true
    }
    
    /// Remove a badge from the session asynchronously and log the audit entry.
    /// - Parameter badge: The badge to remove.
    /// - Returns: Void
    /// - Concurrency: Safe via auditQueue.
    @discardableResult
    func removeBadge(_ badge: SessionBadge) async -> Bool {
        await auditQueue.async(flags: .barrier) {
            if self.badgeTokens.contains(badge.rawValue) {
                self.badgeTokens.removeAll { $0 == badge.rawValue }
                let message = String(format: NSLocalizedString("Badge '%@' removed.", comment: "Audit: badge removed"), badge.rawValue)
                self._addAuditLocked(message)
            }
        }
        return true
    }
    
    /// Check if a badge exists (not concurrency-protected; for UI only).
    func hasBadge(_ badge: SessionBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    // MARK: - Audit Trail

    var auditLog: [String] = []

    /// Add an audit entry asynchronously.
    /// - Parameter entry: The string to log.
    /// - Returns: Void
    /// - Concurrency: Safe via auditQueue.
    func addAudit(_ entry: String) async {
        await auditQueue.async(flags: .barrier) {
            self._addAuditLocked(entry)
        }
    }

    /// Private, non-concurrent method to append an audit entry with timestamp.
    private func _addAuditLocked(_ entry: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let formattedEntry = "[\(stamp)] \(entry)"
        auditLog.append(formattedEntry)
    }

    /// Fetch the most recent audit entries asynchronously.
    /// - Parameter count: Number of entries to fetch (default: 3)
    /// - Returns: Array of audit log entries.
    /// - Concurrency: Safe via auditQueue.
    func recentAudit(_ count: Int = 3) async -> [String] {
        await auditQueue.sync {
            Array(auditLog.suffix(count))
        }
    }

    /// Export the audit log as JSON asynchronously.
    /// - Returns: JSON string or nil if encoding fails.
    /// - Concurrency: Safe via auditQueue.
    func exportAuditLogJSON() async -> String? {
        await auditQueue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(auditLog)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    // MARK: - Session Control

    @Attribute(.transient)
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

    /// Localized accessibility label describing session state, asynchronously.
    /// - Returns: Localized string.
    @Attribute(.transient)
    var accessibilityLabel: String {
        get async {
            let userFormat = NSLocalizedString("Session for %@.", comment: "Accessibility: session for user")
            let statusFormat = NSLocalizedString("Status: %@.", comment: "Accessibility: session status")
            let roleFormat = NSLocalizedString("Role: %@.", comment: "Accessibility: session role")
            let startedFormat = NSLocalizedString("Started at %@.", comment: "Accessibility: session started at")
            let trusted = NSLocalizedString("Trusted device.", comment: "Accessibility: trusted device")
            let untrusted = NSLocalizedString("Untrusted device.", comment: "Accessibility: untrusted device")
            let riskFormat = NSLocalizedString("Risk score: %d.", comment: "Accessibility: risk score")
            let startedStr = DateFormatter.localizedString(from: startedAt, dateStyle: .medium, timeStyle: .short)
            let roleStr = staffRole?.rawValue ?? NSLocalizedString("unknown", comment: "Accessibility: unknown role")
            let parts = [
                String(format: userFormat, userID),
                String(format: statusFormat, NSLocalizedString(status.rawValue, comment: "Session status")),
                String(format: roleFormat, NSLocalizedString(roleStr, comment: "Session role")),
                String(format: startedFormat, startedStr),
                isTrustedDevice ? trusted : untrusted,
                String(format: riskFormat, riskScore)
            ]
            return parts.joined(separator: " ")
        }
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

    /// Preview session for testing, demonstrates async audit logging.
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
        Task {
            await s.addAudit(NSLocalizedString("Session started.", comment: "Audit: session started"))
        }
        return s
    }()
}

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI PreviewProvider demonstrating async audit log addition, export, and accessibility label fetching.
@available(iOS 18.0, *)
struct Session_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
    }
    
    struct PreviewView: View {
        @StateObject var session = Session.preview
        @State private var auditLog: [String] = []
        @State private var auditJSON: String = ""
        @State private var accessibility: String = ""
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Preview")
                    .font(.headline)
                Text("User: \(session.userID)")
                Text("Role: \(session.staffRole?.rawValue ?? "unknown")")
                Text("Badges: \(session.badges.map { $0.rawValue }.joined(separator: ", "))")
                Button("Add High Risk Badge (async)") {
                    Task {
                        _ = await session.addBadge(.highRisk)
                        auditLog = await session.recentAudit(5)
                    }
                }
                Button("Remove Privileged Badge (async)") {
                    Task {
                        _ = await session.removeBadge(.privileged)
                        auditLog = await session.recentAudit(5)
                    }
                }
                Button("Add Audit Entry (async)") {
                    Task {
                        await session.addAudit(NSLocalizedString("Manual audit entry for preview.", comment: "Audit: preview manual entry"))
                        auditLog = await session.recentAudit(5)
                    }
                }
                Button("Export Audit Log JSON") {
                    Task {
                        auditJSON = await session.exportAuditLogJSON() ?? "nil"
                    }
                }
                Button("Fetch Accessibility Label") {
                    Task {
                        accessibility = await session.accessibilityLabel
                    }
                }
                Divider()
                Text("Recent Audit Log:")
                    .font(.subheadline)
                ForEach(auditLog, id: \.self) { entry in
                    Text(entry)
                        .font(.caption2)
                        .lineLimit(2)
                }
                Divider()
                Text("Audit Log JSON:")
                    .font(.subheadline)
                ScrollView(.horizontal) {
                    Text(auditJSON)
                        .font(.caption2)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Text("Accessibility Label:")
                    .font(.subheadline)
                Text(accessibility)
                    .font(.caption2)
                    .lineLimit(3)
            }
            .padding()
            .onAppear {
                Task {
                    auditLog = await session.recentAudit(5)
                    accessibility = await session.accessibilityLabel
                }
            }
        }
    }
}
#endif
}
