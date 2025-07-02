//
//  AuditExportManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Errors that can occur during audit export.
public enum AuditExportError: Error {
    case fileCreationFailed
    case notImplemented
}

/// Manages exporting audit trail entries to common formats.
public class AuditExportManager {
    public static let shared = AuditExportManager()
    private init() {}

    private let fileManager = FileManager.default

    /// Exports an array of `AuditTrailEntry` models to a CSV file in the app’s Documents directory.
    /// - Parameters:
    ///   - entries: The audit entries to export.
    ///   - fileName: The base file name (without extension).
    /// - Returns: The file URL of the written CSV.
    /// - Throws: `AuditExportError.fileCreationFailed` if writing fails.
    public func exportToCSV(_ entries: [AuditTrailEntry], fileName: String = "AuditLog") throws -> URL {
        // Build CSV header
        var csvText = "ID,Timestamp,User,Action,Details\n"
        let isoFormatter = ISO8601DateFormatter()
        for entry in entries {
            let id = entry.id.uuidString
            let timestamp = isoFormatter.string(from: entry.timestamp)
            let user = entry.user ?? ""
            // Escape quotes in action and details
            let action = entry.action.replacingOccurrences(of: "\"", with: "\"\"")
            let details = (entry.details ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csvText += "\"\(id)\",\"\(timestamp)\",\"\(user)\",\"\(action)\",\"\(details)\"\n"
        }

        // Write to file
        let docsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = docsURL.appendingPathComponent("\(fileName).csv")
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw AuditExportError.fileCreationFailed
        }
        return fileURL
    }

    /// Stub for exporting audit entries to a PDF file.
    /// - Parameters:
    ///   - entries: The audit entries to export.
    ///   - fileName: The base file name (without extension).
    /// - Returns: The file URL of the written PDF.
    /// - Throws: `.notImplemented` for now.
    public func exportToPDF(_ entries: [AuditTrailEntry], fileName: String = "AuditLog") throws -> URL {
        // PDF export not implemented yet.
        throw AuditExportError.notImplemented
    }
}
