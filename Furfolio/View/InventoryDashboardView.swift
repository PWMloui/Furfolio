//  InventoryDashboardView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 15, 2025 — initial scaffold with stats & lists.
//

import SwiftUI
import SwiftData
import os
import Services
// TODO: Move dashboard logic into a dedicated ViewModel and cache formatters for performance

@MainActor
/// Dashboard for displaying inventory overview: summary, low-stock alerts, top-value items, and full list.
struct InventoryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = InventoryDashboardViewModel()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "InventoryDashboardView")
    
    /// Shared NumberFormatter for currency values to avoid repeated allocations.
    private static let currencyFormatter = NumberFormatter.currency
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: Summary
                Section(header: Text("Summary")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ) {
                    HStack {
                        Text("Total Items")
                        Spacer()
                        Text("\(viewModel.totalItemsCount)")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    HStack {
                        Text("Inventory Value")
                        Spacer()
                        Text(Self.currencyFormatter.string(from: NSNumber(value: viewModel.totalValue)) ?? "")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                // MARK: Low Stock
                if !viewModel.lowStockItems.isEmpty {
                    Section(header: Text("Low Stock")
                        .font(AppTheme.title)
                        .foregroundColor(AppTheme.primaryText)
                    ) {
                        ForEach(viewModel.lowStockItems) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantityOnHand)")
                                    .font(AppTheme.body)
                                    .foregroundColor(AppTheme.warning)
                            }
                        }
                    }
                    .onAppear {
                        logger.log("Displaying Low Stock section with \(viewModel.lowStockItems.count) items")
                    }
                }
                
                // MARK: Top Value
                Section(header: Text("Top Value Items")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ) {
                    ForEach(viewModel.topValueItems) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(Self.currencyFormatter.string(from: NSNumber(value: item.totalValue)) ?? "")
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
                .onAppear {
                    logger.log("Displaying Top Value section with \(viewModel.topValueItems.count) items")
                }
                
                // MARK: All Items
                Section(header: Text("All Inventory")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ) {
                    ForEach(viewModel.allItems) { item in
                        InventoryRow(item: item)
                    }
                }
                .onAppear {
                    logger.log("Displaying All Inventory with \(viewModel.allItems.count) items")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Inventory Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                logger.log("InventoryDashboardView appeared; totalItems=\(viewModel.totalItemsCount), lowStockCount=\(viewModel.lowStockItems.count)")
            }
        }
        .onAppear {
            viewModel.loadItems(context: modelContext)
        }
    }
}

@MainActor
/// Row view displaying the name, quantity, and sell price of an inventory item.
private struct InventoryRow: View {
    @ObservedObject var item: InventoryItem
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "InventoryRow")
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text("\(item.quantityOnHand)")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
                .frame(minWidth: 40)
            Text(Self.currencyFormatter.string(from: NSNumber(value: item.sellPrice)) ?? "")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .font(AppTheme.body)
        .foregroundColor(AppTheme.primaryText)
        .onAppear {
            logger.log("InventoryRow appeared for item id: \(item.id), quantityOnHand: \(item.quantityOnHand)")
        }
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
