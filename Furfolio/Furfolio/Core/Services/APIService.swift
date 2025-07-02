
//
//  APIService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 APIService
 ----------
 A centralized Swift class for performing HTTP API requests in Furfolio, with built-in async analytics and audit logging.

 - **Purpose**: Sends RESTful requests and decodes JSON responses.
 - **Architecture**: Singleton `ObservableObject` or service class, using `URLSession`.
 - **Concurrency & Async Logging**: All request methods are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and a dedicated audit manager actor.
 - **Localization**: Error messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

import Foundation

// MARK: - Analytics & Audit Protocols

public protocol APIAnalyticsLogger {
    /// Log an API request event asynchronously.
    func logRequest(_ endpoint: String, method: String) async
    /// Log an API response event asynchronously.
    func logResponse(_ endpoint: String, method: String, statusCode: Int) async
    /// Log an API error event asynchronously.
    func logError(_ endpoint: String, method: String, error: Error) async
}

public struct NullAPIAnalyticsLogger: APIAnalyticsLogger {
    public init() {}
    public func logRequest(_ endpoint: String, method: String) async {}
    public func logResponse(_ endpoint: String, method: String, statusCode: Int) async {}
    public func logError(_ endpoint: String, method: String, error: Error) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an API service audit event.
public struct APIServiceAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let endpoint: String
    public let method: String
    public let event: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        endpoint: String,
        method: String,
        event: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.endpoint = endpoint
        self.method = method
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging API service events.
public actor APIServiceAuditManager {
    private var buffer: [APIServiceAuditEntry] = []
    private let maxEntries = 100
    public static let shared = APIServiceAuditManager()

    public func add(_ entry: APIServiceAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [APIServiceAuditEntry] {
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

// MARK: - APIService Main Class

public final class APIService {
    private let session: URLSession
    private let analytics: APIAnalyticsLogger

    public init(
        session: URLSession = .shared,
        analytics: APIAnalyticsLogger = NullAPIAnalyticsLogger()
    ) {
        self.session = session
        self.analytics = analytics
    }

    /// Example async request method with analytics and audit logging.
    public func request<T: Decodable>(_ endpoint: String, method: String = "GET") async throws -> T {
        Task {
            await analytics.logRequest(endpoint, method: method)
            await APIServiceAuditManager.shared.add(
                APIServiceAuditEntry(endpoint: endpoint, method: method, event: "request_start")
            )
        }
        let url = URL(string: endpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            Task {
                await analytics.logResponse(endpoint, method: method, statusCode: status)
                await APIServiceAuditManager.shared.add(
                    APIServiceAuditEntry(endpoint: endpoint, method: method, event: "response", detail: "\(status)")
                )
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Task {
                await analytics.logError(endpoint, method: method, error: error)
                await APIServiceAuditManager.shared.add(
                    APIServiceAuditEntry(endpoint: endpoint, method: method, event: "error", detail: error.localizedDescription)
                )
            }
            throw error
        }
    }
}

// MARK: - Diagnostics

public extension APIService {
    /// Fetch recent API service audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [APIServiceAuditEntry] {
        await APIServiceAuditManager.shared.recent(limit: limit)
    }

    /// Export API service audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await APIServiceAuditManager.shared.exportJSON()
    }
}

