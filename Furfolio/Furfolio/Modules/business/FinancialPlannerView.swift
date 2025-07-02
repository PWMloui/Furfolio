//
//  FinancialPlannerView.swift
//  Furfolio
//
//  Enhanced for Pro Business Insights
//

import SwiftUI
import Charts   // Requires iOS 16+

// MARK: - ViewModel for Financial Planning

@MainActor
class FinancialPlannerViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var monthlyRevenue: Double = 0
    @Published var monthlyExpenses: Double = 0
    @Published var projectedProfit: Double = 0
    @Published var revenueGoal: Double = 5000
    @Published var recentTransactions: [Transaction] = []
    @Published var expenseBreakdown: [String: Double] = [:]
    @Published var errorMessage: String?
    
    // Chart data
    @Published var cashFlowHistory: [CashFlowEntry] = []
    
    // Init with mock data; swap to real data fetches.
    init() {
        loadFinancialData(for: Date())
    }
    
    func loadFinancialData(for month: Date) {
        // Simulate month-based data. Swap with DB or analyzer.
        monthlyRevenue = 3875
        monthlyExpenses = 1220
        projectedProfit = monthlyRevenue - monthlyExpenses
        recentTransactions = [
            Transaction(date: Date(), type: .revenue, amount: 95, note: "Full Groom - Bella", category: "Service"),
            Transaction(date: Date().addingTimeInterval(-86400), type: .expense, amount: 50, note: "Shampoo Inventory", category: "Supplies"),
            Transaction(date: Date().addingTimeInterval(-172800), type: .revenue, amount: 70, note: "Basic Bath - Max", category: "Service"),
            Transaction(date: Date().addingTimeInterval(-200000), type: .expense, amount: 40, note: "Towels", category: "Supplies"),
            Transaction(date: Date().addingTimeInterval(-250000), type: .expense, amount: 80, note: "Rent", category: "Rent")
        ]
        // Expense breakdown
        expenseBreakdown = [
            "Supplies": 90,
            "Rent": 80,
            "Utilities": 40,
            "Marketing": 10
        ]
        // Cash flow chart (simple mock)
        cashFlowHistory = (0..<10).map { i in
            CashFlowEntry(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!, balance: 3500 + Double.random(in: -100...100) * Double(i))
        }.reversed()
    }
    
    func setGoal(_ newGoal: Double) {
        revenueGoal = newGoal
    }
    
    // CSV Export
    func exportCSV() -> URL? {
        let header = "Date,Type,Amount,Category,Note\n"
        let rows = recentTransactions.map { tx in
            "\(tx.date.formatted(date: .numeric, time: .omitted)),\(tx.type.rawValue),\(tx.amount),\(tx.category),\"\(tx.note)\""
        }
        let csvString = ([header] + rows).joined(separator: "\n")
        do {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("Furfolio_Financials.csv")
            try csvString.write(to: tmpURL, atomically: true, encoding: .utf8)
            return tmpURL
        } catch {
            errorMessage = "Failed to export CSV."
            return nil
        }
    }
    
    func selectMonth(_ newMonth: Date) {
        selectedMonth = newMonth
        loadFinancialData(for: newMonth)
    }
}

// MARK: - Models

struct Transaction: Identifiable {
    enum TransactionType: String { case revenue = "Revenue", expense = "Expense" }
    let id = UUID()
    let date: Date
    let type: TransactionType
    let amount: Double
    let note: String
    let category: String
}

struct CashFlowEntry: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
}

// MARK: - Main View

struct FinancialPlannerView: View {
    @StateObject private var viewModel = FinancialPlannerViewModel()
    @State private var isGoalEditing = false
    @State private var newGoal: String = ""
    @State private var showShareSheet = false
    @State private var csvURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Month Selector
                    MonthPickerView(selectedMonth: $viewModel.selectedMonth) {
                        viewModel.selectMonth($0)
                    }
                    
                    // Revenue and Profit Summary
                    HStack {
                        summaryTile(label: "Revenue", value: viewModel.monthlyRevenue, color: .green)
                        summaryTile(label: "Expenses", value: -viewModel.monthlyExpenses, color: .red)
                        summaryTile(label: "Profit", value: viewModel.projectedProfit, color: .accentColor)
                    }
                    
                    // Revenue Goal Progress
                    goalProgressSection
                    
