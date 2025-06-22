
//  ExpenseChartView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct ExpenseRecord {
    let category: String
    let amount: Double
}

struct ExpenseChartView: View {
    let expenses: [ExpenseRecord]

    // Group expenses by category and sum the amounts for each category
    private var groupedExpenses: [(category: String, total: Double)] {
        Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Expenses by Category")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Chart {
                ForEach(groupedExpenses, id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Amount", item.total)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .annotation(position: .top) {
                        Text("$\(item.total, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .accessibilityLabel("\(item.category) expense: $\(item.total, specifier: "%.2f")")
                    }
                    .accessibilityLabel("\(item.category)")
                    .accessibilityValue("$\(item.total, specifier: "%.2f")")
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: groupedExpenses.count)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .chartLegend(.visible)
            .frame(height: 240)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Bar chart of expenses by category")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: Color(.black).opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expense chart view. Bar chart showing expenses grouped by category.")
    }
}

#if DEBUG
struct ExpenseChartView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseChartView(expenses: [
            ExpenseRecord(category: "Supplies", amount: 150),
            ExpenseRecord(category: "Rent", amount: 1000),
            ExpenseRecord(category: "Utilities", amount: 200),
            ExpenseRecord(category: "Other", amount: 75),
            ExpenseRecord(category: "Supplies", amount: 50)
        ])
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}
#endif
