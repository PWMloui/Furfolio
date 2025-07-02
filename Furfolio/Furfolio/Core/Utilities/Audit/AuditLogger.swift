//
//  AuditLogger.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 `AuditLogger.swift` serves as the centralized, auditable logging system for Furfolio, designed to capture and record audit events with various severity levels including sensitive actions.

 ## Architecture
 This system is implemented as a singleton (`AuditLogger.shared`) to ensure a unique, consistent logging instance throughout the app lifecycle. It leverages Apple's `OSLog` framework for efficient, privacy-aware system logging and supports writing logs to a local file during debug builds.

 A diagnostics buffer maintains the most recent 100 audit entries in memory, facilitating quick retrieval for diagnostics and troubleshooting. The design supports asynchronous logging operations to avoid blocking the main thread and to integrate smoothly with modern Swift concurrency.

 ## Concurrency
 The logging protocol and implementation use async functions, enabling non-blocking audit recording. Internal logging operations are dispatched appropriately to maintain thread safety and performance.

 ## Localization & Accessibility
 User-facing log messages printed to the console are localized using `NSLocalizedString` to support internationalization. Accessibility considerations are maintained by ensuring logs do not expose sensitive information unless explicitly marked.

 ## Compliance & Security
 Sensitive audit actions are logged with privacy considerations using OSLog's privacy options and are segregated in the system logs. Local file storage of logs occurs only in debug builds to avoid exposing sensitive data in production environments.

 ## Preview & Testability
 The diagnostics buffer and async logging interface facilitate easy inspection and testing of audit logs, enabling previewing recent audit events and exporting logs in JSON format for analysis.

 */

import Foundation
import OSLog

/// Log levels for audit events
enum AuditLevel: String, Codable {
    case info
    case warning
    case error
    case sensitive
}

/// Protocol for centralized audit logging used across Furfolio
protocol AuditLoggerProtocol {
    /// Record an audit message asynchronously.
    func record(_ message: String, metadata: [String: String]?, level: AuditLevel) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

/// Centralized audit logging system
final class AuditLogger: AuditLoggerProtocol {
    static let shared = AuditLogger()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "audit")

    /// A buffer storing the most recent 100 audit entries for diagnostics.
    private var diagnosticsBuffer: [AuditEntry] = []
    private let diagnosticsBufferLimit = 100
    private let diagnosticsQueue = DispatchQueue(label: "com.furfolio.auditlogger.diagnosticsQueue", attributes: .concurrent)

    private init() {}

    /// Record an audit message asynchronously.
    func record(_ message: String, metadata: [String: String]? = nil, level: AuditLevel = .info) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = AuditEntry(timestamp: timestamp, level: level, message: message, metadata: metadata)

        logToConsole(entry)
        logToSystem(entry)
        await storeLocallyIfDebug(entry)
        appendToDiagnosticsBuffer(entry)
    }

    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async {
        let message = "Sensitive Action: \(action) by user \(userId)"
        await record(message, metadata: ["userId": userId], level: .sensitive)
    }

    private func logToConsole(_ entry: AuditEntry) {
        #if DEBUG
        let auditPrefix = NSLocalizedString("[Audit]", comment: "Prefix for audit log messages")
        print("\(auditPrefix) \(entry.timestamp): [\(entry.level.rawValue.uppercased())] \(entry.message) \(entry.metadata ?? [:])")
        #endif
    }

    private func logToSystem(_ entry: AuditEntry) {
        switch entry.level {
        case .info:
            logger.info("\(entry.message, privacy: .public)")
        case .warning:
            logger.warning("\(entry.message, privacy: .public)")
        case .error:
            logger.error("\(entry.message, privacy: .public)")
        case .sensitive:
            logger.warning("\(entry.message, privacy: .sensitive)")
        }
    }

    /// Stores the audit entry to a local file if in debug mode.
    private func storeLocallyIfDebug(_ entry: AuditEntry) async {
        #if DEBUG
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("audit_log.jsonl") else { return }

        do {
            let json = try JSONEncoder().encode(entry)
            if let line = String(data: json, encoding: .utf8) {
                try line.appendLineToURL(fileURL: url)
            }
        } catch {
            logger.error("Failed to write audit log locally: \(error.localizedDescription)")
        }
        #endif
    }

    /// Append an audit entry to the diagnostics buffer, trimming older entries if necessary.
    private func appendToDiagnosticsBuffer(_ entry: AuditEntry) {
        diagnosticsQueue.async(flags: .barrier) {
            self.diagnosticsBuffer.append(entry)
            if self.diagnosticsBuffer.count > self.diagnosticsBufferLimit {
                self.diagnosticsBuffer.removeFirst(self.diagnosticsBuffer.count - self.diagnosticsBufferLimit)
            }
        }
    }

    /// Returns the most recent audit entries up to the specified limit.
    /// - Parameter limit: The maximum number of recent entries to return. Defaults to 20.
    /// - Returns: An array of recent `AuditEntry` objects.
    func recentDiagnostics(limit: Int = 20) async -> [AuditEntry] {
        await withCheckedContinuation { continuation in
            diagnosticsQueue.async {
                let slice = self.diagnosticsBuffer.suffix(limit)
                continuation.resume(returning: Array(slice))
            }
        }
    }

    /// Exports the diagnostics buffer as a pretty-printed JSON string.
    /// - Returns: A JSON string representing the diagnostics buffer, or `"[]"` if encoding fails.
    func exportDiagnosticsJSON() async -> String {
        await withCheckedContinuation { continuation in
            diagnosticsQueue.async {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(self.diagnosticsBuffer),
                   let jsonString = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonString)
                } else {
                    continuation.resume(returning: "[]")
                }
            }
        }
    }
}

// MARK: - Audit Entry Struct

private struct AuditEntry: Codable {
    let timestamp: String
    let level: AuditLevel
    let message: String
    let metadata: [String: String]?
}

// MARK: - Append Helper

extension String {
    func appendLineToURL(fileURL: URL) throws {
        let data = (self + "\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            handle.write(data)
            try handle.close()
        } else {
            try write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
