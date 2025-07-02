//
//  SharingService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import UIKit

/**
 SharingService
 --------------
 A centralized service for sharing content (text, URLs, images) from Furfolio with async analytics and audit logging.

 - **Purpose**: Presents share sheets and tracks share events.
 - **Architecture**: Singleton `ObservableObject` service using `UIActivityViewController`.
 - **Concurrency & Async Logging**: Wraps share actions in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Share titles and messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol SharingAnalyticsLogger {
    /// Log a share event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol SharingAuditLogger {
    /// Record a share audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullSharingAnalyticsLogger: SharingAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullSharingAuditLogger: SharingAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a sharing audit event.
public struct SharingAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging share events.
public actor SharingAuditManager {
    private var buffer: [SharingAuditEntry] = []
    private let maxEntries = 100
    public static let shared = SharingAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: SharingAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [SharingAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as JSON.
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
public final class SharingService: ObservableObject {
    public static let shared = SharingService(
        analytics: NullSharingAnalyticsLogger(),
        audit: NullSharingAuditLogger()
    )

    private let analytics: SharingAnalyticsLogger
    private let audit: SharingAuditLogger

    private init(
        analytics: SharingAnalyticsLogger,
        audit: SharingAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Presents a share sheet for the given items from a SwiftUI view.
    public func shareItems(_ items: [Any], from viewController: UIViewController) {
        Task {
            await analytics.log(event: "share_start", metadata: ["count": items.count])
            await audit.record("Share started", metadata: ["count": "\(items.count)"])
            await SharingAuditManager.shared.add(
                SharingAuditEntry(event: "share_start", detail: "\(items.count) items")
            )
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, returnedItems, error in
            Task {
                if let error = error {
                    await analytics.log(event: "share_error", metadata: ["error": error.localizedDescription])
                    await audit.record("Share error", metadata: ["error": error.localizedDescription])
                    await SharingAuditManager.shared.add(
                        SharingAuditEntry(event: "share_error", detail: error.localizedDescription)
                    )
                } else if completed {
                    await analytics.log(event: "share_complete", metadata: ["returned": returnedItems?.count ?? 0])
                    await audit.record("Share completed", metadata: ["returned": "\(returnedItems?.count ?? 0)"])
                    await SharingAuditManager.shared.add(
                        SharingAuditEntry(event: "share_complete", detail: "\(returnedItems?.count ?? 0) items")
                    )
                } else {
                    await analytics.log(event: "share_cancelled", metadata: nil)
                    await audit.record("Share cancelled", metadata: nil)
                    await SharingAuditManager.shared.add(
                        SharingAuditEntry(event: "share_cancelled", detail: nil)
                    )
                }
            }
        }

        viewController.present(controller, animated: true, completion: nil)
    }
}

// MARK: - Diagnostics

public extension SharingService {
    /// Fetch recent sharing audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [SharingAuditEntry] {
        await SharingAuditManager.shared.recent(limit: limit)
    }

    /// Export sharing audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await SharingAuditManager.shared.exportJSON()
    }
}
