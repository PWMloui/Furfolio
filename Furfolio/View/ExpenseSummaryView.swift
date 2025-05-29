import SwiftUI
import SwiftData
import os

/// ViewModel for loading and summarizing expenses.
@MainActor
class ExpenseSummaryViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var totalAmount: Double = 0
    @Published var averageAmount: Double = 0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ExpenseSummaryViewModel")
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        logger.log("Initialized ExpenseSummaryViewModel")
        loadExpenses()
    }

    /// Loads all expenses and computes summary metrics.
    func loadExpenses() {
        logger.log("Loading all expenses")
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            let results = try context.fetch(descriptor)
            expenses = results
            totalAmount = results.reduce(0) { $0 + $1.amount }
            averageAmount = results.isEmpty ? 0 : totalAmount / Double(results.count)
            logger.log("Loaded \(results.count) expenses, total: \(totalAmount), average: \(averageAmount)")
        } catch {
            logger.error("Failed to fetch expenses: \(error.localizedDescription)")
            expenses = []
            totalAmount = 0
            averageAmount = 0
        }
    }

    /// Deletes expenses at the specified offsets.
    func delete(at offsets: IndexSet) {
        logger.log("Deleting expenses at offsets: \(offsets)")
        for index in offsets {
            context.delete(expenses[index])
        }
        do {
            try context.save()
            logger.log("Deleted expenses and saved context")
        } catch {
            logger.error("Failed to delete expenses: \(error.localizedDescription)")
        }
        loadExpenses()
    }
}

/// A summary view displaying total, average, and a list of all expenses.
struct ExpenseSummaryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseSummaryViewModel
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ExpenseSummaryView")

    init() {
        let ctx = PersistenceController.shared.modelContext
        _viewModel = StateObject(wrappedValue: ExpenseSummaryViewModel(context: ctx))
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Summary")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)) {
                    HStack {
                        Text("Total Spent:")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        Text(viewModel.totalAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    }
                    HStack {
                        Text("Average Expense:")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        Text(viewModel.averageAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
                Section(header: Text("All Expenses")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)) {
                    ForEach(viewModel.expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.category)
                                    .font(AppTheme.body)
                                    .foregroundColor(AppTheme.primaryText)
                                Text(expense.date, style: .date)
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            Spacer()
                            Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.primaryText)
                        }
                        .onAppear {
                            logger.log("Displaying expense row id: \(expense.id), category: \(expense.category)")
                        }
                    }
                    .onDelete(perform: viewModel.delete(at:))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expense Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        logger.log("ExpenseSummaryView Close tapped")
                        dismiss()
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        logger.log("ExpenseSummaryView Refresh tapped")
                        viewModel.loadExpenses()
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
            }
            .onAppear {
                logger.log("ExpenseSummaryView appeared; loading data")
            }
        }
    }
}
