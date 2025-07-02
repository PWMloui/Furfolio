//
//  InventoryItem.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A new SwiftData model for managing inventory items.
//

import Foundation
import SwiftData

/**
 InventoryItem is a comprehensive SwiftData model designed for robust inventory management within Furfolio. Architected with concurrency in mind, it leverages Swift's async/await capabilities to ensure thread-safe audit logging and data consistency. The model supports detailed audit trails and analytics readiness through structured audit entries managed by a dedicated actor, facilitating efficient diagnostics and historical tracking.

 Localization is integrated into audit entries to support internationalization, while accessibility features provide descriptive labels to enhance usability for assistive technologies. The model encapsulates detailed business logic for stock management, expiration monitoring, and reorder suggestions.

 For development and testing, a SwiftUI preview is included, demonstrating typical use cases and UI integration. This design ensures maintainability, scalability, and compliance with best practices for modern Swift application architectures.
 */

/// Represents a single trackable inventory item, such as a bottle of shampoo, a bag of treats, or a grooming tool.
@Model
final class InventoryItem: Identifiable, ObservableObject {
    // MARK: - Core Properties
    @Attribute(.unique) var id: UUID
    var name: String
    var sku: String?
    var notes: String?
    var category: ItemCategory
    var stockLevel: Int
    var lowStockThreshold: Int
    var cost: Double
    var price: Double?
    var lastUpdated: Date

    // MARK: - Enhancements
    var expirationDate: Date?
    var batchNumber: String?
    var tagTokens: [String]
    var averageMonthlyUsage: Int?
    var isArchived: Bool
    var isDiscontinued: Bool
    var pendingReorder: Bool
    var vendorName: String?
    var lotTraceURL: URL?
    var lastStockChangedBy: String?
    var lastStockChangeDate: Date?
    var lastNotificationType: String?

    // MARK: - Tag Tokenization
    enum InventoryTag: String, CaseIterable, Codable {
        case perishable, highValue, popular, localVendor, ecoFriendly, promo, sample, seasonal, discontinued
    }
    var tags: [InventoryTag] { tagTokens.compactMap { InventoryTag(rawValue: $0) } }
    func addTag(_ tag: InventoryTag) {
        if !tagTokens.contains(tag.rawValue) { tagTokens.append(tag.rawValue) }
    }
    func removeTag(_ tag: InventoryTag) {
        tagTokens.removeAll { $0 == tag.rawValue }
    }
    func hasTag(_ tag: InventoryTag) -> Bool {
        tagTokens.contains(tag.rawValue)
    }

