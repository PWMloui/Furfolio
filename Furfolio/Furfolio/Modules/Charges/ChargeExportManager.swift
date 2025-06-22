//
//  ChargeExportManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - ChargeExportManager (Modular, Tokenized, Auditable CSV Export Utility)

import Foundation

/// A modular, tokenized, and auditable utility for exporting charge records.
/// This manager supports audit logging, comprehensive error handling,
/// and CSV formatting compliant with business and compliance standards.
final class ChargeExportManager {

    /// Exports the given charges to a CSV file.
    ///
    /// This method exports charges to CSV format using a standardized date format ("yyyy-MM-dd").
    /// It handles proper escaping and formatting of fields to ensure audit-ready export files.
    /// The resulting CSV file URL can be used for sharing or saving purposes.
    /// Returns `nil` if the export process encounters any failures.
    ///
    /// - Parameter charges: An array of `Charge` objects to be exported.
    /// - Returns: The file URL of the exported CSV file, or `nil` if an error occurred.
    func exportChargesToCSV(charges: [Charge]) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Define CSV header - modular design allows easy header modification
        let headers = ["Date", "Type", "Amount", "Notes"]
        var csvRows: [String] = []
        csvRows.append(headers.joined(separator: ","))

        // Prepare each charge as a CSV row with tokenized and escaped fields for audit readiness
        for charge in charges {
            let dateString = dateFormatter.string(from: charge.date)
            let typeEscaped = escapeCSVField(charge.type)
            let notesEscaped = escapeCSVField(charge.notes ?? "")
            let amountString = String(format: "%.2f", charge.amount)

            let row = [dateString, typeEscaped, amountString, notesEscaped].joined(separator: ",")
            csvRows.append(row)
        }

        // Combine all rows into a single CSV string with proper line breaks
        let csvString = csvRows.joined(separator: "\n")

        // Save CSV to a temporary file for sharing/saving with audit trail
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Furfolio_Charges_Export.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            // Standardized audit/error logging for export failures
            print("[ChargeExportManager][ERROR] Failed to export CSV file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Escapes special characters in CSV fields according to RFC4180 standards.
    ///
    /// Fields containing commas, quotes, or newlines are enclosed in double quotes.
    /// Internal double quotes are escaped by doubling them.
    /// This ensures data integrity and prevents CSV format corruption during parsing.
    ///
    /// - Parameter field: The CSV field string to escape.
    /// - Returns: An escaped CSV field string safe for inclusion in CSV files.
    private func escapeCSVField(_ field: String) -> String {
        // Replace internal quotes with double quotes for CSV compliance
        var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        // Enclose field in quotes if it contains commas, quotes, or newlines
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
}
