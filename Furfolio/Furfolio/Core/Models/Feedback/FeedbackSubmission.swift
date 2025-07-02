//
//  FeedbackSubmission.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 FeedbackSubmission Module

 Architecture & Purpose:
 This module encapsulates the data structures and logic for handling user feedback submissions within the Furfolio app. It is designed with modularity and extensibility in mind, separating core feedback data, attachments, audit logging, and device metadata.

 Audit & Analytics Readiness:
 Feedback submissions are tracked with comprehensive audit entries managed asynchronously by a dedicated actor, `FeedbackSubmissionAuditManager`. This design supports concurrent safe audit logging, efficient retrieval, and export of audit trails. Analytics-ready summary payloads are included for integration with analytics pipelines.

 Diagnostics & Debugging:
 The `debugDescription` property provides a concise, localized overview of the feedback submission useful for QA and developers. The inclusion of session IDs and device info aids in tracing and reproducing issues.

 Localization & Accessibility:
 All user-facing strings, including status display names and debug messages, are localized using `NSLocalizedString` to support internationalization and accessibility.

 Compliance:
 GDPR compliance is supported through a redaction helper method that strips personally identifiable information from feedback data while preserving audit trails.

 Preview & Testability:
 SwiftUI previews and async test examples demonstrate how to create, audit, and export feedback submissions, facilitating UI development and integration testing.

 */

 // MARK: - Feedback Submission

@Model public struct FeedbackSubmission: Identifiable {
    static let schemaVersion = 2  // For future migrations
    
    @Attribute(.unique) var id: UUID
    let userID: UUID?
    let contactEmail: String?
    let category: FeedbackCategory
    let message: String
    let submittedAt: Date
    let deviceInfo: DeviceInfo?
    var status: FeedbackStatus
    var supportNotes: String?
    var attachments: [FeedbackAttachment]?
    
    /// New: Session/Trace for debugging submission lifecycles.
    var sessionID: UUID?
    
    /// New: Arbitrary extensible metadata for analytics, A/B tests, integrations, etc.
    var metadata: [String: String]?
    
    /// Deprecated: Use `FeedbackSubmissionAuditManager` for audit entries.
    @available(*, deprecated, message: "Use FeedbackSubmissionAuditManager for audit entries.")
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
        self.sessionID = sessionID
        self.metadata = metadata
        self.deprecatedChangeLog = deprecatedChangeLog
    }
    
    // MARK: - Analytics Convenience

    @Attribute(.transient)
    var isBugReport: Bool { category == .bugReport }
    @Attribute(.transient)
    var isAnonymous: Bool { userID == nil && (contactEmail?.isEmpty ?? true) }
    
    // For QA/dev logs
    @Attribute(.transient)
    var debugDescription: String {
        """
        \(NSLocalizedString("FeedbackSubmission(id:", comment: "Debug description prefix")) \(id), \(NSLocalizedString("cat:", comment: "Category label")) \(category.displayName), \(NSLocalizedString("status:", comment: "Status label")) \(status.displayName))
        \(NSLocalizedString("user:", comment: "User label")) \(userID?.uuidString ?? NSLocalizedString("anonymous", comment: "Anonymous user")), \(NSLocalizedString("email:", comment: "Email label")) \(contactEmail ?? "-")
        \(NSLocalizedString("submitted:", comment: "Submitted label")) \(submittedAt), \(NSLocalizedString("message:", comment: "Message label")) \"\(message.prefix(40))\"...
        \(NSLocalizedString("device:", comment: "Device label")) \(deviceInfo?.deviceModel ?? "-"), \(NSLocalizedString("session:", comment: "Session label")) \(sessionID?.uuidString ?? "-")
        """
    }
    
    /// Summarized analytics event payload (for analytics pipeline)
    @Attribute(.transient)
    var analyticsSummary: [String: Any] {
        [
            NSLocalizedString("id", comment: "Analytics key for id"): id.uuidString,
            NSLocalizedString("userID", comment: "Analytics key for userID"): userID?.uuidString ?? NSLocalizedString("anon", comment: "Anonymous user"),
            NSLocalizedString("category", comment: "Analytics key for category"): category.rawValue,
            NSLocalizedString("submittedAt", comment: "Analytics key for submittedAt"): submittedAt.timeIntervalSince1970,
            NSLocalizedString("status", comment: "Analytics key for status"): status.rawValue,
            NSLocalizedString("deviceModel", comment: "Analytics key for deviceModel"): deviceInfo?.deviceModel ?? "-",
            NSLocalizedString("hasAttachment", comment: "Analytics key for hasAttachment"): (attachments?.isEmpty == false),
            NSLocalizedString("sessionID", comment: "Analytics key for sessionID"): sessionID?.uuidString ?? "",
            NSLocalizedString("metadata", comment: "Analytics key for metadata"): metadata ?? [:]
        ]
    }
    
    /**
     Append a new audit entry asynchronously and optionally update the feedback status.

     This method creates a `FeedbackAuditEntry` with the provided action, actor, and optional note. It then asynchronously delegates the storage of this entry to the `FeedbackSubmissionAuditManager` actor, ensuring thread-safe audit logging.

     - Parameters:
       - action: The audit action performed.
       - actor: The user/admin/system responsible for the action.
       - note: Optional additional information about the action.
       - newStatus: Optional new status for the feedback submission; if provided, updates the status property.
     */
    mutating func appendAudit(
        action: FeedbackAuditEntry.AuditAction,
        actor: String?,
        note: String? = nil,
        newStatus: FeedbackStatus? = nil
    ) async {
        let entry = FeedbackAuditEntry(timestamp: Date(), actor: actor, action: action, note: note)
        await FeedbackSubmissionAuditManager.shared.add(entry)
        if let status = newStatus { self.status = status }
    }
    
    /// GDPR Redaction helper: returns a redacted copy
    func redactedForGDPR() -> FeedbackSubmission {
        FeedbackSubmission(
            id: id,
            userID: nil,
            contactEmail: nil,
            category: category,
            message: NSLocalizedString("[REDACTED]", comment: "Redacted message placeholder"),
            submittedAt: submittedAt,
            deviceInfo: nil,
            status: status,
            supportNotes: nil,
            attachments: nil,
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
        case .open: return NSLocalizedString("Open", comment: "Feedback status Open")
        case .inProgress: return NSLocalizedString("In Progress", comment: "Feedback status In Progress")
        case .resolved: return NSLocalizedString("Resolved", comment: "Feedback status Resolved")
        case .closed: return NSLocalizedString("Closed", comment: "Feedback status Closed")
        }
    }
}