    // MARK: - Business Intelligence
    @Attribute(.transient) var stockValue: Double { Double(stockLevel) * (price ?? 0) }
    @Attribute(.transient) var marginPercent: Double? {
        guard let price, price > 0 else { return nil }
        return (price - cost) / price * 100
    }
    @Attribute(.transient) var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        return Calendar.current.isDateInToday(expirationDate)
            || (expirationDate.timeIntervalSinceNow < 60*60*24*30 && expirationDate > Date())
    }
    @Attribute(.transient) var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }
    @Attribute(.transient) var suggestedReorderQuantity: Int {
        // Simple model: replenish up to 2x average usage (or threshold if unavailable)
        let avg = averageMonthlyUsage ?? lowStockThreshold
        return max(0, avg * 2 - stockLevel)
    }

    // MARK: - Stock and Audit Automation
    public func changeStock(by amount: Int, user: String? = nil, reason: String? = nil) async {
        let before = stockLevel
        stockLevel += amount
        lastStockChangedBy = user
        lastStockChangeDate = Date()
        lastUpdated = Date()
        let reasonText = reason != nil ? " (\(reason!))" : ""
        await addAudit("Stock changed from \(before) to \(stockLevel) by \(user ?? \"system\")\(reasonText)")
        if stockLevel <= lowStockThreshold && !pendingReorder {
            pendingReorder = true
            lastNotificationType = "LowStock"
        }
    }
    public func archiveItem() async {
        isArchived = true
        await addAudit("Item archived")
    }
    public func discontinueItem() async {
        isDiscontinued = true
        addTag(.discontinued)
        await addAudit("Item marked as discontinued")
    }

    // MARK: - Audit
    public func addAudit(_ entry: String) async {
        let tsEntry = NSLocalizedString(entry, comment: "Inventory audit log entry")
        let auditEntry = InventoryAuditEntry(id: UUID(), timestamp: Date(), entry: tsEntry)
        await InventoryAuditManager.shared.add(auditEntry)
        lastUpdated = Date()
    }
    public func recentAuditEntries(limit: Int = 3) async -> [InventoryAuditEntry] {
        await InventoryAuditManager.shared.recent(limit: limit)
    }
    public func exportAuditJSON() async -> String {
        await InventoryAuditManager.shared.exportJSON()
    }

    // MARK: - Export
    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID, name: String, sku: String?, notes: String?, category: String, stockLevel: Int, cost: Double, price: Double?, expirationDate: Date?, batchNumber: String?, tags: [String], isArchived: Bool, isDiscontinued: Bool, vendorName: String?, lotTraceURL: URL?
        }
        let export = Export(
            id: id, name: name, sku: sku, notes: notes, category: category.rawValue, stockLevel: stockLevel,
            cost: cost, price: price, expirationDate: expirationDate, batchNumber: batchNumber, tags: tagTokens,
            isArchived: isArchived, isDiscontinued: isDiscontinued, vendorName: vendorName, lotTraceURL: lotTraceURL
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Accessibility
    @Attribute(.transient) var accessibilityLabel: String {
        "Inventory item: \(name). Category: \(category.displayName). \(isInStock ? "In stock: \(stockLevel)." : "Out of stock.") \(isDiscontinued ? "Discontinued." : "") \(isArchived ? "Archived." : "")"
    }

    // MARK: - Computed
    @Attribute(.transient) var isInStock: Bool { !isArchived && stockLevel > 0 }
    @Attribute(.transient) var isLowStock: Bool { isInStock && stockLevel <= lowStockThreshold }

    // MARK: - Initializer
    init(
        id: UUID = UUID(), name: String, sku: String? = nil, notes: String? = nil, category: ItemCategory = .supplies,
        stockLevel: Int = 0, lowStockThreshold: Int = 5, cost: Double = 0.0, price: Double? = nil, lastUpdated: Date = Date(),
        expirationDate: Date? = nil, batchNumber: String? = nil, tagTokens: [String] = [],
        averageMonthlyUsage: Int? = nil, isArchived: Bool = false, isDiscontinued: Bool = false, pendingReorder: Bool = false,
        vendorName: String? = nil, lotTraceURL: URL? = nil, lastStockChangedBy: String? = nil, lastStockChangeDate: Date? = nil,
        lastNotificationType: String? = nil
    ) {
        self.id = id; self.name = name; self.sku = sku; self.notes = notes; self.category = category; self.stockLevel = stockLevel
        self.lowStockThreshold = lowStockThreshold; self.cost = cost; self.price = price; self.lastUpdated = lastUpdated
        self.expirationDate = expirationDate; self.batchNumber = batchNumber; self.tagTokens = tagTokens
        self.averageMonthlyUsage = averageMonthlyUsage; self.isArchived = isArchived; self.isDiscontinued = isDiscontinued
        self.pendingReorder = pendingReorder; self.vendorName = vendorName; self.lotTraceURL = lotTraceURL
        self.lastStockChangedBy = lastStockChangedBy; self.lastStockChangeDate = lastStockChangeDate
        self.lastNotificationType = lastNotificationType
    }
}

// MARK: - Audit Entry and Manager

@Model public struct InventoryAuditEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    let timestamp: Date
    let entry: String
}

actor InventoryAuditManager {
    private var buffer: [InventoryAuditEntry] = []
    let maxEntries = 100
    static let shared = InventoryAuditManager()

    func add(_ entry: InventoryAuditEntry) async {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    func recent(limit: Int) async -> [InventoryAuditEntry] {
        Array(buffer.suffix(limit))
    }

    func exportJSON() async -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(buffer) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct InventoryItem_Previews: PreviewProvider {
    static var previews: some View {
        // This preview demonstrates how the model could be used in a view.
        // In a real implementation, you would create an InventoryListView.
        VStack(alignment: .leading, spacing: 16) {
            Text("Sample Inventory Items")
                .font(.title)

            let lowStockItem = InventoryItem(
                name: "Lavender Shampoo (16oz)",
                sku: "SHMP-LAV-16",
                category: .supplies,
                stockLevel: 3,
                lowStockThreshold: 5,
                cost: 8.50,
                price: 24.99
            )
            
            let inStockItem = InventoryItem(
                name: "Standard Steel Comb",
                category: .tools,
                stockLevel: 12,
                lowStockThreshold: 2,
                cost: 15.00
            )
            
            // Example of how you might display an item
            HStack {
                VStack(alignment: .leading) {
                    Text(lowStockItem.name)
                        .font(.headline)
                    Text("In Stock: \(lowStockItem.stockLevel)")
                        .font(.body)
                }
                Spacer()
                if lowStockItem.isLowStock {
                    Text("Low Stock")
                        .font(.caption.bold())
                        .padding(6)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

        }
        .padding()
    }
}
#endif
