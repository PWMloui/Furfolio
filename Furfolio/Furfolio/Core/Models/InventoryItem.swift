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

/// Represents a single trackable inventory item, such as a bottle of shampoo, a bag of treats, or a grooming tool.
@Model
final class InventoryItem: Identifiable, ObservableObject {
    
    /// Unique identifier for the inventory item.
    @Attribute(.unique)
    var id: UUID

    /// The name of the product (e.g., "Hypoallergenic Oatmeal Shampoo").
    var name: String

    /// Stock Keeping Unit (SKU) or product code for easy tracking.
    var sku: String?

    /// A detailed description of the item.
    var notes: String?

    /// The category this item belongs to.
    var category: ItemCategory

    /// The current number of units in stock.
    var stockLevel: Int

    /// The stock level at which a re-order reminder should be triggered.
    var lowStockThreshold: Int

    /// The cost to the business to purchase one unit of this item.
    var cost: Double

    /// The price the business charges a client for one unit of this item (if for sale).
    var price: Double?
    
    /// The date this item was last updated.
    var lastUpdated: Date

    // MARK: - Relationships
    
    /// An optional relationship to a `Vendor` model for tracking suppliers.
    // @Relationship(deleteRule: .nullify)
    // var vendor: Vendor?

    // MARK: - Computed Properties

    /// A boolean indicating if the item is currently in stock.
    var isInStock: Bool {
        stockLevel > 0
    }

    /// A boolean indicating if the stock level has fallen to or below the low stock threshold.
    var isLowStock: Bool {
        isInStock && stockLevel <= lowStockThreshold
    }

    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        name: String,
        sku: String? = nil,
        notes: String? = nil,
        category: ItemCategory = .supplies,
        stockLevel: Int = 0,
        lowStockThreshold: Int = 5,
        cost: Double = 0.0,
        price: Double? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sku = sku
        self.notes = notes
        self.category = category
        self.stockLevel = stockLevel
        self.lowStockThreshold = lowStockThreshold
        self.cost = cost
        self.price = price
        self.lastUpdated = lastUpdated
    }
}

/// Defines the category for an inventory item.
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case supplies
    case tools
    case retail
    case miscellaneous

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .supplies: "Grooming Supplies"
        case .tools: "Tools & Equipment"
        case .retail: "Retail Products"
        case .miscellaneous: "Miscellaneous"
        }
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
