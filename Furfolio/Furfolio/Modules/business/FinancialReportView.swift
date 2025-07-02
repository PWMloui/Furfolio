//
//  FinancialReportView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Financial Report View
//

import SwiftUI
import AVFoundation

// MARK: - Audit/Event Logging

fileprivate struct FinancialReportAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "generate", "export"
    let period: String
    let totalRevenue: Double
    let totalExpenses: Double
    let netProfit: Double
    let profitMargin: Double
    let revenueBreakdown: [String: Double]
    let expenseBreakdown: [String: Double]
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var s = "[\(operation.capitalized)] \(period)"
        s += ", Revenue: $\(String(format: "%.2f", totalRevenue))"
        s += ", Expenses: $\(String(format: "%.2f", totalExpenses))"
        s += ", Net: $\(String(format: "%.2f", netProfit)), Margin: \(String(format: "%.1f", profitMargin))%"
        if !revenueBreakdown.isEmpty {
            let r = revenueBreakdown.map { "\($0.key): $\(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
            s += " | Revenue Breakdown: [\(r)]"
        }
        if !expenseBreakdown.isEmpty {
            let e = expenseBreakdown.map { "\($0.key): $\(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
            s += " | Expense Breakdown: [\(e)]"
        }
        if !tags.isEmpty { s += " [\(tags.joined(separator: ","))]" }
        s += " at \(dateStr)"
        if let detail, !detail.isEmpty { s += ": \(detail)" }
        return s
    }
}

fileprivate final class FinancialReportAudit {
    static private(set) var log: [FinancialReportAuditEvent] = []

    static func record(
        operation: String,
        period: String,
        totalRevenue: Double,
        totalExpenses: Double,
        netProfit: Double,
        profitMargin: Double,
        revenueBreakdown: [String: Double],
        expenseBreakdown: [String: Double],
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = FinancialReportAuditEvent(
            timestamp: Date(),
            operation: operation,
            period: period,
            totalRevenue: totalRevenue,
            totalExpenses: totalExpenses,
            netProfit: netProfit,
            profitMargin: profitMargin,
            revenueBreakdown: revenueBreakdown,
            expenseBreakdown: expenseBreakdown,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No financial report events recorded."
    }
    
    // MARK: - Analytics Enhancements
    
    /// Average profit margin across all audit events.
    static var averageProfitMargin: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.profitMargin }
        return total / Double(log.count)
    }
    
    /// Most frequent tag in the audit log.
    static var mostFrequentTag: String? {
        let allTags = log.flatMap { $0.tags }
        guard !allTags.isEmpty else { return nil }
        let counts = Dictionary(grouping: allTags, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Most recent period exported (operation == "export").
    static var lastExportedPeriod: String? {
        log.reversed().first(where: { $0.operation == "export" })?.period
    }
    
    // MARK: - CSV Export Enhancement
    
    /// Export the entire audit log as CSV string.
    /// Columns: timestamp,operation,period,totalRevenue,totalExpenses,netProfit,profitMargin,revenueBreakdown,expenseBreakdown,tags,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,period,totalRevenue,totalExpenses,netProfit,profitMargin,revenueBreakdown,expenseBreakdown,tags,detail"
        let dateFormatter = ISO8601DateFormatter()
        
        func csvEscape(_ value: String) -> String {
            // Escape quotes by doubling, wrap in quotes if contains comma or quote
            if value.contains(",") || value.contains("\"") || value.contains("\n") {
                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            } else {
                return value
            }
        }
        
        let rows = log.map { event -> String in
            let timestamp = dateFormatter.string(from: event.timestamp)
            let operation = csvEscape(event.operation)
            let period = csvEscape(event.period)
            let totalRevenue = String(format: "%.2f", event.totalRevenue)
            let totalExpenses = String(format: "%.2f", event.totalExpenses)
            let netProfit = String(format: "%.2f", event.netProfit)
            let profitMargin = String(format: "%.2f", event.profitMargin)
            
            let revenueBreakdownStr = csvEscape(event.revenueBreakdown.map { "\($0.key): \($0.value)" }.joined(separator: "; "))
            let expenseBreakdownStr = csvEscape(event.expenseBreakdown.map { "\($0.key): \($0.value)" }.joined(separator: "; "))
            let tagsStr = csvEscape(event.tags.joined(separator: ";"))
            let detailStr = csvEscape(event.detail ?? "")
            
            return [timestamp, operation, period, totalRevenue, totalExpenses, netProfit, profitMargin, revenueBreakdownStr, expenseBreakdownStr, tagsStr, detailStr].joined(separator: ",")
        }
        
        return ([header] + rows).joined(separator: "\n")
    }
}

/// Admin interface to expose audit analytics and CSV export.
struct FinancialReportAuditAdmin {
    /// Export audit log as CSV string.
    static func exportCSV() -> String {
        FinancialReportAudit.exportCSV()
    }
    
