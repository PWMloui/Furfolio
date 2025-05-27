
//
//  VendorInvoice.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData

@Model
final class VendorInvoice: Identifiable, Hashable {
    @Attribute var id: UUID
    @Attribute var invoiceNumber: String
    @Attribute var supplierName: String
    @Attribute var issueDate: Date
    @Attribute var dueDate: Date?
    @Attribute var amount: Double
    @Attribute var isPaid: Bool
    @Attribute var notes: String?
    @Relationship(deleteRule: .nullify) var attachments: [PetGalleryImage] // if you have a gallery image model

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
    }

    // Computed
    var isOverdue: Bool {
      guard let due = dueDate else { return false }
      return !isPaid && due < Date()
    }

    // Hashable
    static func == (lhs: VendorInvoice, rhs: VendorInvoice) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
}

