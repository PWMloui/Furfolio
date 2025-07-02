//
//  ProductSafetyAPIService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/**
 ProductSafetyAPIService
 -----------------------
 A centralized service for fetching and evaluating product safety data in Furfolio, with async analytics and audit logging.

 - **Purpose**: Retrieves safety guidelines and alerts for products.
 - **Architecture**: Singleton service using URLSession.
 - **Concurrency & Async Logging**: Wraps request methods in non-blocking `Task` blocks for analytics and audit.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol ProductSafetyAnalyticsLogger {
    /// Log a safety API event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol ProductSafetyAuditLogger {
    /// Record a safety API audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullProductSafetyAnalyticsLogger: ProductSafetyAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullProductSafetyAuditLogger: ProductSafetyAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a product safety API audit event.
public struct ProductSafetyAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging product safety events.
public actor ProductSafetyAuditManager {
    private var buffer: [ProductSafetyAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ProductSafetyAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: ProductSafetyAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ProductSafetyAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as pretty-printed JSON.
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
public final class ProductSafetyAPIService {
    public static let shared = ProductSafetyAPIService(
        analytics: NullProductSafetyAnalyticsLogger(),
        audit: NullProductSafetyAuditLogger()
    )

    private let session: URLSession
    private let analytics: ProductSafetyAnalyticsLogger
    private let audit: ProductSafetyAuditLogger

    private init(
        session: URLSession = .shared,
        analytics: ProductSafetyAnalyticsLogger,
        audit: ProductSafetyAuditLogger
    ) {
        self.session = session
        self.analytics = analytics
        self.audit = audit
    }

    /// Fetch safety data for a given product identifier.
    public func fetchSafetyData(for productId: String) async throws -> SafetyData {
        Task {
            await analytics.log(event: "fetch_start", parameters: ["productId": productId])
            await audit.record("Fetch safety data started", metadata: ["productId": productId])
            await ProductSafetyAuditManager.shared.add(
                ProductSafetyAuditEntry(event: "fetch_start", detail: productId)
            )
        }

        let url = URL(string: "https://api.furfolio.com/safety/\(productId)")!
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        Task {
            await analytics.log(event: "fetch_response", parameters: ["status": status])
            await audit.record("Fetch safety data response", metadata: ["status": "\(status)"])
            await ProductSafetyAuditManager.shared.add(
                ProductSafetyAuditEntry(event: "fetch_response", detail: "\(status)")
            )
        }

        let decoder = JSONDecoder()
        let safety = try decoder.decode(SafetyData.self, from: data)

        Task {
            await analytics.log(event: "fetch_complete", parameters: ["productId": productId])
            await audit.record("Fetch safety data completed", metadata: ["productId": productId])
            await ProductSafetyAuditManager.shared.add(
                ProductSafetyAuditEntry(event: "fetch_complete", detail: productId)
            )
        }

        return safety
    }
}

// MARK: - Diagnostics

public extension ProductSafetyAPIService {
    /// Fetch recent API audit entries for diagnostics.
    static func recentAuditEntries(limit: Int = 20) async -> [ProductSafetyAuditEntry] {
        await ProductSafetyAuditManager.shared.recent(limit: limit)
    }

    /// Export API audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await ProductSafetyAuditManager.shared.exportJSON()
    }
}
