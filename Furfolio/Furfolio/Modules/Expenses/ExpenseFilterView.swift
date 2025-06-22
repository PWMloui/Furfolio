//
//  ExpenseFilterView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  ExpenseFilterView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ExpenseFilterView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedCategory: String?
    @Binding var minAmount: String
    @Binding var maxAmount: String

    let categories: [String]

    @State private var errorMessage: String?

    var isApplyDisabled: Bool {
        if endDate < startDate {
            return true
        }
        if let min = Double(minAmount), let max = Double(maxAmount) {
            if min > max {
                return true
            }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityLabel("Start date filter")
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityLabel("End date filter")
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(String?.none)
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                    .accessibilityLabel("Expense category filter")
                }

                Section(header: Text("Amount Range")) {
                    TextField("Min Amount", text: $minAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Minimum amount filter")
                    TextField("Max Amount", text: $maxAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Maximum amount filter")
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }

                Button("Apply Filters") {
                    if validateInputs() {
                        // Possibly send filter apply action to parent view via bindings
                        errorMessage = nil
                    }
                }
                .disabled(isApplyDisabled)
                .accessibilityLabel("Apply expense filters")
            }
            .navigationTitle("Filter Expenses")
        }
    }

    private func validateInputs() -> Bool {
        if endDate < startDate {
            errorMessage = "End date cannot be earlier than start date."
            return false
        }
        if let min = Double(minAmount), let max = Double(maxAmount), min > max {
            errorMessage = "Minimum amount cannot be greater than maximum amount."
            return false
        }
        return true
    }
}

#if DEBUG
struct ExpenseFilterView_Previews: PreviewProvider {
    @State static var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State static var endDate = Date()
    @State static var selectedCategory: String? = nil
    @State static var minAmount = ""
    @State static var maxAmount = ""

    static var categories = ["Supplies", "Rent", "Utilities", "Other"]

    static var previews: some View {
        ExpenseFilterView(
            startDate: $startDate,
            endDate: $endDate,
            selectedCategory: $selectedCategory,
            minAmount: $minAmount,
            maxAmount: $maxAmount,
            categories: categories
        )
    }
}
#endif
