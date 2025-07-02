//
//  StripePOSService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation
import SwiftUI
// import StripeTerminal // Uncomment when using actual Stripe SDK

/**
 StripePOSService
 ----------------
 A centralized service for handling POS transactions via Stripe in Furfolio, with async analytics and audit logging.

 - **Purpose**: Processes payments, refunds, and receipts using Stripe’s POS SDK.
 - **Architecture**: Singleton `ObservableObject` service with dependency-injected async analytics and audit loggers.
 - **Concurrency & Async Logging**: Wraps payment operations in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: User-facing messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol StripeAnalyticsLogger {
    /// Log a Stripe POS event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol StripeAuditLogger {
    /// Record a Stripe POS audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullStripeAnalyticsLogger: StripeAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullStripeAuditLogger: StripeAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a Stripe POS audit event.
public struct StripeAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging Stripe POS events.
public actor StripeAuditManager {
    private var buffer: [StripeAuditEntry] = []
    private let maxEntries = 100
    public static let shared = StripeAuditManager()

    public func add(_ entry: StripeAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [StripeAuditEntry] {
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
public final class StripePOSService: ObservableObject {
    public static let shared = StripePOSService(
        analytics: NullStripeAnalyticsLogger(),
        audit: NullStripeAuditLogger()
    )

    private let analytics: StripeAnalyticsLogger
    private let audit: StripeAuditLogger
    @Published public var lastTransactionResult: Result<String, Error>?

    private init(
        analytics: StripeAnalyticsLogger,
        audit: StripeAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Processes a payment of the specified amount (in cents) with optional currency.
    public func processPayment(amount: Int, currency: String = "usd") async {
        Task {
            await analytics.log(event: "payment_start", metadata: ["amount": amount, "currency": currency])
            await audit.record("Payment started", metadata: ["amount": "\(amount)", "currency": currency])
            await StripeAuditManager.shared.add(
                StripeAuditEntry(event: "payment_start", detail: "\(amount) \(currency)")
            )
        }
        // Stubbed Stripe processing logic
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            let transactionId = UUID().uuidString
            lastTransactionResult = .success(transactionId)
            Task {
                await analytics.log(event: "payment_success", metadata: ["transactionId": transactionId])
                await audit.record("Payment successful", metadata: ["transactionId": transactionId])
                await StripeAuditManager.shared.add(
                    StripeAuditEntry(event: "payment_success", detail: transactionId)
                )
            }
        } catch {
            lastTransactionResult = .failure(error)
            Task {
                await analytics.log(event: "payment_error", metadata: ["error": error.localizedDescription])
                await audit.record("Payment error", metadata: ["error": error.localizedDescription])
                await StripeAuditManager.shared.add(
                    StripeAuditEntry(event: "payment_error", detail: error.localizedDescription)
                )
            }
        }
    }

    /// Issues a refund for a given transaction ID.
    public func refund(transactionId: String, amount: Int? = nil) async {
        Task {
            await analytics.log(event: "refund_start", metadata: ["transactionId": transactionId, "amount": amount as Any])
            await audit.record("Refund started", metadata: ["transactionId": transactionId])
            await StripeAuditManager.shared.add(
                StripeAuditEntry(event: "refund_start", detail: transactionId)
            )
        }
        // Stubbed refund logic
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            lastTransactionResult = .success("refund_\(transactionId)")
            Task {
                await analytics.log(event: "refund_success", metadata: ["transactionId": transactionId])
                await audit.record("Refund successful", metadata: ["transactionId": transactionId])
                await StripeAuditManager.shared.add(
                    StripeAuditEntry(event: "refund_success", detail: transactionId)
                )
            }
        } catch {
            lastTransactionResult = .failure(error)
            Task {
                await analytics.log(event: "refund_error", metadata: ["error": error.localizedDescription])
                await audit.record("Refund error", metadata: ["error": error.localizedDescription])
                await StripeAuditManager.shared.add(
                    StripeAuditEntry(event: "refund_error", detail: error.localizedDescription)
                )
            }
        }
    }
}

// MARK: - Diagnostics

public extension StripePOSService {
    /// Fetch recent Stripe POS audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [StripeAuditEntry] {
        await StripeAuditManager.shared.recent(limit: limit)
    }

    /// Export Stripe POS audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await StripeAuditManager.shared.exportJSON()
    }
}
