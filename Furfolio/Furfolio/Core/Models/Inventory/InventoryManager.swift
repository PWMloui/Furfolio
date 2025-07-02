//
//  InventoryManager.swift
//  Furfolio
//
//  Enhanced: Adds audit logging, notification hooks, predictive restock, and robust handling of discontinued/archived items.
//

/**
 InventoryManager
 ----------------
 Manages inventory operations including stock usage, receipt, automated task generation, and analytics/audit logging for Furfolio.
 
 - **Architecture**: Follows MVVM with @MainActor and ObservableObject for UI binding.
 - **Concurrency**: Uses async/await for data store operations and audit logging, ensuring thread safety.
 - **Audit Logging**: All stock changes and task creations are recorded via a centralized async audit manager.
 - **Notifications**: Low stock events trigger notification hooks for user alerts.
 - **Predictive Restock**: Stub for future ML-powered forecasting.
 - **Localization**: All user-facing strings are wrapped in NSLocalizedString for i18n.
 - **Accessibility**: Exposes localized accessibility labels for key UI metrics.
 - **Preview/Testability**: SwiftUI preview demonstrates core features with in-memory data store.
 */

/// Represents an audit entry for inventory actions.
@Model public struct InventoryManagerAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let action: String
    public let itemID: UUID
}

/// Actor to manage concurrency-safe audit logging.
public actor InventoryManagerAuditLog {
    private var buffer: [InventoryManagerAuditEntry] = []
    let maxEntries = 500
    public static let shared = InventoryManagerAuditLog()
    
    /// Append a new audit entry, capping buffer size.
    public func add(_ entry: InventoryManagerAuditEntry) {
      buffer.append(entry)
      if buffer.count > maxEntries {
        buffer.removeFirst(buffer.count - maxEntries)
      }
    }
    
    /// Retrieve recent audit entries.
    public func recent(limit: Int = 20) -> [InventoryManagerAuditEntry] {
      Array(buffer.suffix(limit))
    }
    
    /// Export audit log as JSON.
    public func exportJSON() -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      encoder.dateEncodingStrategy = .iso8601
      guard let data = try? encoder.encode(buffer),
            let json = String(data: data, encoding: .utf8)
      else { return "[]" }
      return json
    }
}

import Foundation
import SwiftData

@MainActor
final class InventoryManager: ObservableObject {
    @Published private(set) var lowStockItemCount: Int = 0
    private let dataStore: DataStoreService

    // For audit logs
    private func addAudit(for item: InventoryItem, action: String, user: String? = nil) async {
        let userText = user ?? NSLocalizedString("system", comment: "System user for audit")
        let entryText = String(
          format: NSLocalizedString("Audit [%@] %@ by %@", comment: "Audit log entry format: date, action, user"),
          DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short),
          NSLocalizedString(action, comment: "Audit action description"),
          userText
        )
        let auditEntry = InventoryManagerAuditEntry(
          id: UUID(),
          timestamp: Date(),
          action: entryText,
          itemID: item.id
        )
        await InventoryManagerAuditLog.shared.add(auditEntry)
        item.lastUpdated = Date()
    }

    // Notification stub: Call your app’s notification service here.
    private func notifyLowStock(for item: InventoryItem) {
        // e.g., NotificationCenter.default.post(name: .inventoryLowStock, object: item)
        print(String(format: NSLocalizedString("Notify: Low stock alert for %@", comment: "Notify low stock"), item.name))
    }

    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
    }

    // MARK: - Core Inventory Operations

    /// Decrements stock, logs audit, and triggers notification/task if needed.
    func useStock(for itemID: UUID, quantity: Int = 1, user: String? = nil) async {
        guard let item = await dataStore.fetchByID(InventoryItem.self, id: itemID) else {
            print(String(format: NSLocalizedString("InventoryManager Error: Could not find item with ID %@", comment: "InventoryManager error missing item"), "\(itemID)"))
            return
        }
        guard !item.isArchived && !item.isDiscontinued else {
            print(String(format: NSLocalizedString("InventoryManager: Item %@ is archived/discontinued. No stock change.", comment: "Archived/discontinued item"), item.name))
            return
        }
        guard item.stockLevel >= quantity else {
            print(String(format: NSLocalizedString("InventoryManager Warning: Attempted to use more stock than available for %@. Setting to 0.", comment: "Stock depleted to zero"), item.name))
            item.stockLevel = 0
            await addAudit(for: item, action: "Stock depleted to 0", user: user)
            return
        }
        item.stockLevel -= quantity
        await addAudit(for: item, action: "Used \(quantity) unit(s). New stock: \(item.stockLevel)", user: user)
        await checkForLowStockAndCreateTask(for: item)
        await updateLowStockCount()
    }
    
    /// Increments stock, logs audit, resets reorder/pending flag if needed.
    func receiveStock(for itemID: UUID, quantity: Int, user: String? = nil) async {
        guard let item = await dataStore.fetchByID(InventoryItem.self, id: itemID) else { return }
        item.stockLevel += quantity
        item.pendingReorder = false
        await addAudit(for: item, action: "Received \(quantity) unit(s). New stock: \(item.stockLevel)", user: user)
        await updateLowStockCount()
    }

    // MARK: - Automated Task Generation

    /// Create a reorder task if low, not already open, and not archived/discontinued.
    private func checkForLowStockAndCreateTask(for item: InventoryItem) async {
        guard item.isLowStock && !item.isArchived && !item.isDiscontinued else { return }
        let taskTitle = "Re-order: \(item.name)"
        let existingTasks = await dataStore.fetchAll(Task.self)
        let hasOpenTask = existingTasks.contains { $0.title == taskTitle && !$0.completed }
        if !hasOpenTask {
            let reorderQty = item.suggestedReorderQuantity
            let newTask = Task(
                title: taskTitle,
                details: "Stock is at \(item.stockLevel). Threshold is \(item.lowStockThreshold). Suggested reorder: \(reorderQty).",
                priority: .medium
            )
            await dataStore.insert(newTask)
            await addAudit(for: item, action: "Created reorder task for \(reorderQty) units")
            notifyLowStock(for: item)
            item.pendingReorder = true
        }
    }

    /// Updates the published count of all items that are low on stock, not archived/discontinued.
    func updateLowStockCount() async {
        let allItems = await dataStore.fetchAll(InventoryItem.self)
        let lowStockItems = allItems.filter { $0.isLowStock && !$0.isArchived && !$0.isDiscontinued }
        self.lowStockItemCount = lowStockItems.count
    }

    // MARK: - Bulk & Predictive Operations

    /// Check all inventory for low stock and generate tasks/notifications in batch.
    func batchCheckLowStock() async {
        let allItems = await dataStore.fetchAll(InventoryItem.self)
        for item in allItems where item.isLowStock && !item.isArchived && !item.isDiscontinued {
            await checkForLowStockAndCreateTask(for: item)
        }
        await updateLowStockCount()
    }

    /// Predictive restock stub: Ready for ML-driven forecasting in the future.
    func predictRestockNeeds() async -> [(item: InventoryItem, suggestedQty: Int)] {
        let allItems = await dataStore.fetchAll(InventoryItem.self)
        // In future: use AI to predict quantity.
        return allItems
            .filter { $0.isLowStock && !$0.isArchived && !$0.isDiscontinued }
            .map { ($0, $0.suggestedReorderQuantity) }
    }

    // MARK: - Accessibility (example for badge)
    var lowStockAccessibilityLabel: String {
        NSLocalizedString("There are \(lowStockItemCount) items low on stock", comment: "Low stock accessibility label")
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
