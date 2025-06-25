//
//  ExpenseChartView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Expense Chart View
//

import SwiftUI
import Charts

struct ExpenseRecord {
    let category: String
    let amount: Double
}

struct ExpenseChartView: View {
    let expenses: [ExpenseRecord]

    // MARK: - Group and Summarize Expenses
    private var groupedExpenses: [(category: String, total: Double)] {
        Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Expenses by Category")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ExpenseChartView-Header")
                Spacer()
                Text("Total: $\(totalExpenses, specifier: "%.2f")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .accessibilityIdentifier("ExpenseChartView-Total")
            }
            .padding(.bottom, 2)

            if groupedExpenses.isEmpty {
                Text("No expenses to display.")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("ExpenseChartView-EmptyMessage")
            } else {
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
                        .accessibilityLabel("\(item.category) category bar")
                        .accessibilityValue("$\(item.total, specifier: "%.2f")")
                        .accessibilityIdentifier("ExpenseChartView-Bar-\(item.category)")
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: groupedExpenses.count)) { value in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .chartLegend(.visible)
                .frame(height: 240)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Bar chart of expenses by category")
                .accessibilityIdentifier("ExpenseChartView-Chart")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.97))
                .shadow(color: Color(.black).opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expense chart view. Bar chart showing expenses grouped by category.")
        .accessibilityIdentifier("ExpenseChartView-Container")
        .onAppear {
            ExpenseChartAudit.record(categoryCount: groupedExpenses.count, total: totalExpenses)
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseChartAuditEvent: Codable {
    let timestamp: Date
    let categoryCount: Int
    let total: Double
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ExpenseChart] Shown: \(categoryCount) categories, total: $\(String(format: "%.2f", total)) at \(dateStr)"
    }
}
fileprivate final class ExpenseChartAudit {
    static private(set) var log: [ExpenseChartAuditEvent] = []
    static func record(categoryCount: Int, total: Double) {
        let event = ExpenseChartAuditEvent(
            timestamp: Date(),
            categoryCount: categoryCount,
            total: total
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
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

// MARK: - Admin/Audit Accessors

public enum ExpenseChartAuditAdmin {
    public static func lastSummary() -> String { ExpenseChartAudit.log.last?.summary ?? "No chart events yet." }
    public static func lastJSON() -> String? { ExpenseChartAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { ExpenseChartAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

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
