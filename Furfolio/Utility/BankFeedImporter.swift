//
//  BankFeedImporter.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//


import Foundation
import SwiftData
import os

private let bankLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "BankFeedImporter")

/// A model representing a bank transaction.
/// Ensure you have a `@Model class BankTransaction` with `date: Date, description: String, amount: Double, id: UUID` defined in your SwiftData models.
final class BankFeedImporter {
    private let logger = bankLogger
    private let context: ModelContext
    private let csvDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    init(context: ModelContext) {
        self.context = context
        logger.log("Initialized BankFeedImporter")
    }

    /// Imports transactions from a local CSV file.
    /// - Parameter url: The local file URL of the CSV.
    /// - Returns: An array of saved `BankTransaction` instances.
    @discardableResult
    func importCSV(from url: URL) async throws -> [BankTransaction] {
        logger.log("Starting importCSV from local file: \(url.path)")
        let data = try Data(contentsOf: url)
        return try await processCSVData(data)
    }

    /// Fetches a CSV from a remote URL and imports it.
    /// - Parameter url: The remote CSV endpoint.
    /// - Returns: An array of saved `BankTransaction` instances.
    @discardableResult
    func fetchAndImport(from url: URL) async throws -> [BankTransaction] {
        logger.log("Fetching CSV from remote URL: \(url.absoluteString)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try await processCSVData(data)
    }

    /// Parses CSV data and saves transactions.
    private func processCSVData(_ data: Data) async throws -> [BankTransaction] {
        guard let text = String(data: data, encoding: .utf8) else {
            logger.error("Unable to decode CSV data as UTF-8 text")
            throw NSError(domain: "CSVDecodeError", code: 0, userInfo: nil)
        }
        let lines = text
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: "\n")
        logger.log("Parsing CSV with \(lines.count - 1) data rows")
        var saved: [BankTransaction] = []
        // Assume first line is header
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 3,
                  let date = csvDateFormatter.date(from: fields[0]),
                  let amount = Double(fields[2]) else {
                logger.error("Skipping invalid CSV row: \(line)")
                continue
            }
            let description = fields[1]
            let transaction = BankTransaction(date: date, description: description, amount: amount, id: UUID())
            context.insert(transaction)
            saved.append(transaction)
        }
        logger.log("Saving \(saved.count) transactions to context")
        try context.save()
        logger.log("Saved transactions successfully")
        return saved
    }
}
