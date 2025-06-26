//
//  FeedbackSubmission.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

// MARK: - Feedback Submission

struct FeedbackSubmission: Identifiable, Codable, Equatable {
    static let schemaVersion = 2  // For future migrations
    
    let id: UUID
    let userID: UUID?
    let contactEmail: String?
    let category: FeedbackCategory
    let message: String
    let submittedAt: Date
    let deviceInfo: DeviceInfo?
    var status: FeedbackStatus
    var supportNotes: String?
    var attachments: [FeedbackAttachment]?
    var auditLog: [FeedbackAuditEntry]?
    
    /// New: Session/Trace for debugging submission lifecycles.
    var sessionID: UUID?
    
    /// New: Arbitrary extensible metadata for analytics, A/B tests, integrations, etc.
    var metadata: [String: String]?
    
    /// Deprecated: Use `auditLog` for all state changes.
    @available(*, deprecated, message: "Use auditLog for all changes.")
    var deprecatedChangeLog: [String]?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        contactEmail: String? = nil,
        category: FeedbackCategory,
        message: String,
        submittedAt: Date = Date(),
        deviceInfo: DeviceInfo? = nil,
        status: FeedbackStatus = .open,
        supportNotes: String? = nil,
        attachments: [FeedbackAttachment]? = nil,
        auditLog: [FeedbackAuditEntry]? = nil,
        sessionID: UUID? = nil,
        metadata: [String: String]? = nil,
        deprecatedChangeLog: [String]? = nil
    ) {
        self.id = id
        self.userID = userID
        self.contactEmail = contactEmail
        self.category = category
        self.message = message
        self.submittedAt = submittedAt
        self.deviceInfo = deviceInfo
        self.status = status
        self.supportNotes = supportNotes
        self.attachments = attachments
        self.auditLog = auditLog
        self.sessionID = sessionID
        self.metadata = metadata
        self.deprecatedChangeLog = deprecatedChangeLog
    }
    
    // MARK: - Analytics Convenience

    var isBugReport: Bool { category == .bugReport }
    var isAnonymous: Bool { userID == nil && (contactEmail?.isEmpty ?? true) }
    
    // For QA/dev logs
    var debugDescription: String {
        """
        FeedbackSubmission(id: \(id), cat: \(category.displayName), status: \(status.displayName))
        user: \(userID?.uuidString ?? "anonymous"), email: \(contactEmail ?? "-")
        submitted: \(submittedAt), message: "\(message.prefix(40))"...
        device: \(deviceInfo?.deviceModel ?? "-"), session: \(sessionID?.uuidString ?? "-")
        """
    }
    
    /// Summarized analytics event payload (for analytics pipeline)
    var analyticsSummary: [String: Any] {
        [
            "id": id.uuidString,
            "userID": userID?.uuidString ?? "anon",
            "category": category.rawValue,
            "submittedAt": submittedAt.timeIntervalSince1970,
            "status": status.rawValue,
            "deviceModel": deviceInfo?.deviceModel ?? "-",
            "hasAttachment": (attachments?.isEmpty == false),
            "sessionID": sessionID?.uuidString ?? "",
            "metadata": metadata ?? [:]
        ]
    }
    
    /// Add a new audit entry and update status in one call
    mutating func appendAudit(
        action: FeedbackAuditEntry.AuditAction,
        actor: String?,
        note: String? = nil,
        newStatus: FeedbackStatus? = nil
    ) {
        let entry = FeedbackAuditEntry(timestamp: Date(), actor: actor, action: action, note: note)
        if auditLog == nil { auditLog = [] }
        auditLog?.append(entry)
        if let status = newStatus { self.status = status }
    }
    
    /// GDPR Redaction helper: returns a redacted copy
    func redactedForGDPR() -> FeedbackSubmission {
        FeedbackSubmission(
            id: id,
            userID: nil,
            contactEmail: nil,
            category: category,
            message: "[REDACTED]",
            submittedAt: submittedAt,
            deviceInfo: nil,
            status: status,
            supportNotes: nil,
            attachments: nil,
            auditLog: auditLog, // Optionally redact as needed
            sessionID: sessionID,
            metadata: nil,
            deprecatedChangeLog: nil
        )
    }
}

// MARK: - Feedback Attachment

struct FeedbackAttachment: Codable, Equatable {
    let filename: String
    let fileType: String   // e.g., "png", "log", "txt"
    let data: Data
}

// MARK: - Audit Entry

struct FeedbackAuditEntry: Codable, Equatable {
    let timestamp: Date
    let actor: String?         // User/admin/system that made the change
    let action: AuditAction
    let note: String?
    
    enum AuditAction: String, Codable {
        case created
        case statusChanged
        case commentAdded
        case attachmentAdded
        case resolved
        case deleted
        case other
    }
}

// MARK: - Device/App Info

struct DeviceInfo: Codable, Equatable {
    let osVersion: String
    let appVersion: String
    let deviceModel: String
    let deviceIdentifier: String?   // For anonymized device tracking (optional)
    let locale: String?             // User locale
    let timezone: String?           // For audit
}

// MARK: - Feedback Status

enum FeedbackStatus: String, Codable, CaseIterable, Equatable {
    case open
    case inProgress
    case resolved
    case closed
    
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }
}
