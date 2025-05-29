//
//  BankFeedImporter.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData
import os

@Model
final class BankTransaction: Identifiable {
  @Attribute var id: UUID = .init()
  @Attribute var date: Date
  @Attribute var description: String
  @Attribute var amount: Double
  @Attribute var type: String

  init(date: Date, description: String, amount: Double, type: String) {
    self.date = date
    self.description = description
    self.amount = amount
    self.type = type
  }
}

struct ImportResult {
  let imported: [BankTransaction]
  let matchedInvoices: [VendorInvoice]
}

final class BankFeedImporter {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "BankFeedImporter")
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
    logger.log("Initialized BankFeedImporter with context: \(context)")
  }

  /// Imports bank transactions from a CSV at the given URL.
  /// - Parameter url: Local file URL of the CSV.
  /// - Returns: An ImportResult with the new transactions and any matched invoices.
  func importCSV(from url: URL) throws -> ImportResult {
    logger.log("Starting CSV import from URL: \(url.path)")
    let content = try String(contentsOf: url)
    let rows = content.components(separatedBy: .newlines)
    logger.log("Parsed \(rows.count - 1) data rows (excluding header)")
    var imported: [BankTransaction] = []
    var matched: [VendorInvoice] = []

    for row in rows.dropFirst() where !row.isEmpty {
      let columns = row.components(separatedBy: ",")
      guard columns.count >= 4,
            let date = ISO8601DateFormatter().date(from: columns[0]),
            let amount = Double(columns[2]) else {
        continue
      }
      let description = columns[1]
      let type = columns[3]
      let tx = BankTransaction(date: date, description: description, amount: amount, type: type)
      context.insert(tx)
      logger.log("Imported transaction: id=\(tx.id), date=\(tx.date), amount=\(tx.amount), type=\(tx.type)")
      imported.append(tx)

      // Attempt to match to existing VendorInvoice
      if let invoice = matchInvoice(for: tx) {
        logger.log("Matched invoice \(invoice.id) to transaction \(tx.id)")
        matched.append(invoice)
      }
    }

    try context.save()
    logger.log("Saved \(imported.count) transactions, matched \(matched.count) invoices")
    return ImportResult(imported: imported, matchedInvoices: matched)
  }

  /// Matches a bank transaction to a VendorInvoice if possible.
  private func matchInvoice(for transaction: BankTransaction) -> VendorInvoice? {
    logger.log("Attempting to match invoice for transaction id=\(transaction.id)")
    // Simple matching by amount and date proximity
    let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: transaction.date)!
    let predicate = #Predicate<VendorInvoice> {
      $0.amount == transaction.amount && $0.dueDate >= cutoff && $0.dueDate <= transaction.date
    }
    if let invoice = context.fetch(predicate).first {
      logger.log("Found matching invoice id=\(invoice.id) for transaction \(transaction.id)")
      return invoice
    }
    logger.log("No matching invoice found for transaction \(transaction.id)")
    return nil
  }
}
