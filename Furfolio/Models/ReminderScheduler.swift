//
//  ReminderScheduler.swift
//  Furfolio
//
//  Created by ChatGPT on 05/22/2025.
//  Updated on 07/08/2025 — added static helpers to match Appointment APIs.
//


import Foundation
import UserNotifications
import os

/// Schedules, cancels, and reschedules local notifications for appointments.
final class ReminderScheduler {
    /// Shared singleton instance
    static let shared = ReminderScheduler()
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.yourapp.furfolio", category: "ReminderScheduler")
    
    private init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        requestAuthorization()
    }
    
    /// Request notification permissions on first use.
    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Notification auth error: \(error.localizedDescription)")
            } else {
                self.logger.log("Notification authorization granted: \(granted)")
            }
        }
    }
    // MARK: — Dependencies
    
    /// Shared calendar to compute trigger dates.
    private static let calendar = Calendar.current
    
    
    // MARK: — Convenience for Appointment
    
    /// Schedules a reminder notification for the given appointment with a specified offset.
    static func scheduleReminder(for appointment: Appointment, offset: Int) {
        Task {
            do {
                let body = appointment.notes?.isEmpty == false
                    ? appointment.notes!
                    : "You have an appointment at \(appointment.formattedDate)."
                try await ReminderScheduler.shared.scheduleAsync(
                    appointmentID: appointment.id.uuidString,
                    at: appointment.date,
                    offsetMinutes: offset,
                    title: "Upcoming Appointment",
                    body: body,
                    category: Appointment.notificationCategory
                )
            } catch {
                Logger(subsystem: "com.yourapp.furfolio", category: "ReminderScheduler")
                    .error("Failed to schedule async for \(appointment.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Cancels any pending reminder notification for the given appointment.
    static func cancelReminder(for appointment: Appointment) {
        Task {
            await ReminderScheduler.shared.cancelAsync(appointmentID: appointment.id.uuidString)
        }
    }
    
    
    // MARK: — Schedule
    
    func schedule(
        appointmentID: String,
        at date: Date,
        offsetMinutes: Int,
        title: String = "Upcoming Appointment",
        body: String,
        category: String? = nil,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        if let cat = category {
            content.categoryIdentifier = cat
        }
        
        let triggerDate = Self.calendar.date(
          byAdding: .minute,
          value: -offsetMinutes,
          to: date
        ) ?? date
        
        let comps = Self.calendar.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: appointmentID,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let err = error {
                logger.error("Failed to schedule reminder \(appointmentID): \(err.localizedDescription)")
                completion?(.failure(err))
            } else {
                logger.debug("Scheduled reminder \(appointmentID) at \(triggerDate)")
                completion?(.success(()))
            }
        }
    }


    /// Async variant of schedule(...), throwing on error.
    func scheduleAsync(
        appointmentID: String,
        at date: Date,
        offsetMinutes: Int,
        title: String = "Upcoming Appointment",
        body: String,
        category: String? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        if let cat = category {
            content.categoryIdentifier = cat
        }
        let triggerDate = Self.calendar.date(byAdding: .minute, value: -offsetMinutes, to: date) ?? date
        let comps = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: appointmentID, content: content, trigger: trigger)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let err = error {
                    logger.error("Async schedule failed \(appointmentID): \(err.localizedDescription)")
                    continuation.resume(throwing: err)
                } else {
                    logger.debug("Async scheduled \(appointmentID) at \(triggerDate)")
                    continuation.resume()
                }
            }
        }
    }
    
    
    // MARK: — Cancel
    
    func cancel(
        appointmentID: String,
        completion: (() -> Void)? = nil
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [appointmentID])
        logger.debug("Canceled reminder \(appointmentID)")
        completion?()
    }


    /// Async variant of cancel(...).
    func cancelAsync(appointmentID: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [appointmentID])
        logger.debug("Async canceled reminder \(appointmentID)")
    }
    
    
    // MARK: — Reschedule
    
    func reschedule(
        appointmentID: String,
        at date: Date,
        offsetMinutes: Int,
        title: String = "Upcoming Appointment",
        body: String,
        category: String? = nil,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        cancel(appointmentID: appointmentID) {
            schedule(
                appointmentID: appointmentID,
                at: date,
                offsetMinutes: offsetMinutes,
                title: title,
                body: body,
                category: category,
                completion: completion
            )
        }
    }
    
    
    // MARK: — Utilities
    
    func pendingAppointmentIDs(completion: @escaping ([String]) -> Void) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier)
            completion(ids)
        }
    }
}

    /// Cancels all pending reminders.
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
        logger.log("Canceled all reminders")
    }
