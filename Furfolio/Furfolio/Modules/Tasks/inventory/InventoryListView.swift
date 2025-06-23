//
//  InventoryListView.swift
//  Furfolio
//
//  Created by Your Name on 6/22/25.
//
//  This view is fully modular, tokenized, and auditable, aligning with the
//  Furfolio application's architecture. It displays a list of all inventory items,
//  provides at-a-glance status, and allows for easy management.
//

import SwiftUI
import SwiftData

/// A view that displays a searchable and filterable list of all inventory items.
/// It integrates with the `InventoryManager` to show stock levels and provides
/// functionality to add, view details of, and delete items.
struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    
    // The manager holds the logic and summary data like the low stock count.
    @StateObject private var inventoryManager = InventoryManager()

    // Fetches all inventory items from SwiftData, sorted by name.
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    
    // State for the search text and sheet presentation.
    @State private var searchText: String = ""
    @State private var showingAddItemSheet = false

    /// A computed property that filters the inventory based on the search text.
    private var filteredItems: [InventoryItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.sku ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Summary Header
                summaryHeader
                
                // MARK: - Inventory List
                List {
                    if filteredItems.isEmpty {
                        // Show an empty state view if there are no items.
                        ContentUnavailableView(
                            "No Inventory Items",
                            systemImage: "shippingbox.fill",
                            description: Text("Tap the plus button to add your first inventory item.")
                        )
                    } else {
                        ForEach(filteredItems) { item in
                            // Each item is a navigation link to its detail view.
                            // NOTE: InventoryItemDetailView would need to be created.
                            NavigationLink(destination: Text("Detail View for \(item.name)")) {
                                InventoryRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search by name or SKU")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItemSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new inventory item")
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                // Presents the AddInventoryItemView created previously.
                AddInventoryItemView()
                    .environment(\.modelContext, modelContext)
            }
            .task {
                // Update the low stock count when the view appears.
                await inventoryManager.updateLowStockCount()
            }
        }
    }

    /// A header view that displays summary statistics about the inventory.
    private var summaryHeader: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            KPIStatCard(
                title: "Total Items",
                value: "\(items.count)",
                subtitle: "Unique products tracked",
                systemIconName: "shippingbox.circle.fill",
                iconBackgroundColor: AppTheme.Colors.primary
            )
            
            KPIStatCard(
                title: "Low Stock",
                value: "\(inventoryManager.lowStockItemCount)",
                subtitle: "Items needing re-order",
                systemIconName: "exclamationmark.triangle.fill",
                iconBackgroundColor: inventoryManager.lowStockItemCount > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success
            )
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
    }
    
    /// Deletes items from the model context at the specified offsets.
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = filteredItems[index]
            modelContext.delete(itemToDelete)
            // TODO: Add an audit log entry for item deletion.
        }
        Task {
            // Re-calculate the low stock count after deletion.
            await inventoryManager.updateLowStockCount()
        }
    }
}

/// A reusable view for displaying a single inventory item in a list row.
private struct InventoryRowView: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            // MARK: Icon
            Image(systemName: item.category.iconName) // Assumes ItemCategory has an iconName property
                .font(.title2)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 40, height: 40)
            
            // MARK: Name and Category
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(item.name)
                    .font(AppTheme.Fonts.headline)
                
                Text(item.category.displayName)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // MARK: Stock Level and Status
            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                Text("\(item.stockLevel)")
                    .font(AppTheme.Fonts.headline.monospacedDigit())
                
                if item.isLowStock {
                    Text("LOW STOCK")
                        .font(AppTheme.Fonts.caption.weight(.bold))
                        .foregroundColor(AppTheme.Colors.warning)
                }
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, AppTheme.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), category \(item.category.displayName), quantity \(item.stockLevel). \(item.isLowStock ? "Low stock." : "")")
    }
}

// Add an icon property to the ItemCategory enum for use in the UI
fileprivate extension ItemCategory {
    var iconName: String {
        switch self {
        case .supplies:
            return "drop.fill"
        case .tools:
            return "wrench.and.screwdriver.fill"
        case .retail:
            return "tag.fill"
        case .miscellaneous:
            return "questionmark.diamond.fill"
        }
    }
}


// MARK: - SwiftUI Preview

#Preview {
    // This preview sets up an in-memory SwiftData container
    // and populates it with sample data to test the view.
    let container: ModelContainer = {
        let schema = Schema([InventoryItem.self, Task.self]) // Task is included because InventoryManager can create tasks
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    // Add sample data to the context
    let shampoo = InventoryItem(name: "Oatmeal Shampoo", category: .supplies, stockLevel: 3, lowStockThreshold: 5, cost: 8.50)
    let clippers = InventoryItem(name: "Cordless Clippers", category: .tools, stockLevel: 2, lowStockThreshold: 1, cost: 150.00)
    let treats = InventoryItem(name: "Organic Dog Treats", category: .retail, stockLevel: 25, lowStockThreshold: 10, cost: 2.00, price: 5.99)
    
    container.mainContext.insert(shampoo)
    container.mainContext.insert(clippers)
    container.mainContext.insert(treats)
    
    return InventoryListView()
        .modelContainer(container)
}
