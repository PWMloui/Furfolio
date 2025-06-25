//
//  Attachment.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Audit/Analytics Protocol

public protocol AttachmentAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullAttachmentAnalyticsLogger: AttachmentAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol AttachmentTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullAttachmentTrustCenterDelegate: AttachmentTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - Attachment Model (Enterprise Enhanced)

@Model
final class Attachment: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var filename: String
    var type: String                // e.g., "image/png", "pdf"
    var url: URL
    var entityType: String          // e.g., "Dog", "Expense"
    var entityID: UUID
    var uploadedAt: Date
    var uploadedBy: String
    var isDeleted: Bool

    // MARK: - Analytics/Trust Center (injectable)
    static var analyticsLogger: AttachmentAnalyticsLogger = NullAttachmentAnalyticsLogger()
    static var trustCenterDelegate: AttachmentTrustCenterDelegate = NullAttachmentTrustCenterDelegate()

    // MARK: - Initializer
    init(filename: String, type: String, url: URL, entityType: String, entityID: UUID, uploadedBy: String) {
        self.id = UUID()
        self.filename = filename
        self.type = type
        self.url = url
        self.entityType = entityType
        self.entityID = entityID
        self.uploadedAt = Date()
        self.uploadedBy = uploadedBy
        self.isDeleted = false
        Self.analyticsLogger.log(event: "created", info: [
            "filename": filename,
            "type": type,
            "entityType": entityType,
            "entityID": entityID.uuidString,
            "uploadedBy": uploadedBy
        ])
    }

    // MARK: - File Delete/Restore
    func markDeleted(user: String, auditTag: String? = nil) {
        guard !isDeleted else { return }
        guard Self.trustCenterDelegate.permission(for: "markDeleted", context: [
            "user": user,
            "filename": filename,
            "entityType": entityType,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "delete_denied", info: [
                "filename": filename,
                "user": user,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = true
        Self.analyticsLogger.log(event: "deleted", info: [
            "filename": filename,
            "user": user,
            "auditTag": auditTag as Any
        ])
    }

    func restore(user: String, auditTag: String? = nil) {
        guard isDeleted else { return }
        guard Self.trustCenterDelegate.permission(for: "restore", context: [
            "user": user,
            "filename": filename,
            "entityType": entityType,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "restore_denied", info: [
                "filename": filename,
                "user": user,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = false
        Self.analyticsLogger.log(event: "restored", info: [
            "filename": filename,
            "user": user,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - Metadata Update
    func updateFilename(_ newFilename: String, user: String, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateFilename", context: [
            "user": user,
            "oldFilename": filename,
            "newFilename": newFilename,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateFilename_denied", info: [
                "filename": filename,
                "user": user,
                "auditTag": auditTag as Any
            ])
            return
        }
        let old = filename
        filename = newFilename
        Self.analyticsLogger.log(event: "filename_updated", info: [
            "oldFilename": old,
            "newFilename": newFilename,
            "user": user,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - Human-Friendly Description for Accessibility
    var accessibleDescription: String {
        "\(filename) (\(type)), uploaded by \(uploadedBy) on \(Self.dateFormatter.string(from: uploadedAt))"
    }

    static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
