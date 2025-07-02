import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Forum Audit Event & Logging

/// Represents an audit event in the forum.
public struct ForumAuditEvent: Codable, Identifiable {
    public var id: UUID = UUID()
    public let timestamp: Date
    public let operation: String // e.g., "load", "post", "reply", "like", "delete", "search", "export"
    public let postID: String?
    public let threadTitle: String?
    public let userName: String?
    public let contentSnippet: String?
    public let tags: [String]?
    public let actor: String?
    public let context: String?
    public let detail: String?
}

/// Singleton class to handle audit logging for forum operations.
public class ForumAudit: ObservableObject {
    public static let shared = ForumAudit()
    @Published private(set) var events: [ForumAuditEvent] = []
    private let queue = DispatchQueue(label: "ForumAudit.queue")

    private init() {}

    /// Adds a new audit event to the log.
    public func log(operation: String,
                   postID: String? = nil,
                   threadTitle: String? = nil,
                   userName: String? = nil,
                   contentSnippet: String? = nil,
                   tags: [String]? = nil,
                   actor: String? = nil,
                   context: String? = nil,
                   detail: String? = nil) {
        let snippet = contentSnippet?.prefix(80)
        let event = ForumAuditEvent(
            timestamp: Date(),
            operation: operation,
            postID: postID,
            threadTitle: threadTitle,
            userName: userName,
            contentSnippet: snippet.map { String($0) },
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        queue.sync {
            events.append(event)
            if events.count > 500 {
                events.removeFirst(events.count - 500)
            }
        }
    }

    // MARK: - Analytics

    /// Total number of "post" events.
    public var totalPosts: Int {
        queue.sync { events.filter { $0.operation == "post" }.count }
    }

    /// The userName with the most "post" events.
    public var mostActiveUser: String? {
        queue.sync {
            let posts = events.filter { $0.operation == "post" }
            let counts = Dictionary(grouping: posts, by: { $0.userName ?? "" }).mapValues { $0.count }
            return counts.max { $0.value < $1.value }?.key
        }
    }

    /// The postID with the most "like" events.
    public var mostLikedPostID: String? {
        queue.sync {
            let likes = events.filter { $0.operation == "like" }
            let counts = Dictionary(grouping: likes, by: { $0.postID ?? "" }).mapValues { $0.count }
            return counts.max { $0.value < $1.value }?.key
        }
    }
}

// MARK: - Audit Admin API

/// Provides owner/admin access to audit logs and analytics.
public class ForumAuditAdmin {
    public static let shared = ForumAuditAdmin()
    private let audit = ForumAudit.shared

    /// The last event as a human-readable string.
    public var lastSummary: String? {
        audit.events.last.map { event in
            "[\(Self.dateFormatter.string(from: event.timestamp))] \(event.operation) \(event.userName ?? "") \(event.threadTitle ?? "")"
        }
    }

    /// The last event as JSON.
    public var lastJSON: String? {
        guard let last = audit.events.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(last).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Returns the most recent events, up to the specified limit.
    public func recentEvents(limit: Int = 10) -> [ForumAuditEvent] {
        Array(audit.events.suffix(limit))
    }

    /// Exports the audit log as CSV.
    public func exportCSV() -> String {
        var csv = "timestamp,operation,postID,threadTitle,userName,contentSnippet,tags,actor,context,detail\n"
        for event in audit.events {
            let row = [
                Self.dateFormatter.string(from: event.timestamp),
                event.operation,
                event.postID ?? "",
                event.threadTitle ?? "",
                event.userName ?? "",
                event.contentSnippet?.replacingOccurrences(of: "\"", with: "\"\"") ?? "",
                event.tags?.joined(separator: ";") ?? "",
                event.actor ?? "",
                event.context ?? "",
                event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            ].map { "\"\($0)\"" }.joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    /// Analytics
    public var totalPosts: Int { audit.totalPosts }
    public var mostActiveUser: String? { audit.mostActiveUser }
    public var mostLikedPostID: String? { audit.mostLikedPostID }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
}

// MARK: - Accessibility VoiceOver Announcements

/// Posts a VoiceOver accessibility announcement summarizing a forum action.
func postForumAccessibilityAnnouncement(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}
//
//  ForumView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//


// MARK: - DEV Overlay (DEBUG only)

#if DEBUG
/// SwiftUI overlay showing last 3 audit events and analytics.
struct ForumAuditDevOverlay: View {
    @ObservedObject private var audit = ForumAudit.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Forum Audit (DEV)").font(.caption).foregroundColor(.secondary)
            ForEach(audit.events.suffix(3)) { event in
                HStack {
                    Text("\(event.operation)").bold().font(.caption2)
                    Text(event.userName ?? "").font(.caption2)
                    if let title = event.threadTitle { Text(title).font(.caption2) }
                    Text(Self.shortDate(event.timestamp)).foregroundColor(.gray).font(.caption2)
                }
            }
            Text("Total posts: \(audit.totalPosts)").font(.caption2)
            if let user = audit.mostActiveUser {
                Text("Most active user: \(user)").font(.caption2)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(radius: 2)
        .padding(.bottom, 10)
    }
    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df.string(from: date)
    }
}
#endif

// MARK: - Example Integration Points
/*
// Example: log and announce on post
func handleUserPost(postID: String, threadTitle: String, userName: String, content: String, tags: [String]) {
    ForumAudit.shared.log(
        operation: "post",
        postID: postID,
        threadTitle: threadTitle,
        userName: userName,
        contentSnippet: content,
        tags: tags,
        actor: userName,
        context: "ForumView",
        detail: nil
    )
    postForumAccessibilityAnnouncement("Post by \(userName) added")
}

// Example: log and announce on reply
func handleUserReply(postID: String, threadTitle: String, userName: String, content: String) {
    ForumAudit.shared.log(
        operation: "reply",
        postID: postID,
        threadTitle: threadTitle,
        userName: userName,
        contentSnippet: content,
        actor: userName,
        context: "ForumView",
        detail: nil
    )
    postForumAccessibilityAnnouncement("Reply by \(userName) added")
}

// Example: log and announce on like
func handleUserLike(postID: String, threadTitle: String, userName: String) {
    ForumAudit.shared.log(
        operation: "like",
        postID: postID,
        threadTitle: threadTitle,
        userName: userName,
        actor: userName,
        context: "ForumView",
        detail: nil
    )
    postForumAccessibilityAnnouncement("Post by \(userName) liked")
}

// Example: log and announce on delete
func handleUserDelete(postID: String, threadTitle: String, userName: String) {
    ForumAudit.shared.log(
        operation: "delete",
        postID: postID,
        threadTitle: threadTitle,
        userName: userName,
        actor: userName,
        context: "ForumView",
        detail: nil
    )
    postForumAccessibilityAnnouncement("Post by \(userName) deleted")
}
*/
