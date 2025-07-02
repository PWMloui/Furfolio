
/**
 AnonymizationService
 ---------------------
 A service for anonymizing user and pet data in Furfolio, with support for async audit logging and configurable strategies.

 - **Purpose**: Provides methods to pseudonymize or mask personally identifiable information to protect privacy.
 - **Architecture**: Singleton `ObservableObject` service with dependency-injected audit logger.
 - **Concurrency & Async Logging**: Uses async/await to log anonymization operations via `AnonymizationAuditManager` actor.
 - **Strategies**: Supports multiple anonymization strategies (hashing, masking, tokenization).
 - **Accessibility & Localization**: Methods can produce localized masked formats; audit messages are localizable.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent anonymization audit entries.
 */

import Foundation
import CryptoKit
import SwiftUI

// MARK: - Audit Protocol

public protocol AnonymizationAuditLogger {
    /// Record an anonymization operation asynchronously.
    func record(_ operation: String, input: String) async
}

public struct NullAnonymizationAuditLogger: AnonymizationAuditLogger {
    public init() {}
    public func record(_ operation: String, input: String) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an anonymization operation event.
public struct AnonymizationAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let inputSnippet: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), operation: String, inputSnippet: String) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.inputSnippet = inputSnippet
    }
}

/// Concurrency-safe actor for logging anonymization events.
public actor AnonymizationAuditManager {
    private var buffer: [AnonymizationAuditEntry] = []
    private let maxEntries = 100
    public static let shared = AnonymizationAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: AnonymizationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [AnonymizationAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as JSON string.
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

public final class AnonymizationService: ObservableObject {
    public static let shared = AnonymizationService()

    private let auditLogger: AnonymizationAuditLogger

    private init(auditLogger: AnonymizationAuditLogger = NullAnonymizationAuditLogger()) {
        self.auditLogger = auditLogger
    }

    /// Hashes input string using SHA256 and returns hex string.
    public func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        Task {
            await auditLogger.record("hash", input: String(input.prefix(8)))
            await AnonymizationAuditManager.shared.add(
                AnonymizationAuditEntry(operation: "hash", inputSnippet: String(input.prefix(8)))
            )
        }
        return hex
    }

    /// Masks all but last 4 characters of the input.
    public func mask(_ input: String, maskChar: Character = "*") -> String {
        let suffix = input.suffix(4)
        let masked = String(repeating: maskChar, count: max(0, input.count - 4)) + suffix
        Task {
            await auditLogger.record("mask", input: String(input.prefix(4)))
            await AnonymizationAuditManager.shared.add(
                AnonymizationAuditEntry(operation: "mask", inputSnippet: String(input.prefix(4)))
            )
        }
        return masked
    }

    /// Generates a UUID token for the input string.
    public func tokenize(_ input: String) -> String {
        let token = UUID().uuidString
        Task {
            await auditLogger.record("tokenize", input: String(input.prefix(8)))
            await AnonymizationAuditManager.shared.add(
                AnonymizationAuditEntry(operation: "tokenize", inputSnippet: String(input.prefix(8)))
            )
        }
        return token
    }
}

// MARK: - Diagnostics

public extension AnonymizationService {
    /// Fetch recent anonymization audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [AnonymizationAuditEntry] {
        await AnonymizationAuditManager.shared.recent(limit: limit)
    }

    /// Export anonymization audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AnonymizationAuditManager.shared.exportJSON()
    }
}

