//
//  DataImportManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Errors that can occur during data import.
public enum DataImportError: Error {
    case fileNotFound
    case decodeFailed(Error)
    case csvParsingFailed(String)
}

/// Manages importing legacy or backup data into SwiftData.
public class DataImportManager {
    public static let shared = DataImportManager()
    private init() {}

    /// Imports a JSON backup created by `BackupManager`.
    /// - Parameters:
    ///   - url: File URL of the JSON backup.
    ///   - context: The SwiftData model context to insert into.
    public func importBackupJSON(from url: URL, using context: ModelContext) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DataImportError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            // Reuse BackupManager to restore all entities
            try await BackupManager.shared.restore(from: url, using: context)
        } catch {
            throw DataImportError.decodeFailed(error)
        }
    }

    /// Imports a CSV file for a given model type.
    /// The CSV must have a header row matching the model's `Codable` keys.
    /// - Parameters:
    ///   - type: The model type to decode (must conform to `Codable & Identifiable`).
    ///   - url: File URL of the CSV file.
    ///   - context: The SwiftData model context to insert into.
    public func importCSV<Model: Codable & Identifiable>(_ type: Model.Type, from url: URL, using context: ModelContext) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DataImportError.fileNotFound
        }
        let content = try String(contentsOf: url)
        let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard rows.count > 1 else {
            throw DataImportError.csvParsingFailed("No data rows found.")
        }
        let headers = rows[0].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let decoder = JSONDecoder()
        for line in rows.dropFirst() {
            let values = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            var dict = [String: Any]()
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    dict[header] = values[index]
                }
            }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
                let object = try decoder.decode(Model.self, from: jsonData)
                context.insert(object)
            } catch {
                // Skip invalid row but continue processing others
                print("Failed to decode row: \(line); error: \(error)")
            }
        }
    }
}
