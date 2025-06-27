//
//  AuditLogger.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

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
    func record(_ message: String, metadata: [String: String]?, level: AuditLevel)
    func recordSensitive(_ action: String, userId: String)
}

/// Centralized audit logging system
final class AuditLogger: AuditLoggerProtocol {
    static let shared = AuditLogger()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "audit")

    private init() {}

    func record(_ message: String, metadata: [String: String]? = nil, level: AuditLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = AuditEntry(timestamp: timestamp, level: level, message: message, metadata: metadata)

        logToConsole(entry)
        logToSystem(entry)
        storeLocallyIfDebug(entry)
    }

    func recordSensitive(_ action: String, userId: String) {
        let message = "Sensitive Action: \(action) by user \(userId)"
        record(message, metadata: ["userId": userId], level: .sensitive)
    }

    private func logToConsole(_ entry: AuditEntry) {
        #if DEBUG
        print("[Audit] \(entry.timestamp): [\(entry.level.rawValue.uppercased())] \(entry.message) \(entry.metadata ?? [:])")
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

    private func storeLocallyIfDebug(_ entry: AuditEntry) {
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