                    // Cash Flow Chart
                    VStack(alignment: .leading) {
                        Text("Cash Flow History")
                            .font(.headline)
                        if #available(iOS 16.0, *) {
                            Chart(viewModel.cashFlowHistory) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Balance", entry.balance)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue)
                            }
                            .frame(height: 120)
                            .chartYScale(domain: (viewModel.cashFlowHistory.map { $0.balance }.min() ?? 0)...(viewModel.cashFlowHistory.map { $0.balance }.max() ?? 1))
                        } else {
                            Text("Charts require iOS 16+")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    
                    // Expense Breakdown
                    if !viewModel.expenseBreakdown.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Expense Breakdown")
                                .font(.headline)
                            ForEach(viewModel.expenseBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                                HStack {
                                    Text(category)
                                    Spacer()
                                    Text("-$\(amount, specifier: "%.2f")")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                    
                    // Recent Transactions
                    VStack(alignment: .leading) {
                        Text("Recent Transactions")
                            .font(.headline)
                        ForEach(viewModel.recentTransactions.prefix(8)) { tx in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(tx.note).fontWeight(.medium)
                                    HStack(spacing: 8) {
                                        Text(tx.date, style: .date)
                                            .font(.caption).foregroundColor(.secondary)
                                        if !tx.category.isEmpty {
                                            Text(tx.category)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 4)
                                                .background(Color(.systemGray5))
                                                .cornerRadius(5)
                                        }
                                    }
                                }
                                Spacer()
                                Text(tx.type == .revenue ? "+$\(tx.amount, specifier: "%.2f")" : "-$\(tx.amount, specifier: "%.2f")")
                                    .foregroundColor(tx.type == .revenue ? .green : .red)
                                    .bold()
                            }
                            .padding(.vertical, 3)
                        }
                        if viewModel.recentTransactions.isEmpty {
                            Text("No transactions yet.")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    
                    // CSV Export Button
                    Button {
                        if let url = viewModel.exportCSV() {
                            csvURL = url
                            showShareSheet = true
                        }
                    } label: {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Financial Planner")
                .sheet(isPresented: $isGoalEditing) {
                    EditGoalSheet(newGoal: $newGoal, onSave: {
                        if let goalValue = Double(newGoal), goalValue > 0 {
                            viewModel.setGoal(goalValue)
                        }
                        isGoalEditing = false
                    }, onCancel: {
                        isGoalEditing = false
                    })
                }
                .sheet(isPresented: $showShareSheet, content: {
                    if let url = csvURL {
                        ShareSheet(activityItems: [url])
                    }
                })
                .alert(isPresented: .constant(viewModel.errorMessage != nil), content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(viewModel.errorMessage ?? ""),
                        dismissButton: .default(Text("OK"))
                    )
                })
            }
        }
    }
    
    // MARK: - Subviews
    
    func summaryTile(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value < 0 ? "-$\(abs(value), specifier: "%.2f")" : "$\(value, specifier: "%.2f")")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
    
    var goalProgressSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Monthly Revenue Goal").font(.headline)
                Spacer()
                Button(action: {
                    isGoalEditing = true
                    newGoal = String(Int(viewModel.revenueGoal))
                }) {
                    Image(systemName: "pencil")
                        .imageScale(.small)
                }
            }
            ProgressView(value: min(viewModel.monthlyRevenue / viewModel.revenueGoal, 1.0))
                .progressViewStyle(LinearProgressViewStyle())
            HStack {
                Text("$\(Int(viewModel.monthlyRevenue)) / $\(Int(viewModel.revenueGoal))")
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                if viewModel.monthlyRevenue >= viewModel.revenueGoal {
                    Text("Goal Met!").font(.footnote).bold().foregroundColor(.green).transition(.opacity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - Edit Goal Sheet

struct EditGoalSheet: View {
    @Binding var newGoal: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Set Revenue Goal")) {
                    TextField("New Goal", text: $newGoal)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save", action: onSave)
            )
        }
    }
}

// MARK: - Month Picker View

struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    var onSelect: (Date) -> Void
    var body: some View {
        HStack {
            Button(action: {
                withAnimation {
                    if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
                        selectedMonth = prevMonth
                        onSelect(prevMonth)
                    }
                }
            }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(selectedMonth, formatter: monthYearFormatter)
                .font(.headline)
            Spacer()
            Button(action: {
                withAnimation {
                    if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
                        selectedMonth = nextMonth
                        onSelect(nextMonth)
                    }
                }
            }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
    private var monthYearFormatter: DateFormatter {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    FinancialPlannerView()
}
