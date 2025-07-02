//
//  Notification.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import Foundation
import SwiftUI

/**
 Notification
 ------------
 A model representing an in-app notification within the Furfolio app, with auditing, localization, accessibility, and preview support.

 - **Architecture**: Conforms to Identifiable and Codable for SwiftUI binding and networking.
 - **Concurrency & Audit**: Provides async/await audit logging via `NotificationAuditManager` actor.
 - **Fields**: Title, message, date, read state, and creation/update timestamps.
 - **Localization**: All user-facing strings use `NSLocalizedString`.
 - **Accessibility**: Exposes formatted properties for VoiceOver.
 - **Preview/Testability**: Includes SwiftUI preview demonstrating creation, marking read/unread, and audit logging.
 */

/// Represents a single app notification.
public struct Notification: Identifiable, Codable {
    /// Unique identifier for the notification
    public let id: UUID
    /// Notification title
    public var title: String
    /// Detailed message content
    public var message: String
    /// Date the notification was issued
    public var date: Date
    /// Read/unread state
    public var isRead: Bool
    /// Creation timestamp
    public let createdAt: Date
    /// Last updated timestamp
    public var updatedAt: Date

    /// Formatted date string for display
    public var formattedDate: String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    /// Accessibility label combining title and message
    public var accessibilityLabel: Text {
        Text(String(
            format: NSLocalizedString("%@, %@, on %@", comment: "Notification accessibility label: title, message, date"),
            NSLocalizedString(title, comment: "Notification title"),
            NSLocalizedString(message, comment: "Notification message"),
            formattedDate
        ))
    }

    /// Initializes a new Notification
    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        date: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.title = NSLocalizedString(title, comment: "Notification title")
        self.message = NSLocalizedString(message, comment: "Notification message")
        self.date = date
        self.isRead = isRead
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Audit Entry & Manager

/// A record of a Notification audit event.
public struct NotificationAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let entry: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

/// Manages concurrency-safe audit logging for Notification events.
public actor NotificationAuditManager {
    private var buffer: [NotificationAuditEntry] = []
    private let maxEntries = 100
    public static let shared = NotificationAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: NotificationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [NotificationAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(buffer),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }
}

// MARK: - Async Audit & State Methods

public extension Notification {
    /// Asynchronously log an audit entry for this notification.
    func addAudit(_ entry: String) async {
        let localized = NSLocalizedString(entry, comment: "Notification audit entry")
        let auditEntry = NotificationAuditEntry(timestamp: Date(), entry: localized)
        await NotificationAuditManager.shared.add(auditEntry)
        updatedAt = Date()
    }

    /// Mark this notification as read asynchronously, logging the action.
    mutating func markAsRead() async {
        guard !isRead else { return }
        isRead = true
        updatedAt = Date()
        await addAudit("Marked as read")
    }

    /// Mark this notification as unread asynchronously, logging the action.
    mutating func markAsUnread() async {
        guard isRead else { return }
        isRead = false
        updatedAt = Date()
        await addAudit("Marked as unread")
    }

    /// Fetches recent audit entries for this notification.
    func recentAuditEntries(limit: Int = 20) async -> [NotificationAuditEntry] {
        await NotificationAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as JSON asynchronously.
    func exportAuditLogJSON() async -> String {
        await NotificationAuditManager.shared.exportJSON()
    }
}

// MARK: - Preview

#if DEBUG
struct Notification_Previews: PreviewProvider {
    static var previews: some View {
        var note = Notification(title: "Upcoming Appointment", message: "Your dog Coco has an appointment tomorrow at 10 AM.")
        return VStack(spacing: 16) {
            Text(note.title).font(.headline)
            Text(note.message).font(.body)
            Text(note.formattedDate).font(.caption)
            Button(note.isRead ? "Mark Unread" : "Mark Read") {
                Task {
                    await note.markAsRead()
                    let logs = await note.recentAuditEntries(limit: 5)
                    print(logs)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(note.accessibilityLabel)
    }
}
#endif
