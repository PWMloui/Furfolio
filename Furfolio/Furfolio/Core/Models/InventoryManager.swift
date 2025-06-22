//
//  InventoryManager.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A service to manage inventory levels, track stock,
//  and automate re-order tasks.
//

import Foundation
import SwiftData

/// Manages all business logic related to inventory, including stock levels and re-order tasks.
/// This service is designed to be a singleton managed by the DependencyContainer.
@MainActor
final class InventoryManager: ObservableObject {

    /// A published property that the UI can observe to display a badge for low-stock items.
    @Published private(set) var lowStockItemCount: Int = 0

    // Dependencies are injected for testability.
    private let dataStore: DataStoreService

    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
    }

    // MARK: - Core Inventory Operations

    /// Decrements the stock for a specific item, typically after it's used in a GroomingSession.
    /// - Parameters:
    ///   - itemID: The unique ID of the `InventoryItem` to update.
    ///   - quantity: The number of units to decrement. Defaults to 1.
    func useStock(for itemID: UUID, quantity: Int = 1) async {
        guard let item = await dataStore.fetchByID(InventoryItem.self, id: itemID) else {
            print("InventoryManager Error: Could not find item with ID \(itemID)")
            return
        }
        
        guard item.stockLevel >= quantity else {
            print("InventoryManager Warning: Attempted to use more stock than available for \(item.name). Setting to 0.")
            item.stockLevel = 0
            return
        }
        
        item.stockLevel -= quantity
        item.lastUpdated = Date()
        
        // After updating, check if a re-order task is now needed.
        await checkForLowStockAndCreateTask(for: item)
        await updateLowStockCount()
    }
    
    /// Increments the stock for a specific item, e.g., when a new shipment arrives.
    /// - Parameters:
    ///   - itemID: The unique ID of the `InventoryItem` to update.
    ///   - quantity: The number of units to add.
    func receiveStock(for itemID: UUID, quantity: Int) async {
        guard let item = await dataStore.fetchByID(InventoryItem.self, id: itemID) else { return }
        item.stockLevel += quantity
        item.lastUpdated = Date()
        
        // After receiving stock, re-evaluate the low stock count for the UI badge.
        await updateLowStockCount()
    }
    
    // MARK: - Automated Task Generation

    /// Checks a specific item and creates a "Re-order" task if it's low on stock and no open task already exists.
    /// - Parameter item: The `InventoryItem` to check.
    private func checkForLowStockAndCreateTask(for item: InventoryItem) async {
        guard item.isLowStock else { return }
        
        // Check if an open task for this item already exists to prevent duplicates.
        let taskTitle = "Re-order: \(item.name)"
        let existingTasks = await dataStore.fetchAll(Task.self)
        let hasOpenTask = existingTasks.contains { $0.title == taskTitle && !$0.completed }
        
        if !hasOpenTask {
            let newTask = Task(
                title: taskTitle,
                details: "Stock is at \(item.stockLevel). Low stock threshold is \(item.lowStockThreshold).",
                priority: .medium
                // Optionally link to a Vendor model if implemented
            )
            await dataStore.insert(newTask)
            print("InventoryManager: Created new task to re-order \(item.name).")
        }
    }

    /// Recalculates and updates the published count of all items that are low on stock.
    func updateLowStockCount() async {
        let allItems = await dataStore.fetchAll(InventoryItem.self)
        let lowStockItems = allItems.filter { $0.isLowStock }
        self.lowStockItemCount = lowStockItems.count
    }
}


// MARK: - Preview
#if DEBUG
import SwiftUI

struct InventoryManager_Preview: View {
    // In a real view, this would be injected via the environment.
    @StateObject private var manager = InventoryManager(dataStore: .shared)
    @State private var sampleItem = InventoryItem(name: "Oatmeal Shampoo", stockLevel: 6, lowStockThreshold: 5)
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Inventory Manager Demo")
                .font(.title)

            Text("Item: \(sampleItem.name)")
                .font(.headline)
            
            Text("Stock Level: \(sampleItem.stockLevel)")
            
            if sampleItem.isLowStock {
                Text("Status: LOW STOCK")
                    .foregroundColor(.orange)
            } else {
                Text("Status: In Stock")
                    .foregroundColor(.green)
            }
            
            HStack {
                Button("Use 1") {
                    sampleItem.stockLevel -= 1
                    Task {
                        // In a real app, the manager would check for and create a task if needed.
                        await manager.checkForLowStockAndCreateTask(for: sampleItem)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Receive 5") {
                    sampleItem.stockLevel += 5
                }
                .buttonStyle(.bordered)
            }
            
            Text("Low Stock Items: \(manager.lowStockItemCount)")
                .padding()
                .background(.regularMaterial)
                .cornerRadius(10)
        }
        .padding()
        .task {
            // Populate context with sample item for preview
            await manager.dataStore.insert(sampleItem)
            await manager.updateLowStockCount()
        }
    }
}

#Preview {
    InventoryManager_Preview()
        // Provide an in-memory data store for the preview
        .modelContainer(for: [InventoryItem.self, Task.self], inMemory: true)
}
#endif
