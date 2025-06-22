//
//  ExpenseListView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct Expense: Identifiable {
    let id = UUID()
    var description: String
    var amount: Double
    var date: Date
    var category: String
}

@MainActor
class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading: Bool = false

    func loadExpenses() {
        isLoading = true
        // Simulate data loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.expenses = [
                Expense(description: "Dog shampoo", amount: 25.0, date: Date(timeIntervalSinceNow: -86400 * 3), category: "Supplies"),
                Expense(description: "Rent", amount: 1200.0, date: Date(timeIntervalSinceNow: -86400 * 30), category: "Rent"),
                Expense(description: "Electricity bill", amount: 150.0, date: Date(timeIntervalSinceNow: -86400 * 10), category: "Utilities"),
                Expense(description: "Office supplies", amount: 75.0, date: Date(timeIntervalSinceNow: -86400 * 5), category: "Supplies")
            ]
            self.isLoading = false
        }
    }

    func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
    }
}

struct ExpenseListView: View {
    @StateObject private var viewModel = ExpenseListViewModel()
    @State private var showingAddExpense = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.expenses.isEmpty && !viewModel.isLoading {
                    Text("No expenses found.")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No expenses found")
                } else {
                    ForEach(viewModel.expenses) { expense in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.description)
                                .font(.headline)
                            Text(expense.category)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(expense.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(expense.amount, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(expense.description), category \(expense.category), amount \(expense.amount) dollars, date \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .onDelete(perform: viewModel.deleteExpense)
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new expense")
                }
            }
            .refreshable {
                viewModel.loadExpenses()
            }
            .onAppear {
                viewModel.loadExpenses()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView { description, amount, date, category in
                    viewModel.expenses.append(Expense(description: description, amount: amount, date: date, category: category))
                    showingAddExpense = false
                }
            }
        }
    }
}

// Placeholder AddExpenseView for preview and compilation
struct AddExpenseView: View {
    var onAdd: (String, Double, Date, String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var description = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $description)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Category", text: $category)
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amountValue = Double(amount), !description.isEmpty, !category.isEmpty {
                            onAdd(description, amountValue, date, category)
                            dismiss()
                        }
                    }
                    .accessibilityLabel("Save new expense")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding expense")
                }
            }
        }
    }
}

#if DEBUG
struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseListView()
    }
}
#endif
