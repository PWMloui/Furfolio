//
//  AccountingExporter.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData
import os

private let accountingLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AccountingExporter")

/// Exports accounting data such as income statements and balance sheets.
final class AccountingExporter {
    private let logger = accountingLogger
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    /// Exports an income statement for the given period to CSV.
    func exportIncomeStatementCSV(from startDate: Date, to endDate: Date, context: ModelContext) async throws -> URL {
        logger.log("Starting exportIncomeStatementCSV from \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))")
        // Query charges and revenue entries
        let feesRequest: FetchDescriptor<Charge> = FetchDescriptor(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate }
        )
        let charges = (try? context.fetch(feesRequest)) ?? []
        // Build CSV rows: Date, Type, Amount
        var csv = "Date,Type,Amount\n"
        for charge in charges {
            let date = dateFormatter.string(from: charge.date)
            let type = charge.type
            let amount = String(format: "%.2f", charge.amount)
            csv += "\(date),\(type),\(amount)\n"
        }
        // Write to file
        let filename = "IncomeStatement_\(dateFormatter.string(from: startDate))_to_\(dateFormatter.string(from: endDate)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        logger.log("Completed exportIncomeStatementCSV, file at \(url.path)")
        return url
    }

    /// Exports a balance sheet snapshot on the given date to CSV.
    func exportBalanceSheetCSV(on date: Date, context: ModelContext) async throws -> URL {
        logger.log("Starting exportBalanceSheetCSV for date \(dateFormatter.string(from: date))")
        // Assets and liabilities might be represented as Charges with negative/positive flags
        let allRequest: FetchDescriptor<Charge> = FetchDescriptor()
        let charges = (try? context.fetch(allRequest)) ?? []
        // Summarize assets (positive) and liabilities (negative)
        let assets = charges.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount }
        let liabilities = charges.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }
        let csv = """
        Category,Amount
        Assets,\(String(format: "%.2f", assets))
        Liabilities,\(String(format: "%.2f", abs(liabilities)))
        Equity,\(String(format: "%.2f", assets + liabilities))
        """
        let filename = "BalanceSheet_\(dateFormatter.string(from: date)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        logger.log("Completed exportBalanceSheetCSV, file at \(url.path)")
        return url
    }
}
