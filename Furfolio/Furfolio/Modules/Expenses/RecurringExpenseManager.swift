//
//  RecurringExpenseManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Recurring Expense Manager
//

import Foundation

// MARK: - RecurringExpense Frequency Enum
enum RecurringExpenseFrequency: String, Codable, CaseIterable {
    case daily, weekly, biweekly, monthly, quarterly, yearly

    var description: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - RecurringExpense Model
struct RecurringExpense: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var amount: Double
    var startDate: Date
    var frequency: RecurringExpenseFrequency
    var notes: String?
    var lastGeneratedDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        startDate: Date,
        frequency: RecurringExpenseFrequency,
        notes: String? = nil,
        lastGeneratedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.startDate = startDate
        self.frequency = frequency
        self.notes = notes
        self.lastGeneratedDate = lastGeneratedDate
    }
}

// MARK: - Audit/Event Logging

fileprivate struct RecurringExpenseAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let expenseID: UUID?
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[RecurringExpenseManager] \(action): \(details)\(expenseID != nil ? " (\(expenseID!.uuidString))" : "") at \(dateStr)"
    }
}
fileprivate final class RecurringExpenseAudit {
    static private(set) var log: [RecurringExpenseAuditEvent] = []
    static func record(action: String, expenseID: UUID? = nil, details: String = "") {
        let event = RecurringExpenseAuditEvent(timestamp: Date(), action: action, expenseID: expenseID, details: details)
        log.append(event)
        if log.count > 80 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum RecurringExpenseAuditAdmin {
    public static func lastSummary() -> String { RecurringExpenseAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { RecurringExpenseAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 10) -> [String] { RecurringExpenseAudit.recentSummaries(limit: limit) }
}

// MARK: - RecurringExpenseManager
final class RecurringExpenseManager: ObservableObject {
    @Published private(set) var recurringExpenses: [RecurringExpense] = []
    @Published var lastDeleted: (expense: RecurringExpense, index: Int)?
    @Published var showUndo: Bool = false

    // MARK: - Add Recurring Expense
    func addRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.append(expense)
        RecurringExpenseAudit.record(action: "Add", expenseID: expense.id, details: "Added \(expense.name)")
        save()
    }

    // MARK: - Remove Recurring Expense (with undo support)
    func removeRecurringExpense(_ expense: RecurringExpense) {
        if let idx = recurringExpenses.firstIndex(where: { $0.id == expense.id }) {
            lastDeleted = (recurringExpenses[idx], idx)
            recurringExpenses.remove(at: idx)
            showUndo = true
            RecurringExpenseAudit.record(action: "Delete", expenseID: expense.id, details: "Deleted \(expense.name)")
            save()
        }
    }

    func undoDelete() {
        if let last = lastDeleted {
            recurringExpenses.insert(last.expense, at: last.index)
            RecurringExpenseAudit.record(action: "UndoDelete", expenseID: last.expense.id, details: "Restored \(last.expense.name)")
            lastDeleted = nil
            showUndo = false
            save()
        }
    }

    // MARK: - Update Recurring Expense
    func updateRecurringExpense(_ expense: RecurringExpense) {
        if let idx = recurringExpenses.firstIndex(where: { $0.id == expense.id }) {
            recurringExpenses[idx] = expense
            RecurringExpenseAudit.record(action: "Update", expenseID: expense.id, details: "Updated \(expense.name)")
            save()
        }
    }

    // MARK: - Generate Due Expenses
    /// Call this daily (or on app launch) to get all due expenses for today
    func generateDueExpenses(for date: Date = Date()) -> [RecurringExpense] {
        var dueExpenses: [RecurringExpense] = []
        let calendar = Calendar.current

        for var expense in recurringExpenses {
            let nextDueDate = self.nextDueDate(for: expense)
            // Only generate if today is the due date or it's past due
            if let nextDue = nextDueDate, calendar.isDate(nextDue, inSameDayAs: date) || (nextDue < date) {
                dueExpenses.append(expense)
                // Update the lastGeneratedDate so we don't double-generate
                expense.lastGeneratedDate = date
                updateRecurringExpense(expense)
                RecurringExpenseAudit.record(action: "GenerateDue", expenseID: expense.id, details: "Generated due expense: \(expense.name)")
            }
        }
        RecurringExpenseAudit.record(action: "GenerateAllDue", details: "Generated \(dueExpenses.count) due expenses for \(date)")
        return dueExpenses
    }

    // MARK: - Calculate Next Due Date for a Recurring Expense
    func nextDueDate(for expense: RecurringExpense) -> Date? {
        let calendar = Calendar.current
        let fromDate = expense.lastGeneratedDate ?? expense.startDate
        switch expense.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: fromDate)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: fromDate)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: fromDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: fromDate)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: fromDate)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: fromDate)
        }
    }

    // MARK: - Load & Save (ready for async cloud/SwiftData/local storage)
    func load() {
        // Load recurringExpenses from storage if needed
        RecurringExpenseAudit.record(action: "Load", details: "Loaded recurring expenses")
    }

    func save() {
        // Save recurringExpenses to storage if needed
        RecurringExpenseAudit.record(action: "Save", details: "Saved recurring expenses (\(recurringExpenses.count) items)")
    }
}

// MARK: - Example Usage (remove or wrap in #if DEBUG as needed)
#if DEBUG
extension RecurringExpenseManager {
    static var example: RecurringExpenseManager {
        let manager = RecurringExpenseManager()
        manager.addRecurringExpense(
            RecurringExpense(
                name: "Shop Rent",
                amount: 1200,
                startDate: Date().addingTimeInterval(-60*60*24*30),
                frequency: .monthly,
                notes: "Main location"
            )
        )
        manager.addRecurringExpense(
            RecurringExpense(
                name: "Software Subscription",
                amount: 30,
                startDate: Date().addingTimeInterval(-60*60*24*14),
                frequency: .monthly,
                notes: "Grooming app tools"
            )
        )
        return manager
    }
}
#endif
