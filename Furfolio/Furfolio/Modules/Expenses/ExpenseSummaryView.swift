//
//  ExpenseSummaryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Expense Summary View
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

// MARK: - Audit/Event Logging

fileprivate struct ExpenseSummaryAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ExpenseSummary] \(action): \(detail) at \(dateStr)"
    }
}
fileprivate final class ExpenseSummaryAudit {
    static private(set) var log: [ExpenseSummaryAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = ExpenseSummaryAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum ExpenseSummaryAuditAdmin {
    public static func lastSummary() -> String { ExpenseSummaryAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { ExpenseSummaryAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { ExpenseSummaryAudit.recentSummaries(limit: limit) }
}

// MARK: - ViewModel (Ready for real service integration)

@MainActor
final class ExpenseSummaryViewModel: ObservableObject {
    @Published var expenses: [Expense] = [
        Expense(date: .now, category: "Supplies", amount: 45.25, notes: "Shampoo, scissors"),
        Expense(date: .now.addingTimeInterval(-86400), category: "Utilities", amount: 120.00, notes: "Water bill"),
        Expense(date: .now.addingTimeInterval(-2*86400), category: "Maintenance", amount: 65.50, notes: "Clipper repair")
    ]
    @Published var searchText: String = ""

    var filteredExpenses: [Expense] {
        if searchText.isEmpty {
            return expenses
        } else {
            let result = expenses.filter {
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            ExpenseSummaryAudit.record(action: "Search", detail: "Query: '\(searchText)', Found: \(result.count)")
            return result
        }
    }

    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    init() {
        ExpenseSummaryAudit.record(action: "ViewAppear", detail: "Summary loaded with \(expenses.count) expenses")
    }
}

// MARK: - Main View

struct ExpenseSummaryView: View {
    @StateObject private var viewModel = ExpenseSummaryViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Expense Summary")
                    .font(.largeTitle.bold())
                    .padding(.top)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ExpenseSummaryView-Header")

                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text("Total Expenses:")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.totalAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title2.bold())
                        .foregroundStyle(viewModel.totalAmount > 500 ? .red : .primary)
                        .accessibilityIdentifier("ExpenseSummaryView-Total")
                }
                .padding(.vertical, 4)

                SearchBar(text: $viewModel.searchText, placeholder: "Search category or notes")
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("ExpenseSummaryView-SearchBar")

                if viewModel.filteredExpenses.isEmpty {
                    Spacer()
                    ContentUnavailableView("No expenses found.", systemImage: "tray")
                        .accessibilityIdentifier("ExpenseSummaryView-Empty")
                    Spacer()
                } else {
                    List {
                        Section(header: Text("Recent Expenses")
                            .font(.headline)
                            .accessibilityIdentifier("ExpenseSummaryView-ListHeader")) {
                            ForEach(viewModel.filteredExpenses) { expense in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(expense.category)
                                            .font(.headline)
                                            .accessibilityIdentifier("ExpenseSummaryView-Category-\(expense.id)")
                                        Spacer()
                                        Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                            .font(.body.bold())
                                            .foregroundStyle(expense.amount > 100 ? .red : .primary)
                                            .accessibilityIdentifier("ExpenseSummaryView-Amount-\(expense.id)")
                                    }
                                    Text(expense.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("ExpenseSummaryView-Date-\(expense.id)")
                                    if let notes = expense.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("ExpenseSummaryView-Notes-\(expense.id)")
                                    }
                                }
                                .padding(.vertical, 2)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(expense.category), \(expense.amount) dollars, \(expense.date.formatted(date: .abbreviated, time: .omitted)), \(expense.notes ?? "")")
                                .accessibilityIdentifier("ExpenseSummaryView-Item-\(expense.id)")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("ExpenseSummaryView-List")
                }
            }
            .padding(.horizontal)
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        ExpenseSummaryAudit.record(action: "AddExpenseTapped", detail: "User tapped add expense")
                        // Add expense action
                    } label: {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("ExpenseSummaryView-AddButton")
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
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("ExpenseSummaryView-ClearSearch")
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
