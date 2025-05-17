//  InventoryDashboardView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 15, 2025 — initial scaffold with stats & lists.
//

import SwiftUI
import SwiftData
// TODO: Move dashboard logic into a dedicated ViewModel and cache formatters for performance

@MainActor
/// Dashboard for displaying inventory overview: summary, low-stock alerts, top-value items, and full list.
struct InventoryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    /// Shared NumberFormatter for currency values to avoid repeated allocations.
    private static let currencyFormatter = NumberFormatter.currency
    
    // Fetch all items, sorted by name
    @Query(sort: \.name, order: .forward) private var allItems: [InventoryItem]
    
    /// Items with stock at or below the reorder threshold.
    private var lowStockItems: [InventoryItem] {
        allItems.filter(\.isLowStock)
    }
    /// Top five inventory items sorted by total value.
    private var topValueItems: [InventoryItem] {
        Array(allItems
            .sorted { $0.totalValue > $1.totalValue }
            .prefix(5)
        )
    }
    
    /// Combined total value of all inventory items.
    private var totalValue: Double {
        allItems.reduce(0) { $0 + $1.totalValue }
    }
    /// Total count of inventory items.
    private var totalItemsCount: Int {
        allItems.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: Summary
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total Items")
                        Spacer()
                        Text("\(totalItemsCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Inventory Value")
                        Spacer()
                        Text(Self.currencyFormatter.string(from: NSNumber(value: totalValue)) ?? "")
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: Low Stock
                if !lowStockItems.isEmpty {
                    Section(header: Text("Low Stock")) {
                        ForEach(lowStockItems) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantityOnHand)")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // MARK: Top Value
                Section(header: Text("Top Value Items")) {
                    ForEach(topValueItems) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(Self.currencyFormatter.string(from: NSNumber(value: item.totalValue)) ?? "")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // MARK: All Items
                Section(header: Text("All Inventory")) {
                    ForEach(allItems) { item in
                        InventoryRow(item: item)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Inventory Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@MainActor
/// Row view displaying the name, quantity, and sell price of an inventory item.
private struct InventoryRow: View {
    @ObservedObject var item: InventoryItem
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text("\(item.quantityOnHand)")
                .frame(minWidth: 40)
            Text(Self.currencyFormatter.string(from: NSNumber(value: item.sellPrice)) ?? "")
                .frame(minWidth: 60, alignment: .trailing)
        }
        .font(.subheadline)
    }
}

// MARK: — Helpers

private extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()
}

#if DEBUG
struct InventoryDashboardView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [InventoryItem.self],
            modelConfiguration: config
        )
    }()
    
    static var previews: some View {
        // Insert some sample items
        let ctx = container.mainContext
        InventoryItem.create(name: "Shampoo", quantityOnHand: 3, reorderThreshold: 5, costPrice: 4.5, sellPrice: 9.99, in: ctx)
        InventoryItem.create(name: "Brush", quantityOnHand: 12, reorderThreshold: 5, costPrice: 2.0, sellPrice: 5.0, in: ctx)
        InventoryItem.create(name: "Conditioner", quantityOnHand: 2, reorderThreshold: 5, costPrice: 5.0, sellPrice: 11.0, in: ctx)
        
        return InventoryDashboardView()
            .environment(\.modelContext, ctx)
    }
}
#endif
