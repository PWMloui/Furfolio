
//
//  CommunityModerationService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation
import Combine

/**
 CommunityModerationService
 --------------------------
 A centralized service for moderating user-generated content in Furfolio, with full async analytics and audit logging.

 - **Purpose**: Reports abusive content, blocks or flags users, and enforces community guidelines.
 - **Architecture**: Singleton `ObservableObject` service class with Combine publishers for status updates.
 - **Concurrency & Async Logging**: All moderation methods are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol ModerationAnalyticsLogger {
    /// Log a moderation event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol ModerationAuditLogger {
    /// Record a moderation audit entry asynchronously.
    func record(_ action: String, metadata: [String: String]?) async
}

public struct NullModerationAnalyticsLogger: ModerationAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String: Any]?) async {}
}

public struct NullModerationAuditLogger: ModerationAuditLogger {
    public init() {}
    public func record(_ action: String, metadata: [String: String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a moderation action for audit purposes.
public struct ModerationAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let action: String
    public let details: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), action: String, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.details = details
    }
}

/// Concurrency-safe actor for logging moderation events.
public actor ModerationAuditManager {
    private var buffer: [ModerationAuditEntry] = []
    private let maxEntries = 200
    public static let shared = ModerationAuditManager()

    public func add(_ entry: ModerationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [ModerationAuditEntry] {
        Array(buffer.suffix(limit))
    }

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

// MARK: - Service

@MainActor
public final class CommunityModerationService: ObservableObject {
    public static let shared = CommunityModerationService()

    private let analytics: ModerationAnalyticsLogger
    private let audit: ModerationAuditLogger

    @Published public var lastActionResult: Result<String, Error>?

    private init(
        analytics: ModerationAnalyticsLogger = NullModerationAnalyticsLogger(),
        audit: ModerationAuditLogger = NullModerationAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Report a user for abusive behavior.
    public func reportUser(userId: UUID, reason: String) async {
        Task {
            await analytics.log(event: "report_user_start", metadata: ["userId": userId.uuidString])
            await audit.record("Reporting user", metadata: ["userId": userId.uuidString, "reason": reason])
            await ModerationAuditManager.shared.add(
                ModerationAuditEntry(action: "report_user", details: reason)
            )
        }
        // Simulate network operation
        do { try await Task.sleep(nanoseconds: 200_000_000)
            lastActionResult = .success(NSLocalizedString("User reported successfully", comment: ""))
            Task {
                await analytics.log(event: "report_user_success", metadata: ["userId": userId.uuidString])
                await audit.record("User report succeeded", metadata: ["userId": userId.uuidString])
                await ModerationAuditManager.shared.add(
                    ModerationAuditEntry(action: "report_user_success", details: nil)
                )
            }
        } catch {
            lastActionResult = .failure(error)
            Task {
                await analytics.log(event: "report_user_error", metadata: ["error": error.localizedDescription])
                await audit.record("User report failed", metadata: ["error": error.localizedDescription])
                await ModerationAuditManager.shared.add(
                    ModerationAuditEntry(action: "report_user_error", details: error.localizedDescription)
                )
            }
        }
    }

    /// Block a user from accessing the system.
    public func blockUser(userId: UUID) async {
        Task {
            await analytics.log(event: "block_user_start", metadata: ["userId": userId.uuidString])
            await audit.record("Blocking user", metadata: ["userId": userId.uuidString])
            await ModerationAuditManager.shared.add(
                ModerationAuditEntry(action: "block_user", details: nil)
            )
        }
        // Simulate operation
        await Task.sleep(100_000_000)
        lastActionResult = .success(NSLocalizedString("User blocked", comment: ""))
    }

    /// Flag content for moderation review.
    public func flagContent(contentId: UUID, category: String) async {
        Task {
            await analytics.log(event: "flag_content_start", metadata: ["contentId": contentId.uuidString])
            await audit.record("Flagging content", metadata: ["contentId": contentId.uuidString, "category": category])
            await ModerationAuditManager.shared.add(
                ModerationAuditEntry(action: "flag_content", details: category)
            )
        }
        // Simulate operation
        await Task.sleep(150_000_000)
        lastActionResult = .success(NSLocalizedString("Content flagged", comment: ""))
    }
}

// MARK: - Diagnostics

public extension CommunityModerationService {
    /// Fetch recent moderation audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [ModerationAuditEntry] {
        await ModerationAuditManager.shared.recent(limit: limit)
    }

    /// Export moderation audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await ModerationAuditManager.shared.exportJSON()
    }
}

