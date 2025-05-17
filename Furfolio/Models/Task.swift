//
//  Task.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 23, 2025 — removed dynamic defaults from attributes and moved them into init.
//                         Jul 11, 2025 — added fetch helpers, reminder scheduling, and richer computed props.
//

import Foundation
import SwiftData
// TODO: Consider injecting UNUserNotificationCenter and Calendar for testability and centralizing reminder logic.
import UserNotifications

/// Model representing a user task with scheduling, reminders, and status helpers.
@MainActor
@Model
final class Task: Identifiable, Hashable, CustomStringConvertible {
    /// Shared date formatter for dueDateFormatted.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    /// Shared relative date formatter for dueDateRelative.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    /// Shared calendar for date calculations.
    private static let calendar = Calendar.current

    // MARK: – Persistent Properties

    @Attribute               var id: UUID
    @Attribute               var title: String
    @Attribute               var details: String?
    @Attribute               var dueDate: Date?
    @Attribute               var isCompleted: Bool
    @Attribute               var createdAt: Date
    @Attribute               var updatedAt: Date?
    @Attribute               var priority: TaskPriority
    @Relationship(deleteRule: .nullify)
    var owner: DogOwner?

    // MARK: – Init

    /// Initializes a new Task with sanitized inputs.
    init(
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        owner: DogOwner? = nil
    ) {
        self.id          = UUID()
        self.title       = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details     = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dueDate     = dueDate
        self.isCompleted = isCompleted
        self.createdAt   = Date.now
        self.updatedAt   = nil
        self.priority    = priority
        self.owner       = owner
    }

    // MARK: – Computed Properties

    @Transient
    /// Formatted like “May 17, 3:00 PM”
    var dueDateFormatted: String? {
        guard let d = dueDate else { return nil }
        return Task.dateFormatter.string(from: d)
    }

    @Transient
    /// “in 2 days” or “yesterday”
    var dueDateRelative: String? {
        guard let d = dueDate else { return nil }
        return Task.relativeFormatter.localizedString(for: d, relativeTo: Date.now)
    }

    @Transient
    /// True if past due and not yet completed
    var isOverdue: Bool {
        guard let d = dueDate else { return false }
        return !isCompleted && d < Date.now
    }

    @Transient
    /// True if due today
    var isDueToday: Bool {
        guard let d = dueDate else { return false }
        return Task.calendar.isDateInToday(d)
    }

    /// Emoji icon for priority
    var priorityIcon: String { priority.icon }

    @Transient
    /// A one-line summary
    var summary: String {
        var parts: [String] = ["\(priorityIcon) \(title)"]
        if let dto = dueDateFormatted {
            parts.append("Due: \(dto)")
        }
        if isCompleted {
            parts.append("✅")
        } else if isOverdue {
            parts.append("⚠️ Overdue")
        }
        return parts.joined(separator: " • ")
    }

    // MARK: – Actions

    /// Marks the task as completed and updates timestamp.
    func markCompleted() {
        guard !isCompleted else { return }
        isCompleted = true
        updatedAt = Date.now
    }

    /// Reschedules the task to a new date and updates timestamp.
    func reschedule(to newDate: Date) {
        dueDate = newDate
        updatedAt = Date.now
    }

    /// Updates task properties with trimmed inputs and stamps updatedAt.
    func update(
        title: String? = nil,
        details: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority? = nil
    ) {
        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            self.title = t
        }
        if let d = details?.trimmingCharacters(in: .whitespacesAndNewlines) {
            self.details = d
        }
        if let date = dueDate {
            self.dueDate = date
        }
        if let p = priority {
            self.priority = p
        }
        updatedAt = Date.now
    }

    // MARK: – Reminder Scheduling

    /// Schedules a local notification reminder before task is due.
    func scheduleReminder(minutesBefore: Int = 30) {
        guard let due = dueDate else { return }
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: due) ?? due

        let content = UNMutableNotificationContent()
        content.title = "Task Due Soon"
        content.body  = title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending local notification reminders for this task.
    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    // MARK: – Fetch Helpers

    /// Fetches all tasks sorted by due date and priority.
    static func fetchAll(in context: ModelContext) -> [Task] {
        let desc = FetchDescriptor<Task>(
            sortBy: [
                SortDescriptor(\.dueDate, order: .forward),
                SortDescriptor(\.priority, order: .forward)
            ]
        )
        return (try? context.fetch(desc)) ?? []
    }

    /// Fetches all pending (not completed) tasks.
    static func fetchPending(in context: ModelContext) -> [Task] {
        let desc = FetchDescriptor<Task>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        return (try? context.fetch(desc)) ?? []
    }

    /// Fetches all completed tasks.
    static func fetchCompleted(in context: ModelContext) -> [Task] {
        let desc = FetchDescriptor<Task>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [ SortDescriptor(\.updatedAt, order: .reverse) ]
        )
        return (try? context.fetch(desc)) ?? []
    }

    /// Fetches all overdue tasks.
    static func fetchOverdue(in context: ModelContext) -> [Task] {
        let desc = FetchDescriptor<Task>(
            predicate: #Predicate { !$0.isCompleted && ($0.dueDate ?? .distantPast) < Date.now },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        return (try? context.fetch(desc)) ?? []
    }

    /// Fetches tasks due between the start of today and tomorrow.
    static func fetchDueToday(in context: ModelContext) -> [Task] {
        let start = Self.calendar.startOfDay(for: Date.now)
        guard let end = Self.calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let desc = FetchDescriptor<Task>(
            predicate: #Predicate {
                guard let d = $0.dueDate else { return false }
                return d >= start && d < end
            },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        return (try? context.fetch(desc)) ?? []
    }

    /// Creates and inserts a new Task into the context.
    @discardableResult
    static func create(
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        owner: DogOwner? = nil,
        in context: ModelContext
    ) -> Task {
        let t = Task(title: title, details: details, dueDate: dueDate, priority: priority, owner: owner)
        context.insert(t)
        return t
    }

    // MARK: – Hashable

    static func == (lhs: Task, rhs: Task) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: – CustomStringConvertible

    var description: String { summary }
}
