//
//  ExpenseAnalyticsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Expense Analytics View
//

import SwiftUI
import Charts

struct ExpenseRecord: Identifiable {
    let id = UUID()
    var category: String
    var amount: Double
    var date: Date
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseAnalyticsAuditEvent: Codable {
    let timestamp: Date
    let expenseCount: Int
    let total: Double
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ExpenseAnalytics] Shown: \(expenseCount) expenses, total: $\(String(format: "%.2f", total)) at \(dateStr)"
    }
}
fileprivate final class ExpenseAnalyticsAudit {
    static private(set) var log: [ExpenseAnalyticsAuditEvent] = []
    static func record(expenseCount: Int, total: Double) {
        let event = ExpenseAnalyticsAuditEvent(
            timestamp: Date(),
            expenseCount: expenseCount,
            total: total
        )
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum ExpenseAnalyticsAuditAdmin {
    public static func lastSummary() -> String { ExpenseAnalyticsAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { ExpenseAnalyticsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { ExpenseAnalyticsAudit.recentSummaries(limit: limit) }
}

// MARK: - Main View

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

    @State private var showExportAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Expense Analytics")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Expense Analytics Overview")
                    .accessibilityIdentifier("ExpenseAnalyticsView-Header")

                if expenses.isEmpty {
                    Text("No expenses to analyze.")
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .padding(.top, 32)
                        .accessibilityIdentifier("ExpenseAnalyticsView-EmptyMessage")
                } else {
                    // Total Expenses
                    VStack(alignment: .leading) {
                        Text("Total Expenses")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("$\(totalExpenses, specifier: "%.2f")")
                            .font(.title)
                            .foregroundColor(.red)
                            .accessibilityLabel("Total expenses: $\(totalExpenses, specifier: "%.2f")")
                            .accessibilityIdentifier("ExpenseAnalyticsView-Total")
                    }
                    .padding(.horizontal)

                    // Expenses by Category Bar Chart
                    VStack(alignment: .leading) {
                        Text("Expenses by Category")
                            .font(.headline)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Expenses by Category")
                            .accessibilityIdentifier("ExpenseAnalyticsView-CategoryHeader")

                        Chart {
                            ForEach(sortedCategories, id: \.category) { item in
                                BarMark(
                                    x: .value("Category", item.category),
                                    y: .value("Amount", item.total)
                                )
                                .annotation(position: .top) {
                                    Text("$\(item.total, specifier: "%.2f")")
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .accessibilityLabel("\(item.category): $\(item.total, specifier: "%.2f")")
                                .accessibilityIdentifier("ExpenseAnalyticsView-CategoryBar-\(item.category)")
                            }
                        }
                        .frame(height: 240)
                        .padding(.horizontal)
                        .accessibilityLabel("Bar chart of expenses by category")
                        .accessibilityIdentifier("ExpenseAnalyticsView-CategoryBarChart")
                    }

                    // Expenses Over Time Line Chart
                    VStack(alignment: .leading) {
                        Text("Expenses Over Time")
                            .font(.headline)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Expenses Over Time")
                            .accessibilityIdentifier("ExpenseAnalyticsView-TimeHeader")

                        Chart {
                            ForEach(expensesByMonth, id: \.month) { item in
                                LineMark(
                                    x: .value("Month", item.month),
                                    y: .value("Total Expense", item.total)
                                )
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle())
                                .symbolSize(40)
                                .annotation(position: .top) {
                                    Text("$\(item.total, specifier: "%.2f")")
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .accessibilityLabel("\(formattedMonth(item.month)): $\(item.total, specifier: "%.2f")")
                                .accessibilityIdentifier("ExpenseAnalyticsView-TimeLine-\(formattedMonth(item.month))")
                            }
                        }
                        .frame(height: 240)
                        .padding(.horizontal)
                        .accessibilityLabel("Line chart of expenses over time")
                        .accessibilityIdentifier("ExpenseAnalyticsView-TimeLineChart")
                    }

                    // Summary Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Summary Statistics")
                            .accessibilityIdentifier("ExpenseAnalyticsView-SummaryHeader")

                        HStack {
                            Text("Average Expense:")
                            Spacer()
                            Text("$\(averageExpense, specifier: "%.2f")")
                                .accessibilityLabel("Average expense: $\(averageExpense, specifier: "%.2f")")
                                .accessibilityIdentifier("ExpenseAnalyticsView-Average")
                        }
                        .padding(.horizontal)

                        HStack {
                            Text("Highest Expense:")
                            Spacer()
                            Text("$\(highestExpense, specifier: "%.2f")")
                                .accessibilityLabel("Highest expense: $\(highestExpense, specifier: "%.2f")")
                                .accessibilityIdentifier("ExpenseAnalyticsView-Highest")
                        }
                        .padding(.horizontal)
                    }

                    // Optional: Export analytics audit log for admin/QA
                    Button {
                        showExportAlert = true
                    } label: {
                        Label("Export Analytics Log", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.accentColor.opacity(0.11))
                            .cornerRadius(12)
                    }
                    .padding([.horizontal, .top])
                    .accessibilityIdentifier("ExpenseAnalyticsView-ExportButton")
                    .alert("Analytics Log", isPresented: $showExportAlert, actions: {
                        Button("OK", role: .cancel) { }
                    }, message: {
                        ScrollView {
                            Text(ExpenseAnalyticsAuditAdmin.recentEvents(limit: 6).joined(separator: "\n"))
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                        }
                    })
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            ExpenseAnalyticsAudit.record(expenseCount: expenses.count, total: totalExpenses)
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
