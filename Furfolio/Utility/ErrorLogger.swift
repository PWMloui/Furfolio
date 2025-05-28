//
//  ErrorLogger.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import os

enum LogLevel: String {
  case error = "ERROR"
  case warning = "WARNING"
  case info = "INFO"
  case debug = "DEBUG"
}

protocol LoggingBackend {
  func log(level: LogLevel, message: String, metadata: [String: Any]?)
}

struct DefaultLoggingBackend: LoggingBackend {
  static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
  static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "Furfolio", category: "ErrorLogger")
  
  private static func osLogType(for level: LogLevel) -> OSLogType {
    switch level {
    case .debug:
      return .debug
    case .info:
      return .info
    case .warning:
      return .default
    case .error:
      return .error
    }
  }
  
  private init() {}
  
  func log(level: LogLevel, message: String, metadata: [String: Any]?) {
    let timestamp = Self.isoFormatter.string(from: Date())
    var logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)"
    if let meta = metadata, !meta.isEmpty,
       let json = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]),
       let jsonString = String(data: json, encoding: .utf8) {
      logEntry += " | metadata: \(jsonString)"
    }
    os_log("%{public}@", log: Self.osLog, type: Self.osLogType(for: level), logEntry)
  }
}

/// A centralized error logger that can be backed by Crashlytics, Sentry, or other SDKs.
enum ErrorLogger {
    private static var backend: LoggingBackend = DefaultLoggingBackend()

    nonisolated static func logError(
      _ error: Error,
      message: String? = nil,
      metadata: [String: Any]? = nil,
      file: String = #fileID,
      function: String = #function,
      line: Int = #line
    ) {
        var combinedMessage = "\(error)"
        if let msg = message {
            combinedMessage += " — \(msg)"
        }
        var combinedMetadata = metadata ?? [:]
        combinedMetadata["file"] = file
        combinedMetadata["function"] = function
        combinedMetadata["line"] = line
        backend.log(level: .error, message: combinedMessage, metadata: combinedMetadata)
    }

    nonisolated static func logInfo(_ message: String, metadata: [String: Any]? = nil) {
        backend.log(level: .info, message: message, metadata: metadata)
    }

    nonisolated static func logWarning(_ message: String, metadata: [String: Any]? = nil) {
        backend.log(level: .warning, message: message, metadata: metadata)
    }

    nonisolated static func setBackend(_ newBackend: LoggingBackend) {
        backend = newBackend
    }
}
