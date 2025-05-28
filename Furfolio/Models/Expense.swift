// Expense.swift
// Furfolio
//
// Created by ChatGPT on 06/27/2025.

import Foundation
import SwiftData
import UIKit

@Model
final class Expense: Identifiable, Hashable {
  // MARK: - Persistent Properties

  @Attribute var id: UUID
  @Attribute var date: Date
  @Attribute var category: String
  @Attribute var amount: Double
  @Attribute var notes: String?
  /// Stored as JPEG/PNG data
  @Attribute(.externalStorage) var receiptImageData: Data?

  // MARK: - Init

  init(
    id: UUID = UUID(),
    date: Date = Date(),
    category: String,
    amount: Double,
    notes: String? = nil,
    receiptImage: UIImage? = nil
  ) {
    self.id = id
    self.date = date
    self.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
    self.amount = amount
    self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let img = receiptImage, let data = img.jpegData(compressionQuality: 0.8) {
      self.receiptImageData = data
    } else {
      self.receiptImageData = nil
    }
  }

  // MARK: - Computed

  /// UI-friendly image
  @Transient
  var receiptImage: UIImage? {
    guard let data = receiptImageData else { return nil }
    return UIImage(data: data)
  }

  // MARK: - Hashable

  static func == (lhs: Expense, rhs: Expense) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: - Fetch Helpers

  /// All expenses sorted by date descending
  static func fetchAll(in context: ModelContext) -> [Expense] {
    let desc = FetchDescriptor<Expense>(
      sortBy: [ SortDescriptor<Expense>(\.date, order: .reverse) ]
    )
    return (try? context.fetch(desc)) ?? []
  }

  /// Expenses in the given date range
  static func fetch(in context: ModelContext, from start: Date, to end: Date) -> [Expense] {
    let predicate = #Predicate<Expense> { $0.date >= start && $0.date <= end }
    let desc = FetchDescriptor<Expense>(
      predicate: predicate,
      sortBy: [ SortDescriptor<Expense>(\.date, order: .reverse) ]
    )
    return (try? context.fetch(desc)) ?? []
  }
}
