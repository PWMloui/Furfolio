//
//  BankFeedImporter.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData

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
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  /// Imports bank transactions from a CSV at the given URL.
  /// - Parameter url: Local file URL of the CSV.
  /// - Returns: An ImportResult with the new transactions and any matched invoices.
  func importCSV(from url: URL) throws -> ImportResult {
    let content = try String(contentsOf: url)
    var imported: [BankTransaction] = []
    var matched: [VendorInvoice] = []

    let rows = content.components(separatedBy: .newlines)
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
      imported.append(tx)

      // Attempt to match to existing VendorInvoice
      if let invoice = matchInvoice(for: tx) {
        matched.append(invoice)
      }
    }

    try context.save()
    return ImportResult(imported: imported, matchedInvoices: matched)
  }

  /// Matches a bank transaction to a VendorInvoice if possible.
  private func matchInvoice(for transaction: BankTransaction) -> VendorInvoice? {
    // Simple matching by amount and date proximity
    let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: transaction.date)!
    let predicate = #Predicate<VendorInvoice> {
      $0.amount == transaction.amount && $0.dueDate >= cutoff && $0.dueDate <= transaction.date
    }
    if let invoice = context.fetch(predicate).first {
      return invoice
    }
    return nil
  }
}
