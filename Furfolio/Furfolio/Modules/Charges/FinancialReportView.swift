//
//  FinancialReportView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A view to generate and display a professional Profit & Loss
//  financial report for the business.
//

import SwiftUI

/// A data model for a single line item in the financial report.
struct ReportLineItem: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let amount: Double
}

/// The ViewModel responsible for fetching and calculating financial report data.
@MainActor
final class FinancialReportViewModel: ObservableObject {
    @Published var reportTitle: String = "Financial Report"
    @Published var totalRevenue: Double = 0
    @Published var totalExpenses: Double = 0
    @Published var netProfit: Double = 0
    @Published var profitMargin: Double = 0
    
    @Published var revenueBreakdown: [ReportLineItem] = []
    @Published var expenseBreakdown: [ReportLineItem] = []
    
    @Published var isLoading = false
    
    // Injected dependencies
    private let revenueAnalyzer: RevenueAnalyzer
    private let dataStore: DataStoreService
    
    init(revenueAnalyzer: RevenueAnalyzer = .shared, dataStore: DataStoreService = .shared) {
        self.revenueAnalyzer = revenueAnalyzer
        self.dataStore = dataStore
    }
    
    /// Fetches all necessary data and calculates the report values for a given time period.
    func generateReport(for period: TimePeriod) async {
        isLoading = true
        reportTitle = "\(period.rawValue) Financial Report"
        
        // Determine date range from the selected period
        let (start, end) = period.dateRange()
        
        // Fetch all charges and expenses within the date range
        let allCharges = await dataStore.fetchAll(Charge.self) // In a real app, you'd filter by date in the fetch
        let allExpenses = await dataStore.fetchAll(Expense.self) // Placeholder for your Expense model
        
        let periodCharges = allCharges.filter { $0.date >= start && $0.date <= end }
        let periodExpenses = allExpenses.filter { $0.date >= start && $0.date <= end }
        
        // Calculate totals
        self.totalRevenue = revenueAnalyzer.totalRevenue(charges: periodCharges)
        self.totalExpenses = periodExpenses.reduce(0) { $0 + $1.amount }
        self.netProfit = totalRevenue - totalExpenses
        self.profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0
        
        // Create breakdowns
        self.revenueBreakdown = Dictionary(grouping: periodCharges, by: { $0.type.displayName })
            .map { ReportLineItem(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
        
        self.expenseBreakdown = Dictionary(grouping: periodExpenses, by: { $0.category })
            .map { ReportLineItem(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
            
        isLoading = false
    }
}

/// The SwiftUI view that displays the financial report.
struct FinancialReportView: View {
    @StateObject private var viewModel = FinancialReportViewModel()
    @State private var selectedPeriod: TimePeriod = .month
    
    var body: some View {
        Form {
            // MARK: - Period Picker
            Section {
                Picker("Time Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _, newPeriod in
                    Task { await viewModel.generateReport(for: newPeriod) }
                }
            }
            
            // MARK: - Summary Section
            Section(header: Text("Summary")) {
                ReportRow(label: "Total Revenue", amount: viewModel.totalRevenue, color: .green)
                ReportRow(label: "Total Expenses", amount: viewModel.totalExpenses, color: .red)
                Divider()
                ReportRow(label: "Net Profit", amount: viewModel.netProfit, color: viewModel.netProfit >= 0 ? .green : .red, isBold: true)
            }
            
            // MARK: - Revenue Breakdown
            Section(header: Text("Income Breakdown")) {
                if viewModel.revenueBreakdown.isEmpty {
                    Text("No income recorded for this period.")
                } else {
                    ForEach(viewModel.revenueBreakdown) { item in
                        ReportRow(label: item.category, amount: item.amount)
                    }
                }
            }
            
            // MARK: - Expense Breakdown
            Section(header: Text("Expense Breakdown")) {
                if viewModel.expenseBreakdown.isEmpty {
                    Text("No expenses recorded for this period.")
                } else {
                    ForEach(viewModel.expenseBreakdown) { item in
                        ReportRow(label: item.category, amount: item.amount, color: .red)
                    }
                }
            }
        }
        .navigationTitle(viewModel.reportTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export", systemImage: "square.and.arrow.up") {
                    // TODO: Call ReportGenerator to create a PDF of this data
                }
            }
        }
        .task { // Use .task for async onAppear
            await viewModel.generateReport(for: selectedPeriod)
        }
    }
}

/// A reusable row for displaying a line item in the report.
private struct ReportRow: View {
    let label: String
    let amount: Double
    var color: Color? = nil
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(isBold ? .bold : .regular)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .foregroundStyle(color ?? .primary)
                .fontWeight(isBold ? .bold : .regular)
        }
    }
}

/// Extending the TimePeriod enum to provide date ranges.
fileprivate extension TimePeriod {
    func dateRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (startOfWeek, now)
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (startOfMonth, now)
        case .year:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (startOfYear, now)
        }
    }
}

#Preview {
    NavigationStack {
        FinancialReportView()
            // Provide a mock expense model for the preview
            .modelContainer(for: [Charge.self, Expense.self], inMemory: true)
    }
}

// Placeholder Expense model needed for the preview
@Model
final class Expense {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
    var category: String
    init(date: Date, amount: Double, category: String) {
        self.date = date
        self.amount = amount
        self.category = category
    }
}
