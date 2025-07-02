
//
//  SupplierAPIService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation

/**
 SupplierAPIService
 ------------------
 A centralized service for managing supplier data via RESTful API in Furfolio, with async analytics and audit logging.

 - **Purpose**: Fetch, create, update, and delete supplier records.
 - **Architecture**: Singleton service using URLSession.
 - **Concurrency & Async Logging**: Wraps network calls in non-blocking `Task` blocks for analytics and audit.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol SupplierAnalyticsLogger {
    /// Log a supplier API event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol SupplierAuditLogger {
    /// Record a supplier API audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullSupplierAnalyticsLogger: SupplierAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullSupplierAuditLogger: SupplierAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a supplier API audit event.
public struct SupplierAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging supplier API events.
public actor SupplierAuditManager {
    private var buffer: [SupplierAuditEntry] = []
    private let maxEntries = 100
    public static let shared = SupplierAuditManager()

    public func add(_ entry: SupplierAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [SupplierAuditEntry] {
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
public final class SupplierAPIService {
    public static let shared = SupplierAPIService(
        analytics: NullSupplierAnalyticsLogger(),
        audit: NullSupplierAuditLogger()
    )

    private let session: URLSession
    private let baseURL: URL
    private let analytics: SupplierAnalyticsLogger
    private let audit: SupplierAuditLogger

    private init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.furfolio.com/suppliers")!,
        analytics: SupplierAnalyticsLogger,
        audit: SupplierAuditLogger
    ) {
        self.session = session
        self.baseURL = baseURL
        self.analytics = analytics
        self.audit = audit
    }

    /// Fetches all suppliers.
    public func fetchSuppliers() async throws -> [Supplier] {
        let endpoint = baseURL
        Task {
            await analytics.log(event: "fetch_suppliers_start", parameters: nil)
            await audit.record("Fetch suppliers started", metadata: nil)
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "fetch_start", detail: nil)
            )
        }
        let (data, response) = try await session.data(from: endpoint)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        Task {
            await analytics.log(event: "fetch_suppliers_response", parameters: ["status": status])
            await audit.record("Fetch suppliers response", metadata: ["status": "\(status)"])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "fetch_response", detail: "\(status)")
            )
        }
        let suppliers = try JSONDecoder().decode([Supplier].self, from: data)
        Task {
            await analytics.log(event: "fetch_suppliers_complete", parameters: ["count": suppliers.count])
            await audit.record("Fetch suppliers completed", metadata: ["count": "\(suppliers.count)"])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "fetch_complete", detail: "\(suppliers.count)")
            )
        }
        return suppliers
    }

    /// Creates a new supplier.
    public func createSupplier(_ supplier: Supplier) async throws -> Supplier {
        let endpoint = baseURL
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(supplier)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Task {
            await analytics.log(event: "create_supplier_start", parameters: ["id": supplier.id.uuidString])
            await audit.record("Create supplier started", metadata: ["id": supplier.id.uuidString])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "create_start", detail: supplier.id.uuidString)
            )
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        Task {
            await analytics.log(event: "create_supplier_response", parameters: ["status": status])
            await audit.record("Create supplier response", metadata: ["status": "\(status)"])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "create_response", detail: "\(status)")
            )
        }
        let created = try JSONDecoder().decode(Supplier.self, from: data)
        Task {
            await analytics.log(event: "create_supplier_complete", parameters: ["id": created.id.uuidString])
            await audit.record("Create supplier completed", metadata: ["id": created.id.uuidString])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "create_complete", detail: created.id.uuidString)
            )
        }
        return created
    }

    /// Updates an existing supplier.
    public func updateSupplier(_ supplier: Supplier) async throws -> Supplier {
        let endpoint = baseURL.appendingPathComponent(supplier.id.uuidString)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.httpBody = try JSONEncoder().encode(supplier)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Task {
            await analytics.log(event: "update_supplier_start", parameters: ["id": supplier.id.uuidString])
            await audit.record("Update supplier started", metadata: ["id": supplier.id.uuidString])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "update_start", detail: supplier.id.uuidString)
            )
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        Task {
            await analytics.log(event: "update_supplier_response", parameters: ["status": status])
            await audit.record("Update supplier response", metadata: ["status": "\(status)"])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "update_response", detail: "\(status)")
            )
        }
        let updated = try JSONDecoder().decode(Supplier.self, from: data)
        Task {
            await analytics.log(event: "update_supplier_complete", parameters: ["id": updated.id.uuidString])
            await audit.record("Update supplier completed", metadata: ["id": updated.id.uuidString])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "update_complete", detail: updated.id.uuidString)
            )
        }
        return updated
    }

    /// Deletes a supplier by ID.
    public func deleteSupplier(id: UUID) async throws {
        let endpoint = baseURL.appendingPathComponent(id.uuidString)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        Task {
            await analytics.log(event: "delete_supplier_start", parameters: ["id": id.uuidString])
            await audit.record("Delete supplier started", metadata: ["id": id.uuidString])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "delete_start", detail: id.uuidString)
            )
        }
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        Task {
            await analytics.log(event: "delete_supplier_response", parameters: ["status": status])
            await audit.record("Delete supplier response", metadata: ["status": "\(status)"])
            await SupplierAuditManager.shared.add(
                SupplierAuditEntry(event: "delete_response", detail: "\(status)")
            )
        }
    }
}

// MARK: - Diagnostics

public extension SupplierAPIService {
    /// Fetch recent supplier API audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [SupplierAuditEntry] {
        await SupplierAuditManager.shared.recent(limit: limit)
    }

    /// Export supplier API audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await SupplierAuditManager.shared.exportJSON()
    }
}

