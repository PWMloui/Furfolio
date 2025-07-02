//
//  Attachment.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Audit/Analytics Protocol

public protocol AttachmentAnalyticsLogger {
    /// Logs an event asynchronously with optional additional info.
    /// - Parameters:
    ///   - event: The event name to log.
    ///   - info: Optional dictionary with additional event info.
    func log(event: String, info: [String: Any]?) async
}
public struct NullAttachmentAnalyticsLogger: AttachmentAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol AttachmentTrustCenterDelegate {
    /// Asynchronously requests permission for a given action in a specified context.
    /// - Parameters:
    ///   - action: The action to check permission for.
    ///   - context: Optional context dictionary.
    /// - Returns: A Boolean indicating whether permission is granted.
    func permission(for action: String, context: [String: Any]?) async -> Bool
}
public struct NullAttachmentTrustCenterDelegate: AttachmentTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
}

// MARK: - Attachment Model (Enterprise Enhanced)

@Model
final class Attachment: Identifiable {
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

    // MARK: - Concurrency

    /// Serial queue used to ensure thread-safe mutation operations.
    private let mutationQueue = DispatchQueue(label: "Attachment.mutation.queue")

    // MARK: - Initializer

    /// Creates a new Attachment instance asynchronously, logging the creation event.
    /// - Parameters:
    ///   - filename: The filename of the attachment.
    ///   - type: The MIME type of the attachment.
    ///   - url: The URL where the attachment is stored.
    ///   - entityType: The type of entity associated with the attachment.
    ///   - entityID: The UUID of the associated entity.
    ///   - uploadedBy: The user who uploaded the attachment.
    public init(filename: String, type: String, url: URL, entityType: String, entityID: UUID, uploadedBy: String) async {
        self.id = UUID()
        self.filename = filename
        self.type = type
        self.url = url
        self.entityType = entityType
        self.entityID = entityID
        self.uploadedAt = Date()
        self.uploadedBy = uploadedBy
        self.isDeleted = false
        await Self.analyticsLogger.log(event: NSLocalizedString("attachment.created", comment: "Attachment created event"), info: [
            "filename": filename,
            "type": type,
            "entityType": entityType,
            "entityID": entityID.uuidString,
            "uploadedBy": uploadedBy
        ])
    }

    // MARK: - File Delete/Restore

    /// Marks the attachment as deleted asynchronously, after permission check.
    /// - Parameters:
    ///   - user: The user requesting deletion.
    ///   - auditTag: Optional audit tag.
    /// - Throws: None. Fails silently if permission denied.
    public func markDeleted(user: String, auditTag: String? = nil) async {
        await mutationQueue.async {
            Task {
                guard !self.isDeleted else { return }
                let permitted = await Self.trustCenterDelegate.permission(for: "markDeleted", context: [
                    "user": user,
                    "filename": self.filename,
                    "entityType": self.entityType,
                    "auditTag": auditTag as Any
                ])
                if !permitted {
                    await Self.analyticsLogger.log(event: NSLocalizedString("attachment.delete_denied", comment: "Delete denied event"), info: [
                        "filename": self.filename,
                        "user": user,
                        "auditTag": auditTag as Any
                    ])
                    return
                }
                self.isDeleted = true
                await Self.analyticsLogger.log(event: NSLocalizedString("attachment.deleted", comment: "Deleted event"), info: [
                    "filename": self.filename,
                    "user": user,
                    "auditTag": auditTag as Any
                ])
            }
        }
    }

    /// Restores the attachment asynchronously, after permission check.
    /// - Parameters:
    ///   - user: The user requesting restore.
    ///   - auditTag: Optional audit tag.
    /// - Throws: None. Fails silently if permission denied.
    public func restore(user: String, auditTag: String? = nil) async {
        await mutationQueue.async {
            Task {
                guard self.isDeleted else { return }
                let permitted = await Self.trustCenterDelegate.permission(for: "restore", context: [
                    "user": user,
                    "filename": self.filename,
                    "entityType": self.entityType,
                    "auditTag": auditTag as Any
                ])
                if !permitted {
                    await Self.analyticsLogger.log(event: NSLocalizedString("attachment.restore_denied", comment: "Restore denied event"), info: [
                        "filename": self.filename,
                        "user": user,
                        "auditTag": auditTag as Any
                    ])
                    return
                }
                self.isDeleted = false
                await Self.analyticsLogger.log(event: NSLocalizedString("attachment.restored", comment: "Restored event"), info: [
                    "filename": self.filename,
                    "user": user,
                    "auditTag": auditTag as Any
                ])
            }
        }
    }

    // MARK: - Metadata Update

