//
//  ExpenseFilterView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Expense Filter View
//

import SwiftUI

struct ExpenseFilterView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedCategory: String?
    @Binding var minAmount: String
    @Binding var maxAmount: String

    let categories: [String]
    var onApply: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var onReset: (() -> Void)? = nil

    @State private var errorMessage: String?

    var isApplyDisabled: Bool {
        if endDate < startDate { return true }
        if let min = Double(minAmount), let max = Double(maxAmount), min > max { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date Range").fontWeight(.semibold)) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityLabel("Start date filter")
                        .accessibilityIdentifier("ExpenseFilterView-StartDate")
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityLabel("End date filter")
                        .accessibilityIdentifier("ExpenseFilterView-EndDate")
                }

                Section(header: Text("Category").fontWeight(.semibold)) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(String?.none)
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                    .accessibilityLabel("Expense category filter")
                    .accessibilityIdentifier("ExpenseFilterView-CategoryPicker")
                }

                Section(header: Text("Amount Range").fontWeight(.semibold)) {
                    TextField("Min Amount", text: $minAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Minimum amount filter")
                        .accessibilityIdentifier("ExpenseFilterView-MinAmount")
                    TextField("Max Amount", text: $maxAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Maximum amount filter")
                        .accessibilityIdentifier("ExpenseFilterView-MaxAmount")
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("ExpenseFilterView-Error")
                }

                HStack {
                    Button("Reset") {
                        resetFilters()
                    }
                    .accessibilityLabel("Reset expense filters")
                    .accessibilityIdentifier("ExpenseFilterView-ResetButton")
                    .foregroundColor(.orange)
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Apply Filters") {
                        if validateInputs() {
                            errorMessage = nil
                            ExpenseFilterAudit.record(action: "Apply", startDate: startDate, endDate: endDate, category: selectedCategory, minAmount: minAmount, maxAmount: maxAmount)
                            onApply?()
                        }
                    }
                    .disabled(isApplyDisabled)
                    .accessibilityLabel("Apply expense filters")
                    .accessibilityIdentifier("ExpenseFilterView-ApplyButton")
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Filter Expenses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        ExpenseFilterAudit.record(action: "Cancel", startDate: startDate, endDate: endDate, category: selectedCategory, minAmount: minAmount, maxAmount: maxAmount)
                        onCancel?()
                    }
                    .accessibilityLabel("Cancel filter changes")
                    .accessibilityIdentifier("ExpenseFilterView-CancelButton")
                }
            }
            .onAppear {
                ExpenseFilterAudit.record(action: "Appear", startDate: startDate, endDate: endDate, category: selectedCategory, minAmount: minAmount, maxAmount: maxAmount)
            }
        }
    }

    private func validateInputs() -> Bool {
        if endDate < startDate {
            errorMessage = "End date cannot be earlier than start date."
            return false
        }
        if let min = Double(minAmount), let max = Double(maxAmount), min > max {
            errorMessage = "Minimum amount cannot be greater than maximum amount."
            return false
        }
        return true
    }

    private func resetFilters() {
        let now = Date()
        startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        endDate = now
        selectedCategory = nil
        minAmount = ""
        maxAmount = ""
        errorMessage = nil
        ExpenseFilterAudit.record(action: "Reset", startDate: startDate, endDate: endDate, category: selectedCategory, minAmount: minAmount, maxAmount: maxAmount)
        onReset?()
    }
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseFilterAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let startDate: Date
    let endDate: Date
    let category: String?
    let minAmount: String
    let maxAmount: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short
        return "[ExpenseFilter] \(action) from \(df.string(from: startDate)) to \(df.string(from: endDate)), category: \(category ?? "All"), min: \(minAmount), max: \(maxAmount)"
    }
}
fileprivate final class ExpenseFilterAudit {
    static private(set) var log: [ExpenseFilterAuditEvent] = []
    static func record(action: String, startDate: Date, endDate: Date, category: String?, minAmount: String, maxAmount: String) {
        let event = ExpenseFilterAuditEvent(
            timestamp: Date(),
            action: action,
            startDate: startDate,
            endDate: endDate,
            category: category,
            minAmount: minAmount,
            maxAmount: maxAmount
        )
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

// MARK: - Admin/Audit Accessors

public enum ExpenseFilterAuditAdmin {
    public static func lastSummary() -> String { ExpenseFilterAudit.log.last?.summary ?? "No filter events yet." }
    public static func lastJSON() -> String? { ExpenseFilterAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { ExpenseFilterAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct ExpenseFilterView_Previews: PreviewProvider {
    @State static var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State static var endDate = Date()
    @State static var selectedCategory: String? = nil
    @State static var minAmount = ""
    @State static var maxAmount = ""

    static var categories = ["Supplies", "Rent", "Utilities", "Other"]

    static var previews: some View {
        ExpenseFilterView(
            startDate: $startDate,
            endDate: $endDate,
            selectedCategory: $selectedCategory,
            minAmount: $minAmount,
            maxAmount: $maxAmount,
            categories: categories
        )
    }
}
#endif
