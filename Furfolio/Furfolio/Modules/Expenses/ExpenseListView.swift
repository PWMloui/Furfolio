//
//  ExpenseListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Expense List
//

import SwiftUI

struct Expense: Identifiable {
    let id = UUID()
    var description: String
    var amount: Double
    var date: Date
    var category: String
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseListAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let expenseID: UUID?
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ExpenseList] \(action): \(details)\(expenseID != nil ? " (\(expenseID!.uuidString))" : "") at \(dateStr)"
    }
}
fileprivate final class ExpenseListAudit {
    static private(set) var log: [ExpenseListAuditEvent] = []
    static func record(action: String, expenseID: UUID? = nil, details: String = "") {
        let event = ExpenseListAuditEvent(timestamp: Date(), action: action, expenseID: expenseID, details: details)
        log.append(event)
        if log.count > 60 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum ExpenseListAuditAdmin {
    public static func lastSummary() -> String { ExpenseListAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { ExpenseListAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 10) -> [String] { ExpenseListAudit.recentSummaries(limit: limit) }
}

// MARK: - ViewModel

@MainActor
class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading: Bool = false
    @Published var lastDeleted: (expense: Expense, index: Int)? = nil
    @Published var showUndo: Bool = false

    func loadExpenses() {
        isLoading = true
        ExpenseListAudit.record(action: "Load", details: "Loading expenses")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.expenses = [
                Expense(description: "Dog shampoo", amount: 25.0, date: Date(timeIntervalSinceNow: -86400 * 3), category: "Supplies"),
                Expense(description: "Rent", amount: 1200.0, date: Date(timeIntervalSinceNow: -86400 * 30), category: "Rent"),
                Expense(description: "Electricity bill", amount: 150.0, date: Date(timeIntervalSinceNow: -86400 * 10), category: "Utilities"),
                Expense(description: "Office supplies", amount: 75.0, date: Date(timeIntervalSinceNow: -86400 * 5), category: "Supplies")
            ]
            self.isLoading = false
            ExpenseListAudit.record(action: "LoadSuccess", details: "Loaded \(self.expenses.count) expenses")
        }
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        ExpenseListAudit.record(action: "Add", expenseID: expense.id, details: "Added \(expense.description)")
    }

    func deleteExpense(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let expense = expenses[index]
        expenses.remove(atOffsets: offsets)
        lastDeleted = (expense, index)
        showUndo = true
        ExpenseListAudit.record(action: "Delete", expenseID: expense.id, details: "Deleted \(expense.description)")
    }

    func undoDelete() {
        guard let last = lastDeleted else { return }
        expenses.insert(last.expense, at: last.index)
        ExpenseListAudit.record(action: "UndoDelete", expenseID: last.expense.id, details: "Restored \(last.expense.description)")
        lastDeleted = nil
        showUndo = false
    }
}

// MARK: - Main View

struct ExpenseListView: View {
    @StateObject private var viewModel = ExpenseListViewModel()
    @State private var showingAddExpense = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading expenses…")
                        .padding(.top, 30)
                        .accessibilityIdentifier("ExpenseListView-Loading")
                }
                List {
                    Section(header: Text("Expenses")
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("ExpenseListView-Header")
                    ) {
                        if viewModel.expenses.isEmpty && !viewModel.isLoading {
                            Text("No expenses found.")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 30)
                                .accessibilityLabel("No expenses found")
                                .accessibilityIdentifier("ExpenseListView-Empty")
                        } else {
                            ForEach(viewModel.expenses) { expense in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(expense.description)
                                        .font(.headline)
                                        .accessibilityIdentifier("ExpenseListView-Description-\(expense.id)")
                                    Text(expense.category)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("ExpenseListView-Category-\(expense.id)")
                                    HStack {
                                        Text(expense.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .accessibilityIdentifier("ExpenseListView-Date-\(expense.id)")
                                        Spacer()
                                        Text("$\(expense.amount, specifier: "%.2f")")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(expense.amount > 500 ? .red : .primary)
                                            .accessibilityIdentifier("ExpenseListView-Amount-\(expense.id)")
                                    }
                                }
                                .padding(.vertical, 6)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(expense.description), category \(expense.category), amount \(expense.amount) dollars, date \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                                .accessibilityIdentifier("ExpenseListView-Item-\(expense.id)")
                            }
                            .onDelete(perform: viewModel.deleteExpense)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showingAddExpense = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add new expense")
                        .accessibilityIdentifier("ExpenseListView-AddButton")
                    }
                }
                .refreshable {
                    viewModel.loadExpenses()
                    ExpenseListAudit.record(action: "Refresh", details: "User refreshed expenses")
                }
                .onAppear {
                    viewModel.loadExpenses()
                }
                .sheet(isPresented: $showingAddExpense) {
                    AddExpenseView { description, amount, date, category in
                        viewModel.addExpense(Expense(description: description, amount: amount, date: date, category: category))
                        showingAddExpense = false
                    }
                }

                if viewModel.showUndo, let last = viewModel.lastDeleted {
                    Button {
                        withAnimation { viewModel.undoDelete() }
                    } label: {
                        Label("Undo delete '\(last.expense.description)'", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .background(Color.yellow.opacity(0.12))
                    .accessibilityIdentifier("ExpenseListView-UndoButton")
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
                    .accessibilityIdentifier("AddExpenseView-Description")
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("AddExpenseView-Amount")
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .accessibilityIdentifier("AddExpenseView-Date")
                TextField("Category", text: $category)
                    .accessibilityIdentifier("AddExpenseView-Category")
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
                    .accessibilityIdentifier("AddExpenseView-SaveButton")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding expense")
                    .accessibilityIdentifier("AddExpenseView-CancelButton")
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
