//
//  InventoryItem.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData

@MainActor


@Model
final class InventoryItem: Identifiable, Hashable {
  
  /// Shared number and date formatters to avoid repeated allocations.
  private static let currencyFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = .current
    return fmt
  }()
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    return fmt
  }()
  
  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current
  
  // MARK: – Persistent Properties
  
  /// Unique identifier for the inventory item.
  @Attribute
  var id: UUID = UUID()               // was `.init()`
  
  /// Name of the inventory item.
  @Attribute(.required)
  var name: String
  
  /// Category of the inventory item.
  @Attribute
  var category: String?
  
  /// Quantity of the item currently on hand.
  @Attribute(.required)
  var quantityOnHand: Int
  
  /// Threshold at which reorder is recommended.
  @Attribute(.required)
  var reorderThreshold: Int
  
  /// Cost price of the item.
  @Attribute(.required)
  var costPrice: Double
  
  /// Selling price of the item.
  @Attribute(.required)
  var sellPrice: Double
  
  /// Additional notes about the item.
  @Attribute
  var notes: String?
  
  /// Date the item was created.
  @Attribute
  var createdAt: Date = Date.now      // was `.now`
  
  /// Date the item was last updated.
  @Attribute
  var updatedAt: Date?
  
  
  // MARK: – Initialization
  
  /// Initializes an InventoryItem, trimming inputs and enforcing non-negative defaults.
  init(
    name: String,
    category: String? = nil,
    quantityOnHand: Int = 0,
    reorderThreshold: Int = 0,
    costPrice: Double = 0,
    sellPrice: Double = 0,
    notes: String? = nil
  ) {
    self.name             = name.trimmingCharacters(in: .whitespacesAndNewlines)
    self.category         = category?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.quantityOnHand   = max(0, quantityOnHand)
    self.reorderThreshold = max(0, reorderThreshold)
    self.costPrice        = max(0, costPrice)
    self.sellPrice        = max(0, sellPrice)
    self.notes            = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    // createdAt default applies
  }
  
  /// Designated initializer for InventoryItem.
  init(
    id: UUID = UUID(),
    name: String,
    category: String? = nil,
    quantityOnHand: Int = 0,
    reorderThreshold: Int = 0,
    costPrice: Double = 0,
    sellPrice: Double = 0,
    notes: String? = nil,
    createdAt: Date = Date.now,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    self.category = category?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.quantityOnHand = max(0, quantityOnHand)
    self.reorderThreshold = max(0, reorderThreshold)
    self.costPrice = max(0, costPrice)
    self.sellPrice = max(0, sellPrice)
    self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
  
  
  // MARK: – Computed Properties
  
  /// Total value of the current stock of this item.
  @Transient
  var totalValue: Double {
    Double(quantityOnHand) * sellPrice
  }
  
  /// Profit margin per unit.
  @Transient
  var profitMargin: Double {
    sellPrice - costPrice
  }
  
  /// Profit margin as a percentage of cost price.
  @Transient
  var profitMarginPercent: Double {
    guard costPrice > 0 else { return 0 }
    return (profitMargin / costPrice) * 100
  }
  
  /// Indicates if stock is below or equal to reorder threshold.
  @Transient
  var isLowStock: Bool {
    quantityOnHand <= reorderThreshold
  }
  
  /// Recommended quantity to reorder based on threshold.
  @Transient
  var recommendedReorderQuantity: Int {
    max(0, reorderThreshold * 2 - quantityOnHand)
  }
  
  /// Formatted string of the cost price.
  @Transient
  var formattedCostPrice: String {
    Self.currencyFormatter.string(from: NSNumber(value: costPrice)) ?? "\(costPrice)"
  }
  
  /// Formatted string of the selling price.
  @Transient
  var formattedSellPrice: String {
    Self.currencyFormatter.string(from: NSNumber(value: sellPrice)) ?? "\(sellPrice)"
  }
  
  /// Formatted string of the total stock value.
  @Transient
  var formattedTotalValue: String {
    Self.currencyFormatter.string(from: NSNumber(value: totalValue)) ?? "\(totalValue)"
  }
  
  /// Number of days since the item was last updated.
  @Transient
  var daysSinceUpdate: Int? {
    guard let updated = updatedAt else { return nil }
    return Self.calendar.dateComponents([.day], from: updated, to: Date.now).day
  }
  
  /// Human-readable string representing days since last update.
  @Transient
  var daysSinceUpdateString: String? {
    guard let d = daysSinceUpdate else { return nil }
    return d == 0 ? "Today" : "\(d) day\(d > 1 ? "s" : "") ago"
  }
  
  /// Age of the item in days since creation.
  @Transient
  var ageInDays: Int {
    Self.calendar.dateComponents([.day], from: createdAt, to: Date.now).day ?? 0
  }
  
  /// Summary description of the inventory item.
  @Transient
  var summary: String {
    let cat = category ?? "Uncategorized"
    let lowTag = isLowStock ? " (LOW STOCK)" : ""
    return "\(name) [\(cat)] — \(quantityOnHand) on hand\(lowTag); Value: \(formattedTotalValue)"
  }
  
  
  // MARK: – Validation
  
  /// True if the item has a non-empty name and non-negative pricing and stock.
  var isValid: Bool {
    !name.isEmpty && quantityOnHand >= 0 && sellPrice >= costPrice
  }
  
  
  // MARK: – Stock Management
  
  /// Adjusts stock by a delta, ensuring non-negative quantity and stamping `updatedAt`.
  func adjustStock(by delta: Int) {
    quantityOnHand = max(0, quantityOnHand + delta)
    updatedAt = Date.now    // was `.now`
  }
  
  /// Updates the reorder threshold and stamps `updatedAt`.
  func updateReorderThreshold(_ threshold: Int) {
    reorderThreshold = max(0, threshold)
    updatedAt = Date.now    // was `.now`
  }
  
  /// Updates cost and sell prices, enforcing non-negative values and stamping `updatedAt`.
  func updatePrices(cost: Double, sell: Double) {
    costPrice  = max(0, cost)
    sellPrice  = max(0, sell)
    updatedAt  = Date.now   // was `.now`
  }
  
  /// Updates name, category, and notes, trimming inputs and stamping `updatedAt`.
  func updateInfo(name: String, category: String?, notes: String?) {
    self.name     = name.trimmingCharacters(in: .whitespacesAndNewlines)
    self.category = category?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.notes    = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    updatedAt     = Date.now   // was `.now`
  }
  
  
  // MARK: – Static Helpers & Fetch
  
  /// Creates and inserts a new InventoryItem into the context.
  @discardableResult
  static func create(
    name: String,
    category: String? = nil,
    quantityOnHand: Int = 0,
    reorderThreshold: Int = 0,
    costPrice: Double = 0,
    sellPrice: Double = 0,
    notes: String? = nil,
    in context: ModelContext
  ) -> InventoryItem {
    let item = InventoryItem(
      name: name,
      category: category,
      quantityOnHand: quantityOnHand,
      reorderThreshold: reorderThreshold,
      costPrice: costPrice,
      sellPrice: sellPrice,
      notes: notes
    )
    context.insert(item)
    return item
  }
  
  /// Fetches all InventoryItem sorted by name.
  static func fetchAll(in context: ModelContext) -> [InventoryItem] {
    let desc = FetchDescriptor<InventoryItem>(
      sortBy: [SortDescriptor(\InventoryItem.name, order: .forward)]
    )
    return (try? context.fetch(desc)) ?? []
  }
  
  /// Fetches InventoryItem filtered by category.
  static func fetch(category: String?, in context: ModelContext) -> [InventoryItem] {
    let predicate: Predicate<InventoryItem>? = {
      guard let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines),
            !cat.isEmpty
      else { return nil }
      return #Predicate { $0.category == cat }
    }()
    let desc = FetchDescriptor<InventoryItem>(
      predicate: predicate,
      sortBy: [SortDescriptor(\InventoryItem.name, order: .forward)]
    )
    return (try? context.fetch(desc)) ?? []
  }
  
  /// Fetches InventoryItem with low stock.
  static func fetchLowStock(in context: ModelContext) -> [InventoryItem] {
    let desc = FetchDescriptor<InventoryItem>(
      predicate: #Predicate { $0.isLowStock },
      sortBy: [SortDescriptor(\InventoryItem.name, order: .forward)]
    )
    return (try? context.fetch(desc)) ?? []
  }
  
  /// Fetches top value InventoryItem limited to the specified count.
  static func fetchTopValue(limit: Int = 5, in context: ModelContext) -> [InventoryItem] {
    fetchAll(in: context)
      .sorted { $0.totalValue > $1.totalValue }
      .prefix(limit)
      .map { $0 }
  }
  
  
  // MARK: – Hashable
  
  static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}


// MARK: – Preview Data

#if DEBUG
import SwiftUI
extension InventoryItem {
  static var sample: InventoryItem {
    InventoryItem(
      name: "Deluxe Dog Shampoo",
      category: "Grooming Supplies",
      quantityOnHand: 12,
      reorderThreshold: 5,
      costPrice: 4.50,
      sellPrice: 9.99,
      notes: "Organic, lavender-scented"
    )
  }
}
#endif
