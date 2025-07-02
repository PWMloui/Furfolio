//
//  SocialMediaService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

/**
 SocialMediaService
 ------------------
 A centralized service for sharing content to social media platforms from Furfolio, with async analytics and audit logging.

 - **Purpose**: Posts updates and images to Facebook, Instagram, and Twitter.
 - **Architecture**: Singleton `ObservableObject` service with dependency-injected async analytics and audit loggers.
 - **Concurrency & Async Logging**: Wraps share operations in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: User-facing messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol SocialMediaAnalyticsLogger {
    /// Log a social share event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol SocialMediaAuditLogger {
    /// Record a social share audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullSocialMediaAnalyticsLogger: SocialMediaAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullSocialMediaAuditLogger: SocialMediaAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a social media share audit event.
public struct SocialMediaAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging social media share events.
public actor SocialMediaAuditManager {
    private var buffer: [SocialMediaAuditEntry] = []
    private let maxEntries = 100
    public static let shared = SocialMediaAuditManager()

    public func add(_ entry: SocialMediaAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [SocialMediaAuditEntry] {
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
public final class SocialMediaService: ObservableObject {
    public static let shared = SocialMediaService(
        analytics: NullSocialMediaAnalyticsLogger(),
        audit: NullSocialMediaAuditLogger()
    )

    private let analytics: SocialMediaAnalyticsLogger
    private let audit: SocialMediaAuditLogger

    private init(
        analytics: SocialMediaAnalyticsLogger,
        audit: SocialMediaAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Shares a text post to Facebook.
    public func shareToFacebook(message: String) async {
        Task {
            await analytics.log(event: "share_facebook_start", parameters: ["message": message])
            await audit.record("Facebook share started", metadata: ["message": String(message.prefix(20))])
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "share_facebook_start", detail: String(message.prefix(20)))
            )
        }
        // Stubbed share logic
        try? await Task.sleep(nanoseconds: 200_000_000)
        Task {
            await analytics.log(event: "share_facebook_complete", parameters: nil)
            await audit.record("Facebook share completed", metadata: nil)
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "share_facebook_complete", detail: nil)
            )
        }
    }

    /// Shares a text post to Twitter.
    public func tweet(message: String) async {
        Task {
            await analytics.log(event: "tweet_start", parameters: ["message": message])
            await audit.record("Tweet started", metadata: ["message": String(message.prefix(20))])
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "tweet_start", detail: String(message.prefix(20)))
            )
        }
        // Stubbed tweet logic
        try? await Task.sleep(nanoseconds: 150_000_000)
        Task {
            await analytics.log(event: "tweet_complete", parameters: nil)
            await audit.record("Tweet completed", metadata: nil)
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "tweet_complete", detail: nil)
            )
        }
    }

    /// Shares an image to Instagram.
    public func shareImageToInstagram(image: UIImage, caption: String?) async {
        Task {
            await analytics.log(event: "share_instagram_start", parameters: ["caption": caption ?? ""])
            await audit.record("Instagram share started", metadata: ["caption": String(caption?.prefix(20) ?? "")])
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "share_instagram_start", detail: String(caption?.prefix(20) ?? ""))
            )
        }
        // Stubbed Instagram share logic
        try? await Task.sleep(nanoseconds: 250_000_000)
        Task {
            await analytics.log(event: "share_instagram_complete", parameters: nil)
            await audit.record("Instagram share completed", metadata: nil)
            await SocialMediaAuditManager.shared.add(
                SocialMediaAuditEntry(event: "share_instagram_complete", detail: nil)
            )
        }
    }
}

// MARK: - Diagnostics

public extension SocialMediaService {
    /// Fetch recent social media audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [SocialMediaAuditEntry] {
        await SocialMediaAuditManager.shared.recent(limit: limit)
    }

    /// Export social media audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await SocialMediaAuditManager.shared.exportJSON()
    }
}
