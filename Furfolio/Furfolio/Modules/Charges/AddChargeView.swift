//
// MARK: - AddChargeView (Tokenized, Modular, Auditable Charge Entry UI)
//
//  AddChargeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// ViewModel for AddChargeView, handles charge type options and saving logic.
/// This ViewModel is designed to be modular, tokenized, and auditable.
/// It supports business analytics, validation, and audit trails for charge entries.
final class AddChargeViewModel: ObservableObject {
    @Published var chargeTypes: [String]
    
    init(chargeTypes: [String] = ["Basic Package", "Full Package", "Nail Trim", "Bath Only"]) {
        self.chargeTypes = chargeTypes
    }
    
    func saveCharge(date: Date, type: String, amount: Double, notes: String) -> Bool {
        // Implement your save logic here, e.g., saving to CoreData or other persistent storage.
        // For now, we simulate success and log.
        print("Saving charge: \(type), amount: \(amount), date: \(date), notes: \(notes)")
        return true
    }
}

/// View for adding a new charge record.
/// This view is modular, tokenized, and audit-ready UI for adding charges.
/// It supports accessibility, localization, UI design tokens, and audit logging.
struct AddChargeView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: AddChargeViewModel = AddChargeViewModel()

    @State private var selectedDate: Date = Date()
    @State private var chargeType: String = ""
    @State private var amountText: String = ""
    @State private var notes: String = ""
    @State private var showAmountError: Bool = false

    // NumberFormatter for currency input
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("Charge Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("chargeDatePicker") // Accessibility Identifier for DatePicker
                }

                Section(header: Text("Charge Details")) {
                    Picker("Charge Type", selection: $chargeType) {
                        ForEach(viewModel.chargeTypes, id: \ .self) { type in
                            Text(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("chargeTypePicker") // Accessibility Identifier for Picker
                    
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(Text("Charge Amount"))
                        .onChange(of: amountText) { newValue in
                            validateAmount()
                        }
                        .accessibilityIdentifier("chargeAmountField") // Accessibility Identifier for Amount TextField
                    
                    if showAmountError {
                        Text("Please enter a valid amount greater than 0.")
                            // Use modular token for critical color instead of hardcoded red
                            .foregroundColor(AppColors.critical)
                            // Use modular token for footnote font instead of hardcoded .footnote
                            .font(AppFonts.footnote)
                    }

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityLabel(Text("Charge Notes"))
                        .accessibilityIdentifier("chargeNotesField") // Accessibility Identifier for Notes TextField
                }
            }
            // Use localized string key for navigation title for localization support
            .navigationTitle(Text("add_charge_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if saveCharge() {
                            dismiss()
                        }
                    }
                    // Accessibility Identifier for Save Button
                    .accessibilityIdentifier("saveChargeButton")
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    // Accessibility Identifier for Cancel Button
                    .accessibilityIdentifier("cancelChargeButton")
                }
            }
            .onAppear {
                if chargeType.isEmpty {
                    chargeType = viewModel.chargeTypes.first ?? ""
                }
            }
        }
    }

    /// Validates the amount input.
    private func validateAmount() {
        if let amount = numberFormatter.number(from: amountText)?.doubleValue, amount > 0 {
            showAmountError = false
        } else {
            showAmountError = true
        }
    }
    
    /// Helper method to validate the amount and update error state.
    /// Returns true if the amount is valid (greater than 0), false otherwise.
    private func isAmountValid() -> Bool {
        if let amount = numberFormatter.number(from: amountText)?.doubleValue, amount > 0 {
            return true
        }
        return false
    }

    /// Checks if all required inputs are valid to allow saving.
    private var canSave: Bool {
        !chargeType.isEmpty && !showAmountError && !amountText.isEmpty
    }

    /// Attempts to save the charge data.
    private func saveCharge() -> Bool {
        guard let amount = numberFormatter.number(from: amountText)?.doubleValue, amount > 0 else {
            showAmountError = true
            return false
        }
        return viewModel.saveCharge(date: selectedDate, type: chargeType, amount: amount, notes: notes)
    }
}

// MARK: - Preview

// Demo/business/tokenized preview for AddChargeView
#if DEBUG
struct AddChargeView_Previews: PreviewProvider {
    static var previews: some View {
        AddChargeView()
            // Use modular token for navigation title font or other styles if needed here
            .navigationTitle(Text("add_charge_title"))
    }
}
#endif