    /// Updates the filename asynchronously, after permission check.
    /// - Parameters:
    ///   - newFilename: The new filename to set.
    ///   - user: The user requesting the update.
    ///   - auditTag: Optional audit tag.
    /// - Throws: None. Fails silently if permission denied.
    public func updateFilename(_ newFilename: String, user: String, auditTag: String? = nil) async {
        await mutationQueue.async {
            Task {
                let permitted = await Self.trustCenterDelegate.permission(for: "updateFilename", context: [
                    "user": user,
                    "oldFilename": self.filename,
                    "newFilename": newFilename,
                    "auditTag": auditTag as Any
                ])
                if !permitted {
                    await Self.analyticsLogger.log(event: NSLocalizedString("attachment.updateFilename_denied", comment: "Update filename denied event"), info: [
                        "filename": self.filename,
                        "user": user,
                        "auditTag": auditTag as Any
                    ])
                    return
                }
                let old = self.filename
                self.filename = newFilename
                await Self.analyticsLogger.log(event: NSLocalizedString("attachment.filename_updated", comment: "Filename updated event"), info: [
                    "oldFilename": old,
                    "newFilename": newFilename,
                    "user": user,
                    "auditTag": auditTag as Any
                ])
            }
        }
    }

    // MARK: - Human-Friendly Description for Accessibility

    /// Returns an accessibility-friendly description asynchronously.
    /// - Returns: A localized string describing the attachment.
    @Attribute(.transient)
    public var accessibleDescription: String {
        get async {
            let format = NSLocalizedString("attachment.accessibleDescription", comment: "Accessible description format")
            return String(format: format, filename, type, uploadedBy, Self.dateFormatter.string(from: uploadedAt))
        }
    }

    static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: - Deprecated synchronous wrappers

    @available(*, deprecated, message: "Use async init(filename:type:url:entityType:entityID:uploadedBy:) instead.")
    convenience init(filename: String, type: String, url: URL, entityType: String, entityID: UUID, uploadedBy: String) {
        self.init()
        self.id = UUID()
        self.filename = filename
        self.type = type
        self.url = url
        self.entityType = entityType
        self.entityID = entityID
        self.uploadedAt = Date()
        self.uploadedBy = uploadedBy
        self.isDeleted = false
        Task {
            await Self.analyticsLogger.log(event: "created", info: [
                "filename": filename,
                "type": type,
                "entityType": entityType,
                "entityID": entityID.uuidString,
                "uploadedBy": uploadedBy
            ])
        }
    }

    @available(*, deprecated, message: "Use async markDeleted(user:auditTag:) instead.")
    func markDeletedSync(user: String, auditTag: String? = nil) {
        Task {
            await markDeleted(user: user, auditTag: auditTag)
        }
    }

    @available(*, deprecated, message: "Use async restore(user:auditTag:) instead.")
    func restoreSync(user: String, auditTag: String? = nil) {
        Task {
            await restore(user: user, auditTag: auditTag)
        }
    }

    @available(*, deprecated, message: "Use async updateFilename(_:user:auditTag:) instead.")
    func updateFilenameSync(_ newFilename: String, user: String, auditTag: String? = nil) {
        Task {
            await updateFilename(newFilename, user: user, auditTag: auditTag)
        }
    }

    @available(*, deprecated, message: "Use async accessibleDescription property instead.")
    var accessibleDescriptionSync: String {
        get async {
            await accessibleDescription
        } as! String // force cast for backward compatibility; use async version instead
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async usage

#if DEBUG
struct Attachment_Previews: PreviewProvider {
    static var previews: some View {
        AttachmentPreviewView()
    }

    struct AttachmentPreviewView: View {
        @State private var attachment: Attachment?
        @State private var description: String = ""

        var body: some View {
            VStack(spacing: 20) {
                if let attachment = attachment {
                    Text(description)
                        .padding()
                    Button(NSLocalizedString("attachment.markDeleted.button", comment: "Mark Deleted button")) {
                        Task {
                            await attachment.markDeleted(user: "previewUser", auditTag: "previewAudit")
                            description = await attachment.accessibleDescription
                        }
                    }
                    Button(NSLocalizedString("attachment.restore.button", comment: "Restore button")) {
                        Task {
                            await attachment.restore(user: "previewUser", auditTag: "previewAudit")
                            description = await attachment.accessibleDescription
                        }
                    }
                    Button(NSLocalizedString("attachment.updateFilename.button", comment: "Update Filename button")) {
                        Task {
                            await attachment.updateFilename("new_filename.txt", user: "previewUser", auditTag: "previewAudit")
                            description = await attachment.accessibleDescription
                        }
                    }
                } else {
                    Text(NSLocalizedString("attachment.loading", comment: "Loading attachment..."))
                }
            }
            .task {
                let newAttachment = await Attachment(filename: "example.txt", type: "text/plain", url: URL(string: "https://example.com/example.txt")!, entityType: "Document", entityID: UUID(), uploadedBy: "previewUser")
                attachment = newAttachment
                description = await newAttachment.accessibleDescription
            }
            .padding()
        }
    }
}
#endif
