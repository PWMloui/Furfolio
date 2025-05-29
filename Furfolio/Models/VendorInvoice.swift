
//
//  VendorInvoice.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData
import os

@Model
final class VendorInvoice: Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
    @Attribute var id: UUID
    @Attribute var invoiceNumber: String
    @Attribute var supplierName: String
    @Attribute var issueDate: Date
    @Attribute var dueDate: Date?
    @Attribute var amount: Double
    @Attribute var isPaid: Bool
    @Attribute var notes: String?
    @Relationship(deleteRule: .nullify) var attachments: [VendorInvoiceAttachment] // references the invoice attachment model

    init(
      invoiceNumber: String,
      supplierName: String,
      issueDate: Date = Date(),
      dueDate: Date? = nil,
      amount: Double,
      isPaid: Bool = false,
      notes: String? = nil
    ) {
      self.id = UUID()
      self.invoiceNumber = invoiceNumber
      self.supplierName = supplierName
      self.issueDate = issueDate
      self.dueDate = dueDate
      self.amount = amount
      self.isPaid = isPaid
      self.notes = notes
      logger.log("Initialized VendorInvoice id: \(id), invoiceNumber: \(invoiceNumber), supplierName: \(supplierName), amount: \(amount)")
    }

    // Computed
    var isOverdue: Bool {
      logger.log("Evaluating isOverdue for VendorInvoice id: \(id)")
      guard let due = dueDate else {
        logger.log("isOverdue = false (no dueDate) for VendorInvoice id: \(id)")
        return false
      }
      let overdue = !isPaid && due < Date()
      logger.log("isOverdue result: \(overdue) for VendorInvoice id: \(id)")
      return overdue
    }

    // Hashable
    static func == (lhs: VendorInvoice, rhs: VendorInvoice) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
}

extension VendorInvoice {
    /// Creates and inserts a new VendorInvoice in the given context.
    @discardableResult
    static func create(
        invoiceNumber: String,
        supplierName: String,
        issueDate: Date = Date(),
        dueDate: Date? = nil,
        amount: Double,
        isPaid: Bool = false,
        notes: String? = nil,
        in context: ModelContext
    ) -> VendorInvoice {
        let invoice = VendorInvoice(
            invoiceNumber: invoiceNumber,
            supplierName: supplierName,
            issueDate: issueDate,
            dueDate: dueDate,
            amount: amount,
            isPaid: isPaid,
            notes: notes
        )
        invoice.logger.log("Creating VendorInvoice via factory: \(invoiceNumber)")
        context.insert(invoice)
        do {
            try context.save()
            invoice.logger.log("Inserted VendorInvoice id: \(invoice.id)")
        } catch {
            invoice.logger.error("Failed to save VendorInvoice: \(error.localizedDescription)")
        }
        return invoice
    }

    /// Fetches all VendorInvoice entries.
    static func fetchAll(in context: ModelContext) -> [VendorInvoice] {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
            .log("Fetching all VendorInvoices")
        let descriptor = FetchDescriptor<VendorInvoice>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        do {
            let results = try context.fetch(descriptor)
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
                .log("Fetched \(results.count) VendorInvoices")
            return results
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
                .error("VendorInvoice.fetchAll failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetches overdue invoices.
    static func fetchOverdue(in context: ModelContext) -> [VendorInvoice] {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
            .log("Fetching overdue VendorInvoices")
        let now = Date()
        let descriptor = FetchDescriptor<VendorInvoice>(
            predicate: #Predicate { $0.isOverdue },
            sortBy: [SortDescriptor(\.dueDate!, order: .forward)]
        )
        do {
            let results = try context.fetch(descriptor)
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
                .log("Fetched \(results.count) overdue VendorInvoices")
            return results
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "VendorInvoice")
                .error("VendorInvoice.fetchOverdue failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Marks this invoice as paid.
    func markPaid(in context: ModelContext) {
        logger.log("Marking VendorInvoice \(id) as paid")
        isPaid = true
        do {
            try context.save()
            logger.log("Marked paid and saved VendorInvoice \(id)")
        } catch {
            logger.error("Failed to mark VendorInvoice \(id) as paid: \(error.localizedDescription)")
        }
    }

    /// Marks this invoice as unpaid.
    func markUnpaid(in context: ModelContext) {
        logger.log("Marking VendorInvoice \(id) as unpaid")
        isPaid = false
        do {
            try context.save()
            logger.log("Marked unpaid and saved VendorInvoice \(id)")
        } catch {
            logger.error("Failed to mark VendorInvoice \(id) as unpaid: \(error.localizedDescription)")
        }
    }
}

