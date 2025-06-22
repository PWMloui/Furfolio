//
//  RecurringExpenseManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - RecurringExpense Frequency Enum
enum RecurringExpenseFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

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

// MARK: - RecurringExpenseManager
final class RecurringExpenseManager: ObservableObject {
    @Published private(set) var recurringExpenses: [RecurringExpense] = []

    // MARK: - Add Recurring Expense
    func addRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.append(expense)
    }

    // MARK: - Remove Recurring Expense
    func removeRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.removeAll { $0.id == expense.id }
    }

    // MARK: - Update Recurring Expense
    func updateRecurringExpense(_ expense: RecurringExpense) {
        if let idx = recurringExpenses.firstIndex(where: { $0.id == expense.id }) {
            recurringExpenses[idx] = expense
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
            }
        }
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

    // MARK: - Load & Save (Placeholder - Replace with SwiftData/Storage)
    func load() {
        // Load recurringExpenses from storage if needed
    }

    func save() {
        // Save recurringExpenses to storage if needed
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