    /// Average profit margin across all audit events.
    static var averageProfitMargin: Double {
        FinancialReportAudit.averageProfitMargin
    }
    
    /// Most frequent tag in audit log.
    static var mostFrequentTag: String? {
        FinancialReportAudit.mostFrequentTag
    }
    
    /// Most recent period exported.
    static var lastExportedPeriod: String? {
        FinancialReportAudit.lastExportedPeriod
    }
}

// MARK: - ReportLineItem

struct ReportLineItem: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let amount: Double
}

// MARK: - FinancialReportViewModel

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

    private(set) var lastPeriod: TimePeriod = .month
    
    init(revenueAnalyzer: RevenueAnalyzer = .shared, dataStore: DataStoreService = .shared) {
        self.revenueAnalyzer = revenueAnalyzer
        self.dataStore = dataStore
    }
    
    /// Fetches all necessary data and calculates the report values for a given time period.
    func generateReport(for period: TimePeriod) async {
        isLoading = true
        lastPeriod = period
        reportTitle = "\(period.rawValue) Financial Report"
        
        // Determine date range from the selected period
        let (start, end) = period.dateRange()
        
        // Fetch all charges and expenses within the date range
        let allCharges = await dataStore.fetchAll(Charge.self)
        let allExpenses = await dataStore.fetchAll(Expense.self)
        
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
        
        // Audit event
        FinancialReportAudit.record(
            operation: "generate",
            period: period.rawValue,
            totalRevenue: self.totalRevenue,
            totalExpenses: self.totalExpenses,
            netProfit: self.netProfit,
            profitMargin: self.profitMargin,
            revenueBreakdown: Dictionary(uniqueKeysWithValues: self.revenueBreakdown.map { ($0.category, $0.amount) }),
            expenseBreakdown: Dictionary(uniqueKeysWithValues: self.expenseBreakdown.map { ($0.category, $0.amount) }),
            tags: ["generate", period.rawValue]
        )
        
        // Accessibility enhancement: announce low profit margin warning if below 10%
        if self.profitMargin < 10 {
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: "Warning: Low profit margin for this period.")
            }
        }
        
        isLoading = false
    }

    /// Audit export for admin/BI
    var lastAuditSummary: String { FinancialReportAudit.accessibilitySummary }
    var lastAuditJSON: String? { FinancialReportAudit.exportLastJSON() }
    func recentAuditEvents(limit: Int = 5) -> [String] {
        FinancialReportAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - FinancialReportView

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
                ReportRow(label: "Profit Margin", amount: viewModel.profitMargin, isBold: true, isPercent: true)
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
                    FinancialReportAudit.record(
                        operation: "export",
                        period: selectedPeriod.rawValue,
                        totalRevenue: viewModel.totalRevenue,
                        totalExpenses: viewModel.totalExpenses,
                        netProfit: viewModel.netProfit,
                        profitMargin: viewModel.profitMargin,
                        revenueBreakdown: Dictionary(uniqueKeysWithValues: viewModel.revenueBreakdown.map { ($0.category, $0.amount) }),
                        expenseBreakdown: Dictionary(uniqueKeysWithValues: viewModel.expenseBreakdown.map { ($0.category, $0.amount) }),
                        tags: ["export", selectedPeriod.rawValue],
                        detail: "Export button tapped"
                    )
                    // TODO: Integrate ReportGenerator to create a PDF of this data
                }
            }
        }
        .task {
            await viewModel.generateReport(for: selectedPeriod)
        }
#if DEBUG
        // MARK: - DEV Overlay showing audit info in DEBUG builds
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit Events (Last 3):")
                    .font(.caption)
                    .bold()
                ForEach(FinancialReportAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(String(format: "Average Profit Margin: %.2f%%", FinancialReportAudit.averageProfitMargin))
                    .font(.caption2)
                Text("Most Frequent Tag: \(FinancialReportAudit.mostFrequentTag ?? "None")")
                    .font(.caption2)
            }
            .padding(6)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
            , alignment: .bottom
        )
#endif
    }
}

/// A reusable row for displaying a line item in the report.
private struct ReportRow: View {
    let label: String
    let amount: Double
    var color: Color? = nil
    var isBold: Bool = false
    var isPercent: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(isBold ? .bold : .regular)
            Spacer()
            if isPercent {
                Text("\(amount, specifier: "%.1f")%")
                    .foregroundStyle(color ?? .primary)
                    .fontWeight(isBold ? .bold : .regular)
            } else {
                Text(amount, format: .currency(code: "USD"))
                    .foregroundStyle(color ?? .primary)
                    .fontWeight(isBold ? .bold : .regular)
            }
        }
    }
}

// MARK: - TimePeriod Extension

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
