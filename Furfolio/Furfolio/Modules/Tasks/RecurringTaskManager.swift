//
//  RecurringTaskManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Robust Recurring Task Manager
//

import Foundation

// MARK: - Recurrence Rule

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

// MARK: - Recurring Task

struct RecurringTask: Identifiable, Codable, Equatable {
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

// MARK: - Recurring Task Manager

class RecurringTaskManager: ObservableObject {
    @Published private(set) var tasks: [RecurringTask] = []

    // Audit log for admin/QA/debug
    static private(set) var auditLog: [RecurringTaskAuditEvent] = []

    // MARK: - Add Task (with duplicate prevention)
    func addTask(_ task: RecurringTask) {
        guard !tasks.contains(where: { $0.title == task.title && Calendar.current.isDate($0.dueDate, inSameDayAs: task.dueDate) }) else {
            Self.recordAudit(.init(action: "AddFailed", detail: "Duplicate '\(task.title)' for \(task.dueDate)"))
            return
        }
        tasks.append(task)
        Self.recordAudit(.init(action: "Add", detail: task.title))
    }

    // MARK: - Bulk Add (for import/onboarding)
    func addTasks(_ newTasks: [RecurringTask]) {
        for task in newTasks { addTask(task) }
        Self.recordAudit(.init(action: "BulkAdd", detail: "Count=\(newTasks.count)"))
    }

    // MARK: - Mark Task as Completed and Schedule Next
    func completeTask(_ task: RecurringTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted = true
        Self.recordAudit(.init(action: "Complete", detail: task.title))
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
            Self.recordAudit(.init(action: "GenerateNext", detail: "\(task.title) -> \(nextDate)"))
        }
    }

    // MARK: - Bulk Complete
    func completeTasks(_ tasksToComplete: [RecurringTask]) {
        for task in tasksToComplete { completeTask(task) }
        Self.recordAudit(.init(action: "BulkComplete", detail: "Count=\(tasksToComplete.count)"))
    }

    // MARK: - Undo Complete (reactivate a task)
    func undoComplete(_ task: RecurringTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted = false
        Self.recordAudit(.init(action: "UndoComplete", detail: task.title))
    }

    // MARK: - Generate Next Occurrence
    func nextOccurrence(for task: RecurringTask) -> Date? {
        switch task.recurrence {
        case .none: return nil
        case .daily: return Calendar.current.date(byAdding: .day, value: 1, to: task.dueDate)
        case .weekly: return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: task.dueDate)
        case .monthly: return Calendar.current.date(byAdding: .month, value: 1, to: task.dueDate)
        }
    }

    // MARK: - Delete Task
    func deleteTask(_ task: RecurringTask) {
        tasks.removeAll { $0.id == task.id }
        Self.recordAudit(.init(action: "Delete", detail: task.title))
    }

    // MARK: - Bulk Delete
    func deleteTasks(_ toDelete: [RecurringTask]) {
        for task in toDelete { deleteTask(task) }
        Self.recordAudit(.init(action: "BulkDelete", detail: "Count=\(toDelete.count)"))
    }

    // MARK: - Undo Delete (optional, if keeping deleted buffer)
    private var deletedBuffer: [RecurringTask] = []
    func deleteTaskWithUndo(_ task: RecurringTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            deletedBuffer.append(tasks[idx])
            tasks.remove(at: idx)
            Self.recordAudit(.init(action: "DeleteWithUndo", detail: task.title))
        }
    }
    func undoLastDelete() {
        guard let last = deletedBuffer.popLast() else { return }
        addTask(last)
        Self.recordAudit(.init(action: "UndoDelete", detail: last.title))
    }

    // MARK: - Edit Task
    func updateTask(_ task: RecurringTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        Self.recordAudit(.init(action: "Update", detail: task.title))
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

    // MARK: - Audit/Event Logging

    struct RecurringTaskAuditEvent: Codable {
        let timestamp: Date = Date()
        let action: String
        let detail: String
        var summary: String {
            let df = DateFormatter()
            df.dateStyle = .short; df.timeStyle = .short
            return "[RecurringTaskManager] \(action): \(detail) at \(df.string(from: timestamp))"
        }
    }

    static func recordAudit(_ event: RecurringTaskAuditEvent) {
        auditLog.append(event)
        if auditLog.count > 50 { auditLog.removeFirst() }
    }
    static func recentAuditSummaries(limit: Int = 12) -> [String] {
        auditLog.suffix(limit).map { $0.summary }
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
