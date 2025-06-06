//
//  ScheduledTask.swift
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
import os

/// Model representing a user task with scheduling, reminders, and status helpers.
@MainActor
@Model
final class ScheduledTask: @preconcurrency Identifiable, Hashable, CustomStringConvertible {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
    /// Notification center, injectable for testing.
    static var notificationCenter: UNUserNotificationCenter = .current()

    /// Calendar provider, injectable for testing.
    static var calendarProvider: Calendar = .current
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
    @Attribute               var reminderOffsetMinutes: Int
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
        owner: DogOwner? = nil,
        reminderOffsetMinutes: Int = 30
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
        self.reminderOffsetMinutes = reminderOffsetMinutes
        logger.log("Initialized ScheduledTask id: \(id), title: '\(title)', dueDate: \(String(describing: dueDate)), priority: \(priority)")
        scheduleReminder()
    }

    // MARK: – Computed Properties

    @Transient
    /// Formatted like “May 17, 3:00 PM”
    var dueDateFormatted: String? {
        logger.log("Computing dueDateFormatted for ScheduledTask id: \(id)")
        guard let d = dueDate else { return nil }
        return ScheduledTask.dateFormatter.string(from: d)
    }

    @Transient
    /// “in 2 days” or “yesterday”
    var dueDateRelative: String? {
        logger.log("Computing dueDateRelative for ScheduledTask id: \(id)")
        guard let d = dueDate else { return nil }
        return ScheduledTask.relativeFormatter.localizedString(for: d, relativeTo: Date.now)
    }

    @Transient
    /// True if past due and not yet completed
    var isOverdue: Bool {
        logger.log("Evaluating isOverdue for ScheduledTask id: \(id)")
        guard let d = dueDate else { return false }
        return !isCompleted && d < Date.now
    }

    @Transient
    /// True if due today
    var isDueToday: Bool {
        logger.log("Evaluating isDueToday for ScheduledTask id: \(id)")
        guard let d = dueDate else { return false }
        return ScheduledTask.calendar.isDateInToday(d)
    }

    /// Emoji icon for priority
    var priorityIcon: String { priority.icon }

    @Transient
    /// A one-line summary
    var summary: String {
        logger.log("Generating summary for ScheduledTask id: \(id)")
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

    @Transient
    /// Description of reminder offset for display
    var reminderOffsetDescription: String {
        logger.log("Accessing reminderOffsetDescription for ScheduledTask id: \(id)")
        "\(reminderOffsetMinutes) min before"
    }

    // MARK: – Actions

    /// Marks the task as completed and updates timestamp.
    func markCompleted() {
        logger.log("Marking ScheduledTask \(id) as completed")
        guard !isCompleted else { return }
        isCompleted = true
        updatedAt = Date.now
        logger.log("ScheduledTask \(id) marked completed at \(updatedAt!)")
    }

    /// Reschedules the task to a new date and updates timestamp.
    func reschedule(to newDate: Date) {
        logger.log("Rescheduling ScheduledTask \(id) to newDate: \(newDate)")
        dueDate = newDate
        updatedAt = Date.now
        logger.log("ScheduledTask \(id) rescheduled at \(updatedAt!)")
        scheduleReminder()
    }

    /// Updates task properties with trimmed inputs and stamps updatedAt.
    func update(
        title: String? = nil,
        details: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority? = nil,
        reminderOffsetMinutes: Int? = nil
    ) {
        logger.log("Updating ScheduledTask \(id) with values title=\(String(describing: title)), details=\(String(describing: details)), dueDate=\(String(describing: dueDate)), priority=\(String(describing: priority)), offset=\(String(describing: reminderOffsetMinutes))")
        var didUpdate = false
        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            self.title = t
            didUpdate = true
        }
        if let d = details?.trimmingCharacters(in: .whitespacesAndNewlines) {
            self.details = d
            didUpdate = true
        }
        if let date = dueDate {
            self.dueDate = date
            didUpdate = true
        }
        if let p = priority {
            self.priority = p
            didUpdate = true
        }
        if let offset = reminderOffsetMinutes, offset != self.reminderOffsetMinutes {
            self.reminderOffsetMinutes = offset
            didUpdate = true
        }
        if didUpdate {
            updatedAt = Date.now
            // Reschedule reminder when due date or offset changes
            scheduleReminder()
            logger.log("ScheduledTask \(id) updated at \(updatedAt!)")
        }
    }

    // MARK: – Reminder Scheduling

    /// Schedules a local notification reminder using the task’s reminderOffsetMinutes.
    func scheduleReminder() {
        scheduleReminder(minutesBefore: reminderOffsetMinutes)
    }

    private func scheduleReminder(minutesBefore: Int) {
        logger.log("Scheduling reminder for ScheduledTask \(id), minutesBefore: \(minutesBefore)")
        guard let due = dueDate else { return }
        let triggerDate = Self.calendarProvider.date(byAdding: .minute, value: -minutesBefore, to: due) ?? due

        let content = UNMutableNotificationContent()
        content.title = "Task Due Soon"
        content.body  = title
        content.sound = .default

        let comps = Self.calendarProvider.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        Self.notificationCenter.add(request)
        logger.log("Registered UNNotificationRequest for ScheduledTask \(id)")
    }

    /// Cancels any pending local notification reminders for this task.
    func cancelReminder() {
        logger.log("Canceling reminder for ScheduledTask \(id)")
        Self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        logger.log("Canceled reminders for ScheduledTask \(id)")
    }

    // MARK: – Fetch Helpers

    /// Fetches all tasks sorted by due date and priority.
    static func fetchAll(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Calling fetchAll")
        let desc = FetchDescriptor<ScheduledTask>(
            sortBy: [
                SortDescriptor(\.dueDate, order: .forward),
                SortDescriptor(\.priority, order: .forward)
            ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) ScheduledTask entries")
        return results
    }

    /// Fetches all pending (not completed) tasks.
    static func fetchPending(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Calling fetchPending")
        let desc = FetchDescriptor<ScheduledTask>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) ScheduledTask entries")
        return results
    }

    /// Fetches all completed tasks.
    static func fetchCompleted(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Calling fetchCompleted")
        let desc = FetchDescriptor<ScheduledTask>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [ SortDescriptor(\.updatedAt, order: .reverse) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) ScheduledTask entries")
        return results
    }

    /// Fetches all overdue tasks.
    static func fetchOverdue(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Calling fetchOverdue")
        let desc = FetchDescriptor<ScheduledTask>(
            predicate: #Predicate { !$0.isCompleted && ($0.dueDate ?? .distantPast) < Date.now },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) ScheduledTask entries")
        return results
    }

    /// Fetches tasks due between the start of today and tomorrow.
    static func fetchDueToday(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Calling fetchDueToday")
        let start = ScheduledTask.calendar.startOfDay(for: Date.now)
        guard let end = ScheduledTask.calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let desc = FetchDescriptor<ScheduledTask>(
            predicate: #Predicate {
                guard let d = $0.dueDate else { return false }
                return d >= start && d < end
            },
            sortBy: [ SortDescriptor(\.dueDate, order: .forward) ]
        )
        let results = (try? context.fetch(desc)) ?? []
        logger.log("Fetched \(results.count) ScheduledTask entries")
        return results
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
    ) -> ScheduledTask {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Creating ScheduledTask with title: \(title)")
        let t = ScheduledTask(title: title, details: details, dueDate: dueDate, priority: priority, owner: owner)
        context.insert(t)
        logger.log("Created ScheduledTask id: \(t.id)")
        t.scheduleReminder()
        logger.log("Created ScheduledTask id: \(t.id)")
        return t
    }

    // MARK: – Hashable

    static func == (lhs: ScheduledTask, rhs: ScheduledTask) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: – CustomStringConvertible

    var description: String { summary }
}
