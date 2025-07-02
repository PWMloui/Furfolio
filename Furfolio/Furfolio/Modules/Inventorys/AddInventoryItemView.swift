//
//  AddInventoryItemView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Inventory Add View
//

import SwiftUI
import SwiftData

struct AddInventoryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // State variables for the form fields
    @State private var name: String = ""
    @State private var sku: String = ""
    @State private var notes: String = ""
    @State private var category: ItemCategory = .supplies
    @State private var stockLevel: Int = 0
    @State private var lowStockThreshold: Int = 5
    @State private var costString: String = ""
    @State private var priceString: String = ""

    // Feedback states
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccess = false
    @State private var animateBadge = false
    @State private var showAuditLog = false

    /// A computed property to check if the form is valid and the save button can be enabled.
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !costString.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(costString) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Item Details Section
                Section(header: Text("Item Details").font(AppTheme.Fonts.headline)) {
                    TextField("Item Name (e.g., Oatmeal Shampoo)", text: $name)
                        .accessibilityIdentifier("itemNameField")
                    
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .accessibilityIdentifier("itemCategoryPicker")
                    
                    TextField("SKU or Product Code (Optional)", text: $sku)
                        .accessibilityIdentifier("itemSkuField")
                }
                
                // MARK: - Stock & Pricing Section
                Section(header: Text("Stock & Pricing").font(AppTheme.Fonts.headline)) {
                    StepperInputView(label: "Current Stock", value: $stockLevel, range: 0...1000)
                        .accessibilityIdentifier("itemStockLevelStepper")

                    StepperInputView(label: "Low Stock Alert At", value: $lowStockThreshold, range: 0...1000)
                        .accessibilityIdentifier("itemLowStockStepper")
                    
                    HStack {
                        Text("Cost Per Item")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        TextField("0.00", text: $costString)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("itemCostField")
                    }
                    
                    HStack {
                        Text("Retail Price (Optional)")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        TextField("0.00", text: $priceString)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("itemPriceField")
                    }
                }
                
                // MARK: - Notes Section
                Section(header: Text("Notes").font(AppTheme.Fonts.headline)) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("itemNotesEditor")
                }
            }
            .navigationTitle("Add Inventory Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveItem()
                    } label: {
                        ZStack {
                            if animateBadge {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.19))
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(1.11)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.54), value: animateBadge)
                            }
                            Text("Save")
                        }
                    }
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("addInventorySaveButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("addInventoryAuditLogButton")
                }
            }
            .alert("Invalid Input", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
                    .accessibilityIdentifier("addInventoryInvalidInputMessage")
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Inventory item added successfully.")
                    .accessibilityIdentifier("addInventorySuccessMessage")
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(InventoryAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Inventory Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = InventoryAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("addInventoryCopyAuditLogButton")
                        }
                    }
                }
            }
        }
    }
    
    /// Validates the form input and saves the new inventory item to the model context.
    private func saveItem() {
        guard let cost = Double(costString) else {
            alertMessage = "Please enter a valid number for the item cost."
            showAlert = true
            InventoryAudit.record(action: "AddFailed", detail: "Invalid cost")
            return
        }
        // Check for duplicate name in current context
        let duplicate = (try? modelContext.fetch(FetchDescriptor<InventoryItem>(predicate: #Predicate { $0.name == name }))).map { !$0.isEmpty } ?? false
        if duplicate {
            alertMessage = "An inventory item with this name already exists."
            showAlert = true
            InventoryAudit.record(action: "AddFailed", detail: "Duplicate name: \(name)")
            return
        }
        let price = Double(priceString)
        let newItem = InventoryItem(
            name: name,
            sku: sku.isEmpty ? nil : sku,
            notes: notes.isEmpty ? nil : notes,
            category: category,
            stockLevel: stockLevel,
            lowStockThreshold: lowStockThreshold,
            cost: cost,
            price: price
        )
        modelContext.insert(newItem)
        InventoryAudit.record(action: "Add", detail: "\(name), SKU=\(sku), Cat=\(category.displayName), Stock=\(stockLevel), Cost=\(cost)")
        animateBadge = true
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateBadge = false }
    }
}

// MARK: - Inventory Audit/Event Logging

fileprivate struct InventoryAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[AddInventoryItem] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class InventoryAudit {
    static private(set) var log: [InventoryAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = InventoryAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum InventoryAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { InventoryAudit.recentSummaries(limit: limit) }
}

// MARK: - SwiftUI Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: InventoryItem.self, configurations: config)
    return AddInventoryItemView()
        .modelContainer(container)
}
