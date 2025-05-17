//
//  ExportManager.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import Foundation
import SwiftData

// TODO: Refactor CSV formatting to a separate CSVBuilder for reuse and inject formatters for testability.
@MainActor

/// Central service for exporting application data as CSV files.
/// Supports DogOwner, Appointment, and Charge exports with proper CSV escaping.
final class ExportManager {

  /// Shared singleton instance
  static let shared = ExportManager()

  /// Shared ISO8601 date formatter.
  private let isoFormatter: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fmt
  }()

  private init() {}

  /// Escapes CSV field by doubling quotes and wrapping in quotes.
  private func escape(_ field: String) -> String {
    "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  /// Exports an array of DogOwner entities to a CSV file.
  /// - Parameter owners: The list of DogOwner objects to export.
  /// - Returns: URL of the generated CSV file.
  /// - Throws: An error if writing the file fails.
  func exportOwnersCSV(_ owners: [DogOwner]) throws -> URL {
    var csv = "Owner Name,Email,Phone,Address,Number of Dogs\n"
    for owner in owners {
      let fields: [String] = [
        owner.ownerName,
        owner.email ?? "",
        owner.contactInfo ?? "",
        owner.address ?? "",
        String(owner.dogs.count)
      ]
      csv += fields.map { escape($0) }.joined(separator: ",") + "\n"
    }
    return try write(csv: csv, fileName: "DogOwners.csv")
  }

  /// Exports an array of Appointment entities to a CSV file.
  /// - Parameter appointments: The list of Appointment objects to export.
  /// - Returns: URL of the generated CSV file.
  /// - Throws: An error if writing the file fails.
  func exportAppointmentsCSV(_ appointments: [Appointment]) throws -> URL {
    var csv = "Date,Owner Name,Service Type,Notes\n"
    for appt in appointments {
      let dateStr = isoFormatter.string(from: appt.date)
      let fields: [String] = [
        dateStr,
        appt.dogOwner.ownerName,
        appt.serviceType.rawValue,
        appt.notes ?? ""
      ]
      csv += fields.map { escape($0) }.joined(separator: ",") + "\n"
    }
    return try write(csv: csv, fileName: "Appointments.csv")
  }

  /// Exports an array of Charge entities to a CSV file.
  /// - Parameter charges: The list of Charge objects to export.
  /// - Returns: URL of the generated CSV file.
  /// - Throws: An error if writing the file fails.
  func exportChargesCSV(_ charges: [Charge]) throws -> URL {
    var csv = "Date,Type,Amount,Notes\n"
    for charge in charges {
      let dateStr = isoFormatter.string(from: charge.date)
      let fields: [String] = [
        dateStr,
        charge.serviceType.rawValue,
        String(format: "%.2f", charge.amount),
        charge.notes ?? ""
      ]
      csv += fields.map { escape($0) }.joined(separator: ",") + "\n"
    }
    return try write(csv: csv, fileName: "Charges.csv")
  }

  /// Writes a CSV string to a temporary file and returns its URL.
  /// - Parameters:
  ///   - csv: The CSV content as a string.
  ///   - fileName: Desired file name (e.g., "Data.csv").
  /// - Returns: URL of the written file.
  /// - Throws: An error if file writing fails.
  private func write(csv: String, fileName: String) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(fileName)
    guard let data = csv.data(using: .utf8) else {
      throw NSError(domain: "ExportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode CSV data."])
    }
    try data.write(to: fileURL, options: .atomic)
    return fileURL
  }
}
//
