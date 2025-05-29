import Foundation
import SwiftData
import os

@Model
final class ScheduledTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var appointmentID: UUID
    var dueDate: Date
    var createdAt: Date
    var updatedAt: Date
    @Transient private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
    
    /// Initializes a scheduled follow-up task.
    init(id: UUID = UUID(), appointmentID: UUID, dueDate: Date) {
        self.id = id
        self.appointmentID = appointmentID
        self.dueDate = dueDate
        let now = Date.now
        self.createdAt = now
        self.updatedAt = now
        logger.log("Initialized ScheduledTask id: \(id), appointmentID: \(appointmentID), dueDate: \(dueDate)")
    }
    
    /// Marks the task as completed by updating its timestamp.
    func markCompleted() {
        updatedAt = Date.now
        logger.log("Marked ScheduledTask \(id) as completed at \(updatedAt)")
    }
    
    /// Updates the due date of the task.
    func reschedule(to newDate: Date) {
        logger.log("Rescheduling ScheduledTask \(id) from \(dueDate) to \(newDate)")
        dueDate = newDate
        updatedAt = Date.now
        logger.log("Rescheduled ScheduledTask \(id) at \(updatedAt)")
    }
    
    /// Cancels this task by deleting it from the provided context.
    func cancel(in context: ModelContext) {
        logger.log("Cancelling ScheduledTask \(id)")
        context.delete(self)
        do {
            try context.save()
            logger.log("Deleted ScheduledTask \(id)")
        } catch {
            logger.error("Failed to delete ScheduledTask \(id): \(error.localizedDescription)")
        }
    }
    
    /// Fetches all scheduled tasks from the context.
    static func fetchAll(in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Fetching all ScheduledTask entries")
        let descriptor = FetchDescriptor<ScheduledTask>(sortBy: [SortDescriptor(\.dueDate, order: .forward)])
        do {
            let results = try context.fetch(descriptor)
            logger.log("Fetched \(results.count) ScheduledTask entries")
            return results
        } catch {
            logger.error("ScheduledTask.fetchAll failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches tasks due before the specified date.
    static func fetchDue(before date: Date, in context: ModelContext) -> [ScheduledTask] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ScheduledTask")
        logger.log("Fetching ScheduledTask due before: \(date)")
        let descriptor = FetchDescriptor<ScheduledTask>(
            predicate: #Predicate { $0.dueDate <= date },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        do {
            let results = try context.fetch(descriptor)
            logger.log("Fetched \(results.count) due ScheduledTask entries")
            return results
        } catch {
            logger.error("ScheduledTask.fetchDue failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Creates and saves a new ScheduledTask in the given context.
    @discardableResult
    static func create(
        appointmentID: UUID,
        dueDate: Date,
        in context: ModelContext
    ) -> ScheduledTask {
        let task = ScheduledTask(appointmentID: appointmentID, dueDate: dueDate)
        logger.log("Creating ScheduledTask for appointment \(appointmentID) due \(dueDate)")
        context.insert(task)
        do {
            try context.save()
            logger.log("Inserted ScheduledTask id: \(task.id)")
        } catch {
            logger.error("Failed to save ScheduledTask \(task.id): \(error.localizedDescription)")
        }
        return task
    }
}
