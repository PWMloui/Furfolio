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

/// A utility responsible for exporting financial data to CSV.
struct AccountingExporter {
    /// Escapes a value for CSV output (wraps in quotes, doubles quotes inside).
    private static func escapeCSV(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    /// Exports all Charges in the given context to a CSV file at the specified URL.
    static func exportChargesCSV(in context: ModelContext, to url: URL) throws {
        accountingLogger.log("Starting exportChargesCSV: fetching charges")
        let charges: [Charge] = try context.fetch(Charge.fetchRequest())
        accountingLogger.log("Fetched \(charges.count) charges")
        var csvLines: [String] = []
        // Header
        csvLines.append("Date,Owner,ServiceType,Amount,PaymentMethod,Notes")
        // Rows
        for charge in charges {
            let date = isoFormatter.string(from: charge.date)
            let ownerName = escapeCSV(charge.owner?.name ?? "")
            let service = escapeCSV(charge.serviceType.rawValue)
            let amount = String(format: "%.2f", charge.amount)
            let payment = escapeCSV(charge.paymentMethod.rawValue)
            let notes = escapeCSV(charge.notes)
            csvLines.append([date, ownerName, service, amount, payment, notes].joined(separator: ","))
        }
        let csvString = csvLines.joined(separator: "\n")
        accountingLogger.log("Writing charges CSV to \(url.path)")
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        accountingLogger.log("Completed exportChargesCSV to \(url.path)")
    }

    /// Exports all Expenses in the given context to a CSV file at the specified URL.
    static func exportExpensesCSV(in context: ModelContext, to url: URL) throws {
        accountingLogger.log("Starting exportExpensesCSV: fetching expenses")
        let expenses: [Expense] = try context.fetch(Expense.fetchRequest())
        accountingLogger.log("Fetched \(expenses.count) expenses")
        var csvLines: [String] = []
        // Header
        csvLines.append("Date,Category,Amount,Notes")
        // Rows
        for expense in expenses {
            let date = isoFormatter.string(from: expense.date)
            let category = escapeCSV(expense.category)
            let amount = String(format: "%.2f", expense.amount)
            let notes = escapeCSV(expense.notes)
            csvLines.append([date, category, amount, notes].joined(separator: ","))
        }
        let csvString = csvLines.joined(separator: "\n")
        accountingLogger.log("Writing expenses CSV to \(url.path)")
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        accountingLogger.log("Completed exportExpensesCSV to \(url.path)")
    }

    /// Generates a Profit & Loss summary CSV combining Charges and Expenses.
    static func exportProfitAndLossCSV(in context: ModelContext, to url: URL) throws {
        accountingLogger.log("Starting exportProfitAndLossCSV")
        // Fetch revenue and expenses
        let charges: [Charge] = try context.fetch(Charge.fetchRequest())
        let expenses: [Expense] = try context.fetch(Expense.fetchRequest())
        accountingLogger.log("Fetched \(charges.count) charges and \(expenses.count) expenses")

        // Calculate totals
        let totalRevenue = charges.reduce(0) { $0 + $1.amount }
        let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
        let netProfit = totalRevenue - totalExpenses
        accountingLogger.log("Calculated totals: totalRevenue=\(totalRevenue, format: .number), totalExpenses=\(totalExpenses, format: .number), netProfit=\(netProfit, format: .number)")

        var csvLines: [String] = []
        csvLines.append("Metric,Amount")
        csvLines.append(["Total Revenue", String(format: "%.2f", totalRevenue)].joined(separator: ","))
        csvLines.append(["Total Expenses", String(format: "%.2f", totalExpenses)].joined(separator: ","))
        csvLines.append(["Net Profit", String(format: "%.2f", netProfit)].joined(separator: ","))

        let csvString = csvLines.joined(separator: "\n")
        accountingLogger.log("Writing ProfitAndLoss CSV to \(url.path)")
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        accountingLogger.log("Completed exportProfitAndLossCSV to \(url.path)")
    }
}
