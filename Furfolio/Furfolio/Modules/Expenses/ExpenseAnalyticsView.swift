//
//  ExpenseAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  ExpenseAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct ExpenseRecord: Identifiable {
    let id = UUID()
    var category: String
    var amount: Double
    var date: Date
}

struct ExpenseAnalyticsView: View {
    let expenses: [ExpenseRecord]

    // Group expenses by category and sum amounts
    private var expensesByCategory: [String: Double] {
        Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    // Sort categories by total amount descending
    private var sortedCategories: [(category: String, total: Double)] {
        expensesByCategory.sorted { $0.value > $1.value }
    }

    // Group expenses by month
    private var expensesByMonth: [(month: Date, total: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenses) { expense in
            calendar.date(from: calendar.dateComponents([.year, .month], from: expense.date)) ?? expense.date
        }
        return grouped.map { (key, values) in
            (month: key, total: values.reduce(0) { $0 + $1.amount })
        }.sorted { $0.month < $1.month }
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var averageExpense: Double {
        guard !expenses.isEmpty else { return 0 }
        return totalExpenses / Double(expenses.count)
    }

    private var highestExpense: Double {
        expenses.map { $0.amount }.max() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Expense Analytics")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Expense Analytics Overview")

                // Total Expenses
                VStack(alignment: .leading) {
                    Text("Total Expenses")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("$\(totalExpenses, specifier: "%.2f")")
                        .font(.title)
                        .foregroundColor(.red)
                        .accessibilityLabel("Total expenses: $\(totalExpenses, specifier: "%.2f")")
                }
                .padding(.horizontal)

                // Expenses by Category Bar Chart
                VStack(alignment: .leading) {
                    Text("Expenses by Category")
                        .font(.headline)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Expenses by Category")

                    Chart {
                        ForEach(sortedCategories, id: \.category) { item in
                            BarMark(
                                x: .value("Category", item.category),
                                y: .value("Amount", item.total)
                            )
                            .foregroundStyle(Color.red.gradient)
                            .annotation(position: .top) {
                                Text("$\(item.total, specifier: "%.2f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel("\(item.category): $\(item.total, specifier: "%.2f")")
                        }
                    }
                    .frame(height: 240)
                    .padding(.horizontal)
                    .accessibilityLabel("Bar chart of expenses by category")
                }

                // Expenses Over Time Line Chart
                VStack(alignment: .leading) {
                    Text("Expenses Over Time")
                        .font(.headline)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Expenses Over Time")

                    Chart {
                        ForEach(expensesByMonth, id: \.month) { item in
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Total Expense", item.total)
                            )
                            .foregroundStyle(Color.red)
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle())
                            .symbolSize(40)
                            .annotation(position: .top) {
                                Text("$\(item.total, specifier: "%.2f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel("\(formattedMonth(item.month)): $\(item.total, specifier: "%.2f")")
                        }
                    }
                    .frame(height: 240)
                    .padding(.horizontal)
                    .accessibilityLabel("Line chart of expenses over time")
                }

                // Summary Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Summary Statistics")

                    HStack {
                        Text("Average Expense:")
                        Spacer()
                        Text("$\(averageExpense, specifier: "%.2f")")
                            .accessibilityLabel("Average expense: $\(averageExpense, specifier: "%.2f")")
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("Highest Expense:")
                        Spacer()
                        Text("$\(highestExpense, specifier: "%.2f")")
                            .accessibilityLabel("Highest expense: $\(highestExpense, specifier: "%.2f")")
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func formattedMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

#if DEBUG
struct ExpenseAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleExpenses = [
            ExpenseRecord(category: "Supplies", amount: 120.0, date: Date(timeIntervalSinceNow: -86400 * 1)),
            ExpenseRecord(category: "Rent", amount: 1500.0, date: Date(timeIntervalSinceNow: -86400 * 30)),
            ExpenseRecord(category: "Utilities", amount: 200.0, date: Date(timeIntervalSinceNow: -86400 * 15)),
            ExpenseRecord(category: "Supplies", amount: 90.0, date: Date(timeIntervalSinceNow: -86400 * 5)),
            ExpenseRecord(category: "Other", amount: 50.0, date: Date(timeIntervalSinceNow: -86400 * 10))
        ]
        ExpenseAnalyticsView(expenses: sampleExpenses)
    }
}
#endif
