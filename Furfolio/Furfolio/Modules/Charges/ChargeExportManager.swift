//
//  ChargeExportManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular CSV Export Utility with Full Audit Trail
//

import Foundation

#if DEBUG
import SwiftUI
#endif

// MARK: - ChargeExport Audit/Event Logging

fileprivate struct ChargeExportAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "export"
    let chargeCount: Int
    let fileURL: URL?
    let error: String?
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[Export] \(chargeCount) charges"
        if let url = fileURL { base += " → \(url.lastPathComponent)" }
        if let error { base += " [ERROR: \(error)]" }
        base += " at \(dateStr)"
        if let detail { base += ": \(detail)" }
        return base
    }
}

fileprivate final class ChargeExportAudit {
    /// Internal log of audit events, capped at 100 most recent.
    static private(set) var log: [ChargeExportAuditEvent] = []

    /// Records a new audit event with full context.
    ///
    /// - Parameters:
    ///   - operation: The operation type, e.g. "export".
    ///   - chargeCount: Number of charges involved in the operation.
    ///   - fileURL: The URL of the exported file, if any.
    ///   - error: Error description if operation failed.
    ///   - actor: Who performed the operation, default "system".
    ///   - context: Context or source of the operation, default "ChargeExportManager".
    ///   - detail: Additional details or notes.
    static func record(
        operation: String,
        chargeCount: Int,
        fileURL: URL?,
        error: String?,
        actor: String? = "system",
        context: String? = "ChargeExportManager",
        detail: String? = nil
    ) {
        let event = ChargeExportAuditEvent(
            timestamp: Date(),
            operation: operation,
            chargeCount: chargeCount,
            fileURL: fileURL,
            error: error,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
    }

    /// Exports the most recent audit event as pretty-printed JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides an accessibility-friendly summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge export events recorded."
    }

    // MARK: - New Enhancements

    /// Total number of export events recorded in the audit log.
    static var totalExports: Int {
        log.filter { $0.operation == "export" }.count
    }

    /// The URL of the last successful export (no error).
    static var lastSuccessfulExportURL: URL? {
        log.reversed().first(where: { $0.operation == "export" && $0.error == nil })?.fileURL
    }

    /// The error description of the last export failure, if any.
    static var lastExportError: String? {
        log.reversed().first(where: { $0.operation == "export" && $0.error != nil })?.error
    }

    /// Exports the entire audit log as a CSV string with headers:
    /// timestamp,operation,chargeCount,fileURL,error,actor,context,detail
    ///
    /// - Returns: CSV string representing all audit events.
    static func exportCSV() -> String {
        let headers = ["timestamp", "operation", "chargeCount", "fileURL", "error", "actor", "context", "detail"]
        var rows: [String] = []
        rows.append(headers.joined(separator: ","))

        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = dateFormatter.string(from: event.timestamp)
            let operation = escapeCSVField(event.operation)
            let chargeCount = String(event.chargeCount)
            let fileURL = escapeCSVField(event.fileURL?.absoluteString ?? "")
            let error = escapeCSVField(event.error ?? "")
            let actor = escapeCSVField(event.actor ?? "")
            let context = escapeCSVField(event.context ?? "")
            let detail = escapeCSVField(event.detail ?? "")
            let row = [timestamp, operation, chargeCount, fileURL, error, actor, context, detail].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }

    /// Helper to escape CSV fields according to RFC4180.
    private static func escapeCSVField(_ field: String) -> String {
        var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - ChargeExportManager (Modular, Tokenized, Auditable CSV Export Utility)

final class ChargeExportManager {

    /// Exports the given charges to a CSV file with audit/event logging.
    ///
    /// Returns the file URL or nil if an error occurred, and logs all attempts.
    func exportChargesToCSV(charges: [Charge]) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let headers = ["Date", "Type", "Amount", "Notes"]
        var csvRows: [String] = []
        csvRows.append(headers.joined(separator: ","))

        for charge in charges {
            let dateString = dateFormatter.string(from: charge.date)
            let typeEscaped = escapeCSVField(charge.type)
            let notesEscaped = escapeCSVField(charge.notes ?? "")
            let amountString = String(format: "%.2f", charge.amount)
            let row = [dateString, typeEscaped, amountString, notesEscaped].joined(separator: ",")
            csvRows.append(row)
        }

        let csvString = csvRows.joined(separator: "\n")

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Furfolio_Charges_Export.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            ChargeExportAudit.record(
                operation: "export",
                chargeCount: charges.count,
                fileURL: fileURL,
                error: nil,
                detail: "Exported charges to CSV successfully"
            )
            return fileURL
        } catch {
            ChargeExportAudit.record(
                operation: "export",
                chargeCount: charges.count,
                fileURL: nil,
                error: error.localizedDescription,
                detail: "Failed to export charges to CSV"
            )
            print("[ChargeExportManager][ERROR] Failed to export CSV file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Escapes special characters in CSV fields according to RFC4180 standards.
    private func escapeCSVField(_ field: String) -> String {
        var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeExportAuditAdmin {
    /// Provides a textual summary of the last audit event.
    public static var lastSummary: String { ChargeExportAudit.accessibilitySummary }

    /// Provides the last audit event as pretty-printed JSON.
    public static var lastJSON: String? { ChargeExportAudit.exportLastJSON() }

    /// Provides the most recent audit events' accessibility labels, limited by count.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeExportAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    /// Provides the total count of export events recorded.
    public static var totalExports: Int { ChargeExportAudit.totalExports }

    /// Provides the URL of the last successful export, if any.
    public static var lastSuccessfulExportURL: URL? { ChargeExportAudit.lastSuccessfulExportURL }

    /// Provides the error description of the last failed export, if any.
    public static var lastExportError: String? { ChargeExportAudit.lastExportError }

    /// Exports the full audit log as CSV string.
    public static func exportCSV() -> String {
        ChargeExportAudit.exportCSV()
    }
}

#if DEBUG
// MARK: - DEV Overlay Utility: ChargeExportAuditSummaryView

/// SwiftUI view displaying a summary of the last 3 audit events and analytics.
///
/// Useful for developers to quickly inspect export audit history and state.
struct ChargeExportAuditSummaryView: View {
    /// The last three audit events to display.
    private var recentEvents: [ChargeExportAuditEvent] {
        Array(ChargeExportAudit.log.suffix(3).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Charge Export Audit Summary")
                .font(.headline)
                .padding(.bottom, 4)

            Group {
                Text("Total Exports: \(ChargeExportAudit.totalExports)")
                Text("Last Successful Export URL: \(ChargeExportAudit.lastSuccessfulExportURL?.absoluteString ?? "None")")
                Text("Last Export Error: \(ChargeExportAudit.lastExportError ?? "None")")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()

            Text("Last 3 Audit Events:")
                .font(.subheadline)
                .bold()

            ForEach(recentEvents.indices, id: \.self) { idx in
                let event = recentEvents[idx]
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.accessibilityLabel)
                        .font(.caption)
                        .lineLimit(nil)
                }
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding()
    }
}
#endif
