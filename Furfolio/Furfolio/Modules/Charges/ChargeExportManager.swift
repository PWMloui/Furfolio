//
//  ChargeExportManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular CSV Export Utility with Full Audit Trail
//

import Foundation

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
    static private(set) var log: [ChargeExportAuditEvent] = []

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge export events recorded."
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
    public static var lastSummary: String { ChargeExportAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeExportAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeExportAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
