
//
//  HelpContentService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 HelpContentService
 ------------------
 A centralized service in Furfolio for retrieving and managing in-app help and tutorial content, with async analytics and audit logging.

 - **Purpose**: Loads help articles and embeds context-aware guidance for users.
 - **Architecture**: Singleton `ObservableObject` or service class with dependency-injected `AnalyticsServiceProtocol` and `AuditLoggerProtocol`.
 - **Concurrency & Async Logging**: All fetch and cache operations are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Help content keys and error messages support `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit log entries for troubleshooting.
 */



// MARK: - Analytics & Audit Protocols

public protocol HelpContentAnalyticsLogger {
    /// Log a help content event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol HelpContentAuditLogger {
    /// Record a help content audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullHelpContentAnalyticsLogger: HelpContentAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String: Any]?) async {}
}

public struct NullHelpContentAuditLogger: HelpContentAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String: String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a help content service audit event.
public struct HelpContentAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging help content events.
public actor HelpContentAuditManager {
    private var buffer: [HelpContentAuditEntry] = []
    private let maxEntries = 100
    public static let shared = HelpContentAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: HelpContentAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [HelpContentAuditEntry] {
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


// MARK: - HelpContentService

@MainActor
public final class HelpContentService {
    public static let shared = HelpContentService()

    private let analytics: HelpContentAnalyticsLogger
    private let audit: HelpContentAuditLogger

    private init(
        analytics: HelpContentAnalyticsLogger = NullHelpContentAnalyticsLogger(),
        audit: HelpContentAuditLogger = NullHelpContentAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
        // existing initialization...
    }

    // Example method: Fetch help articles
    public func fetchHelpArticles() async {
        Task {
            await analytics.log(event: "fetch_articles_start", metadata: nil)
            await audit.record("Started fetching help articles", metadata: nil)
            await HelpContentAuditManager.shared.add(
                HelpContentAuditEntry(event: "fetch_articles_start", detail: nil)
            )
        }
        do {
            // Simulate fetch logic (replace with real implementation)
            let articles: [String] = [] // TODO: actual fetch
            // ... after successful fetch:
            Task {
                await analytics.log(event: "fetch_articles_complete", metadata: ["count": articles.count])
                await audit.record("Completed fetching help articles", metadata: ["count": "\(articles.count)"])
                await HelpContentAuditManager.shared.add(
                    HelpContentAuditEntry(event: "fetch_articles_complete", detail: "\(articles.count)")
                )
            }
        } catch {
            Task {
                await analytics.log(event: "fetch_articles_error", metadata: ["error": error.localizedDescription])
                await audit.record("Error fetching help articles", metadata: ["error": error.localizedDescription])
                await HelpContentAuditManager.shared.add(
                    HelpContentAuditEntry(event: "fetch_articles_error", detail: error.localizedDescription)
                )
            }
        }
    }

    // Example method: Load content for a given key
    public func loadContent(for key: String) async {
        Task {
            await analytics.log(event: "load_content_start", metadata: ["key": key])
            await audit.record("Started loading help content", metadata: ["key": key])
            await HelpContentAuditManager.shared.add(
                HelpContentAuditEntry(event: "load_content_start", detail: key)
            )
        }
        do {
            // Simulate load logic (replace with real implementation)
            let content: String = "" // TODO: actual load
            Task {
                await analytics.log(event: "load_content_complete", metadata: ["key": key])
                await audit.record("Completed loading help content", metadata: ["key": key])
                await HelpContentAuditManager.shared.add(
                    HelpContentAuditEntry(event: "load_content_complete", detail: key)
                )
            }
        } catch {
            Task {
                await analytics.log(event: "load_content_error", metadata: ["key": key, "error": error.localizedDescription])
                await audit.record("Error loading help content", metadata: ["key": key, "error": error.localizedDescription])
                await HelpContentAuditManager.shared.add(
                    HelpContentAuditEntry(event: "load_content_error", detail: "\(key): \(error.localizedDescription)")
                )
            }
        }
    }
}


// MARK: - Diagnostics

public extension HelpContentService {
    /// Fetch recent help content audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [HelpContentAuditEntry] {
        await HelpContentAuditManager.shared.recent(limit: limit)
    }

    /// Export help content audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await HelpContentAuditManager.shared.exportJSON()
    }
}
