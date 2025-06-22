//
//  ExpenseSummaryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// Dummy Expense model for demonstration. Replace with your real model if needed.
struct Expense: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let amount: Double
    let notes: String?
}

struct ExpenseSummaryView: View {
    // Replace with @Query or ViewModel if connecting to SwiftData/CoreData
    @State private var expenses: [Expense] = [
        Expense(date: .now, category: "Supplies", amount: 45.25, notes: "Shampoo, scissors"),
        Expense(date: .now.addingTimeInterval(-86400), category: "Utilities", amount: 120.00, notes: "Water bill"),
        Expense(date: .now.addingTimeInterval(-2*86400), category: "Maintenance", amount: 65.50, notes: "Clipper repair")
    ]
    @State private var searchText: String = ""
    
    var filteredExpenses: [Expense] {
        if searchText.isEmpty {
            return expenses
        } else {
            return expenses.filter {
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Expense Summary")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.blue)
                    Text("Total Expenses:")
                        .font(.headline)
                    Spacer()
                    Text(totalAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 4)
                
                SearchBar(text: $searchText, placeholder: "Search category or notes")
                    .padding(.bottom, 6)
                
                if filteredExpenses.isEmpty {
                    Spacer()
                    ContentUnavailableView("No expenses found.", systemImage: "tray")
                    Spacer()
                } else {
                    List {
                        ForEach(filteredExpenses) { expense in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(expense.category)
                                        .font(.headline)
                                    Spacer()
                                    Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                        .font(.body.bold())
                                }
                                Text(expense.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let notes = expense.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Add expense action
                    } label: {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// Simple reusable SearchBar for SwiftUI
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground).opacity(0.8))
        .cornerRadius(10)
    }
}

#Preview {
    ExpenseSummaryView()
}
