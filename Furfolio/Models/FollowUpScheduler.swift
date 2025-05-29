//
//  FollowUpScheduler.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData
import os

/// Schedules automated follow-up tasks after each completed appointment.
final class FollowUpScheduler {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FollowUpScheduler")
    /// Shared singleton instance
    static let shared = FollowUpScheduler()
    private init() {}

    /// Default number of days after an appointment to schedule a follow-up
    private let defaultOffsetDays = 10

    /// Schedule a follow-up task for the given appointment.
    ///
    /// - Parameters:
    ///   - appointment: The completed Appointment instance.
    ///   - daysAfter: Optional custom offset days. If nil, uses `defaultOffsetDays`.
    ///   - context: The SwiftData `ModelContext` to insert the task into.
    func scheduleFollowUp(
        for appointment: Appointment,
        daysAfter: Int? = nil,
        in context: ModelContext
    ) {
        let offsetDays = daysAfter ?? defaultOffsetDays
        logger.log("Scheduling follow-up for appointment \(appointment.id) in \(offsetDays) days")
        // Compute follow-up date
        let offset = offsetDays
        guard let followUpDate = Calendar.current.date(byAdding: .day, value: offset, to: appointment.date) else {
            return
        }

        // Create and insert a ScheduledTask
        let task = ScheduledTask(
            id: UUID(),
            title: "Check in with \(appointment.owner.name)",
            dueDate: followUpDate,
            isCompleted: false,
            relatedAppointmentID: appointment.id
        )
        do {
            context.insert(task)
            try context.save()
            logger.log("Inserted ScheduledTask id: \(task.id), dueDate: \(followUpDate)")
        } catch {
            logger.error("Failed to save ScheduledTask: \(error.localizedDescription)")
        }

        // Register a local notification
        ReminderScheduler.shared.scheduleNotification(for: task)
        logger.log("Registered follow-up notification for task id: \(task.id)")
    }

    /// Cancel all follow-up tasks related to the given appointment.
    ///
    /// - Parameters:
    ///   - appointment: The Appointment whose follow-ups should be canceled.
    ///   - context: The SwiftData `ModelContext` to delete tasks from.
    func cancelFollowUps(for appointment: Appointment, in context: ModelContext) {
        logger.log("Cancelling follow-ups for appointment \(appointment.id)")
        let predicate = #Predicate<ScheduledTask> { $0.relatedAppointmentID == appointment.id }
        let request = FetchDescriptor<ScheduledTask>(predicate: predicate)

        let tasks = (try? context.fetch(request)) ?? []
        logger.log("Found \(tasks.count) follow-up tasks to cancel")
        for task in tasks {
            context.delete(task)
        }
        do {
            try context.save()
            logger.log("Cancelled and removed follow-up tasks for appointment \(appointment.id)")
        } catch {
            logger.error("Failed to delete ScheduledTasks: \(error.localizedDescription)")
        }
    }
}
