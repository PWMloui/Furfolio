//
//  AddInventoryItemView.swift
//  Furfolio
//
//  Created by Your Name on 6/22/25.
//
//  This view is fully modular, tokenized, and auditable, aligning with the
//  Furfolio application's architecture. It provides a form for adding new
//  inventory items to the data store.
//

import SwiftUI
import SwiftData

/// A view that presents a form to add a new `InventoryItem`.
/// It uses design system tokens for styling and provides input validation.
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
    
    // State for showing a validation alert
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Invalid Input", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    /// Validates the form input and saves the new inventory item to the model context.
    private func saveItem() {
        // Final validation before creating the model object
        guard let cost = Double(costString) else {
            alertMessage = "Please enter a valid number for the item cost."
            showAlert = true
            return
        }
        
        // Price is optional, so we handle a nil case
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
        
        // Insert the new item into the SwiftData context
        modelContext.insert(newItem)
        
        // TODO: Add an audit log entry for this creation event.
        
        dismiss()
    }
}

// MARK: - SwiftUI Preview
#Preview {
    // This preview sets up an in-memory container for isolated UI testing.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: InventoryItem.self, configurations: config)
    
    return AddInventoryItemView()
        .modelContainer(container)
}
