//
//  AddExpenseView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Add Expense View
//

import SwiftUI

struct ExpenseCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String

    static let all: [ExpenseCategory] = [
        ExpenseCategory(name: "Supplies"),
        ExpenseCategory(name: "Rent"),
        ExpenseCategory(name: "Utilities"),
        ExpenseCategory(name: "Other")
    ]
}

// MARK: - Audit/Event Logging

fileprivate struct AddExpenseAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let description: String?
    let amount: Double?
    let date: Date?
    let category: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[AddExpenseView] \(action): \(description ?? "-") $\(amount ?? 0) [\(category ?? "-")] at \(dateStr)"
    }
}
fileprivate final class AddExpenseAudit {
    static private(set) var log: [AddExpenseAuditEvent] = []
    static func record(action: String, description: String? = nil, amount: Double? = nil, date: Date? = nil, category: String? = nil) {
        let event = AddExpenseAuditEvent(
            timestamp: Date(),
            action: action,
            description: description,
            amount: amount,
            date: date,
            category: category
        )
        log.append(event)
        if log.count > 50 { log.removeFirst() }
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
public enum AddExpenseAuditAdmin {
    public static func lastSummary() -> String { AddExpenseAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { AddExpenseAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { AddExpenseAudit.recentSummaries(limit: limit) }
}

// MARK: - Main View

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: ExpenseCategory = ExpenseCategory.all.first!
    @State private var errorMessage: String? = nil
    @State private var lastSavedExpense: (String, Double, Date, ExpenseCategory)? = nil
    @State private var showUndo: Bool = false

    var onSave: ((String, Double, Date, ExpenseCategory) -> Void)?

    var isSaveDisabled: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return true
        }
        return description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                        .accessibilityLabel("Expense description")
                        .accessibilityIdentifier("AddExpenseView-DescriptionField")
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Expense amount")
                        .accessibilityIdentifier("AddExpenseView-AmountField")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Expense date")
                        .accessibilityIdentifier("AddExpenseView-DatePicker")
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.all) { category in
                            Text(category.name).tag(category)
                        }
                    }
                    .accessibilityLabel("Expense category")
                    .accessibilityIdentifier("AddExpenseView-CategoryPicker")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .accessibilityIdentifier("AddExpenseView-ErrorMessage")
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        AddExpenseAudit.record(action: "Cancel")
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding expense")
                    .accessibilityIdentifier("AddExpenseView-CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(isSaveDisabled)
                    .accessibilityLabel("Save expense")
                    .accessibilityIdentifier("AddExpenseView-SaveButton")
                }
            }
            .alert(isPresented: Binding(get: { showUndo }, set: { showUndo = $0 })) {
                Alert(
                    title: Text("Expense Saved"),
                    message: Text("Expense was saved successfully."),
                    primaryButton: .default(Text("Undo"), action: undoLastSave),
                    secondaryButton: .cancel(Text("OK"))
                )
            }
        }
    }

    private func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount."
            return
        }
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Description is required."
            return
        }
        errorMessage = nil
        AddExpenseAudit.record(action: "Save", description: description, amount: amountValue, date: date, category: selectedCategory.name)
        onSave?(description, amountValue, date, selectedCategory)
        lastSavedExpense = (description, amountValue, date, selectedCategory)
        showUndo = true
        // Note: You can call dismiss() here if you don't want to show undo
    }

    private func undoLastSave() {
        if let last = lastSavedExpense {
            AddExpenseAudit.record(action: "UndoSave", description: last.0, amount: last.1, date: last.2, category: last.3.name)
            // If your system allows, implement undo logic for the last expense (e.g., remove it from storage)
            lastSavedExpense = nil
        }
        dismiss()
    }
}

#if DEBUG
struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView { description, amount, date, category in
            print("Expense saved: \(description), \(amount), \(date), \(category.name)")
        }
    }
}
#endif
