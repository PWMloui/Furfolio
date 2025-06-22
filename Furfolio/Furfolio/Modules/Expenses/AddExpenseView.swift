//
//  AddExpenseView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


import SwiftUI

struct ExpenseCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String

    static let all: [ExpenseCategory] = [
        ExpenseCategory(name: "Supplies"),
        ExpenseCategory(name: "Rent"),
        ExpenseCategory(name: "Utilities"),
        ExpenseCategory(name: "Other")
    ]
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: ExpenseCategory = ExpenseCategory.all.first!

    var onSave: ((String, Double, Date, ExpenseCategory) -> Void)?

    var isSaveDisabled: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return true
        }
        return description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                        .accessibilityLabel("Expense description")
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Expense amount")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Expense date")
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.all) { category in
                            Text(category.name).tag(category)
                        }
                    }
                    .accessibilityLabel("Expense category")
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding expense")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amountValue = Double(amount), amountValue > 0 {
                            onSave?(description, amountValue, date, selectedCategory)
                            dismiss()
                        }
                    }
                    .disabled(isSaveDisabled)
                    .accessibilityLabel("Save expense")
                }
            }
        }
    }
}

#if DEBUG
struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView { description, amount, date, category in
            print("Expense saved: \(description), \(amount), \(date), \(category.name)")
        }
    }
}
#endif
