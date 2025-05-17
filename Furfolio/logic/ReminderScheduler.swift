//
//  ReminderScheduler.swift
//  Furfolio
//
//  Created by ChatGPT on 05/22/2025.
//  Updated on 07/08/2025 — added static helpers to match Appointment APIs.
//

import Foundation
import UserNotifications
import os.log

@MainActor
/// Schedules, cancels, and reschedules local notifications for appointments.
struct ReminderScheduler {
    // MARK: — Dependencies
    
    private let center: UNUserNotificationCenter
    /// Shared calendar to compute trigger dates.
    private static let calendar = Calendar.current
    private let logger = Logger(subsystem: "com.yourapp.furfolio", category: "ReminderScheduler")
    
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }
    
    
    // MARK: — Convenience for Appointment
    
    /// Schedules a reminder notification for the given appointment with a specified offset.
    static func scheduleReminder(for appointment: Appointment, offset: Int) {
        let body = appointment.notes?.isEmpty == false
            ? appointment.notes!
            : "You have an appointment at \(appointment.formattedDate)."
        
        ReminderScheduler().schedule(
          appointmentID: appointment.id.uuidString,
          at: appointment.date,
          offsetMinutes: offset,
          title: "Upcoming Appointment",
          body: body,
          category: Appointment.notificationCategory
        ) { result in
          switch result {
          case .success: break
          case .failure(let err):
            // if needed, log or handle error
            print("🔔 Failed to schedule for \(appointment.id):", err)
          }
        }
    }
    
    /// Cancels any pending reminder notification for the given appointment.
    static func cancelReminder(for appointment: Appointment) {
      ReminderScheduler().cancel(appointmentID: appointment.id.uuidString)
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
    
    
    // MARK: — Cancel
    
    func cancel(
        appointmentID: String,
        completion: (() -> Void)? = nil
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [appointmentID])
        logger.debug("Canceled reminder \(appointmentID)")
        completion?()
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
