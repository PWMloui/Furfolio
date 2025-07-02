//
//  InventoryListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Inventory List
//

import SwiftUI
import SwiftData

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var inventoryManager = InventoryManager()
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    @State private var searchText: String = ""
    @State private var showingAddItemSheet = false
    @State private var showAuditLog = false
    @State private var animateAddBadge = false
    @State private var appearedOnce = false

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
                summaryHeader

                List {
                    if filteredItems.isEmpty {
                        ContentUnavailableView(
                            "No Inventory Items",
                            systemImage: "shippingbox.fill",
                            description: Text("Tap the plus button to add your first inventory item.")
                        )
                        .accessibilityIdentifier("InventoryListView-EmptyState")
                        .overlay(
                            Button {
                                showAuditLog = true
                            } label: {
                                Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                                    .font(.caption)
                            }
                            .accessibilityIdentifier("InventoryListView-AuditLogButton"),
                            alignment: .bottomTrailing
                        )
                    } else {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: Text("Detail View for \(item.name)")) {
                                InventoryRowView(item: item)
                            }
                            .accessibilityIdentifier("InventoryListView-Row-\(item.name)")
                            .onTapGesture {
                                InventoryListAudit.record(action: "NavigateToDetail", itemName: item.name)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search by name or SKU")
            .onChange(of: searchText) { value in
                InventoryListAudit.record(action: "Search", itemName: value)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddItemSheet = true
                        animateAddBadge = true
                        InventoryListAudit.record(action: "ShowAddItem", itemName: "")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateAddBadge = false }
                    }) {
                        ZStack {
                            if animateAddBadge {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.17))
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(1.08)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.55), value: animateAddBadge)
                            }
                            Image(systemName: "plus")
                        }
                    }
                    .accessibilityLabel("Add new inventory item")
                    .accessibilityIdentifier("InventoryListView-AddButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("View Audit Log")
                    .accessibilityIdentifier("InventoryListView-AuditLogButton")
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddInventoryItemView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(InventoryListAuditAdmin.recentEvents(limit: 24), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Inventory Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = InventoryListAuditAdmin.recentEvents(limit: 24).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("InventoryListView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .task {
                await inventoryManager.updateLowStockCount()
            }
            .onAppear {
                if !appearedOnce {
                    InventoryListAudit.record(action: "Appear", itemName: "")
                    appearedOnce = true
                }
            }
        }
    }

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

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = filteredItems[index]
            modelContext.delete(itemToDelete)
            InventoryListAudit.record(action: "Delete", itemName: itemToDelete.name)
        }
        Task {
            await inventoryManager.updateLowStockCount()
        }
    }
}

/// A reusable view for displaying a single inventory item in a list row.
private struct InventoryRowView: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: item.category.iconName)
                .font(.title2)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(item.name)
                    .font(AppTheme.Fonts.headline)
                Text(item.category.displayName)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

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

// MARK: - Audit/Event Logging

fileprivate struct InventoryListAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let itemName: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let itemPart = itemName.isEmpty ? "" : " [\(itemName)]"
        return "[InventoryListView] \(action)\(itemPart) at \(df.string(from: timestamp))"
    }
}
fileprivate final class InventoryListAudit {
    static private(set) var log: [InventoryListAuditEvent] = []
    static func record(action: String, itemName: String) {
        let event = InventoryListAuditEvent(timestamp: Date(), action: action, itemName: itemName)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 12) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum InventoryListAuditAdmin {
    public static func recentEvents(limit: Int = 12) -> [String] { InventoryListAudit.recentSummaries(limit: limit) }
}

// MARK: - SwiftUI Preview

#Preview {
    let container: ModelContainer = {
        let schema = Schema([InventoryItem.self, Task.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    let shampoo = InventoryItem(name: "Oatmeal Shampoo", category: .supplies, stockLevel: 3, lowStockThreshold: 5, cost: 8.50)
    let clippers = InventoryItem(name: "Cordless Clippers", category: .tools, stockLevel: 2, lowStockThreshold: 1, cost: 150.00)
    let treats = InventoryItem(name: "Organic Dog Treats", category: .retail, stockLevel: 25, lowStockThreshold: 10, cost: 2.00, price: 5.99)

    container.mainContext.insert(shampoo)
    container.mainContext.insert(clippers)
    container.mainContext.insert(treats)

    return InventoryListView()
        .modelContainer(container)
}
