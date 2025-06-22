//
//  RecurringTaskManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Represents the recurrence rule for a task (daily, weekly, monthly).
enum RecurrenceRule: String, Codable, CaseIterable {
    case none
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

/// A struct for a recurring task. Add more fields as needed.
struct RecurringTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var recurrence: RecurrenceRule
    var isCompleted: Bool

    init(title: String, notes: String = "", dueDate: Date, recurrence: RecurrenceRule, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.isCompleted = isCompleted
    }
}

class RecurringTaskManager: ObservableObject {
    @Published private(set) var tasks: [RecurringTask] = []

    // MARK: - Add Task
    func addTask(_ task: RecurringTask) {
        tasks.append(task)
    }

    // MARK: - Mark Task as Completed and Schedule Next
    func completeTask(_ task: RecurringTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted = true

        // If task is recurring, generate the next occurrence
        if let nextDate = nextOccurrence(for: task) {
            let nextTask = RecurringTask(
                title: task.title,
                notes: task.notes,
                dueDate: nextDate,
                recurrence: task.recurrence,
                isCompleted: false
            )
            addTask(nextTask)
        }
    }

    // MARK: - Generate Next Occurrence
    func nextOccurrence(for task: RecurringTask) -> Date? {
        switch task.recurrence {
        case .none:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: 1, to: task.dueDate)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: task.dueDate)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: task.dueDate)
        }
    }

    // MARK: - Delete Task
    func deleteTask(_ task: RecurringTask) {
        tasks.removeAll { $0.id == task.id }
    }

    // MARK: - Edit Task
    func updateTask(_ task: RecurringTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }

    // MARK: - Fetch Upcoming Tasks
    func upcomingTasks(from date: Date = Date()) -> [RecurringTask] {
        tasks.filter { $0.dueDate >= date && !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Fetch Overdue Tasks
    func overdueTasks(asOf date: Date = Date()) -> [RecurringTask] {
        tasks.filter { $0.dueDate < date && !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

#if DEBUG
// MARK: - Preview Mock
extension RecurringTaskManager {
    static func mock() -> RecurringTaskManager {
        let manager = RecurringTaskManager()
        manager.addTask(RecurringTask(title: "Call supplier", dueDate: Date().addingTimeInterval(-3600), recurrence: .weekly))
        manager.addTask(RecurringTask(title: "Inventory Check", dueDate: Date().addingTimeInterval(3600*5), recurrence: .daily))
        return manager
    }
}
#endif