// MARK: - FeedbackSubmissionAuditManager Actor

private actor FeedbackSubmissionAuditManager {
    static let shared = FeedbackSubmissionAuditManager()
    
    private var auditEntries: [FeedbackAuditEntry] = []
    private let maxEntries = 100
    
    /// Add a new audit entry asynchronously, maintaining a capped buffer.
    func add(_ entry: FeedbackAuditEntry) {
        auditEntries.append(entry)
        if auditEntries.count > maxEntries {
            auditEntries.removeFirst(auditEntries.count - maxEntries)
        }
    }
    
    /// Retrieve recent audit entries up to the specified limit.
    func recent(limit: Int) -> [FeedbackAuditEntry] {
        let count = auditEntries.count
        guard count > 0 else { return [] }
        let start = max(0, count - limit)
        return Array(auditEntries[start..<count])
    }
    
    /// Export all audit entries as a JSON string.
    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(auditEntries)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}

// MARK: - SwiftUI PreviewProvider

struct FeedbackSubmission_Previews: PreviewProvider {
    static var previews: some View {
        Text(NSLocalizedString("Feedback Submission Preview", comment: "Preview title"))
            .padding()
            .task {
                await previewAuditFlow()
            }
    }
    
    static func previewAuditFlow() async {
        var submission = FeedbackSubmission(
            userID: UUID(),
            contactEmail: "user@example.com",
            category: .bugReport,
            message: NSLocalizedString("App crashes on launch", comment: "Example feedback message"),
            deviceInfo: DeviceInfo(
                osVersion: "iOS 17.0",
                appVersion: "1.0.0",
                deviceModel: "iPhone 14 Pro",
                deviceIdentifier: nil,
                locale: Locale.current.identifier,
                timezone: TimeZone.current.identifier
            ),
            status: .open,
            sessionID: UUID(),
            metadata: ["testKey": "testValue"]
        )
        
        await submission.appendAudit(
            action: .created,
            actor: NSLocalizedString("System", comment: "Audit actor"),
            note: NSLocalizedString("Feedback created during preview", comment: "Audit note"),
            newStatus: .open
        )
        
        await submission.appendAudit(
            action: .commentAdded,
            actor: NSLocalizedString("QA Tester", comment: "Audit actor"),
            note: NSLocalizedString("Initial review completed", comment: "Audit note"),
            newStatus: .inProgress
        )
        
        let recentEntries = await FeedbackSubmissionAuditManager.shared.recent(limit: 5)
        print(NSLocalizedString("Recent Audit Entries:", comment: "Audit entries header"))
        for entry in recentEntries {
            print(" - \(entry.timestamp): \(entry.action.rawValue) by \(entry.actor ?? NSLocalizedString("unknown", comment: "Unknown actor")) - \(entry.note ?? "")")
        }
        
        let exportedJSON = await FeedbackSubmissionAuditManager.shared.exportJSON()
        print(NSLocalizedString("Exported Audit JSON:", comment: "Audit JSON header"))
        print(exportedJSON)
    }
}
