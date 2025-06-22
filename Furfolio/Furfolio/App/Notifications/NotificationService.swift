//
//  NotificationService.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated and enhanced by ChatGPT on 6/21/25.
//

import Foundation
import UserNotifications
import OSLog
import SwiftUI

/**
 NotificationService is a centralized, unified notification management service designed for the multi-platform Furfolio app ecosystem.

 Architecturally, it serves as the single source of truth for scheduling, managing, and auditing local notifications across iOS, macOS, and other supported platforms.
 This service is built with extensibility in mind, providing hooks for future Trust Center integrations and audit logging to support security, privacy, and operational transparency.
 */
final class NotificationService: ObservableObject {

    static let shared = NotificationService()
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.furfolio.notification", category: "audit")

    @Published var lastError: Error?

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - Authorization

    func requestAuthorization(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    completion?(.failure(error))
                    self?.logNotificationEvent("Authorization request failed: \(error.localizedDescription)")
                    return
                }

                if !granted {
                    let denial = NSError(domain: "NotificationService", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("Notification permission was denied by the user.", comment: "")
                    ])
                    self?.lastError = denial
                    completion?(.failure(denial))
                    self?.logNotificationEvent("Authorization denied by user.")
                    return
                }

                self?.lastError = nil
                completion?(.success(true))
                self?.logNotificationEvent("Authorization granted.")
            }
        }
    }

    // MARK: - Scheduling

    func scheduleNotification(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        at date: Date,
        sound: UNNotificationSound = .default,
        categoryIdentifier: String? = nil,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    completion?(.failure(error))
                    self?.logNotificationEvent("Failed to schedule notification \(id): \(error.localizedDescription)")
                } else {
                    self?.lastError = nil
                    completion?(.success(()))
                    self?.logNotificationEvent("Scheduled notification \(id) for \(date).")
                }
            }
        }
    }

    func scheduleNotifications(
        _ notifications: [NotificationConfig],
        completion: ((Result<Void, [Error]>) -> Void)? = nil
    ) {
        let group = DispatchGroup()
        var errors: [Error] = []

        for config in notifications {
            group.enter()
            scheduleNotification(
                id: config.id,
                title: config.title,
                body: config.body,
                at: config.date,
                sound: config.sound,
                categoryIdentifier: config.categoryIdentifier
            ) { result in
                if case .failure(let error) = result {
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            if errors.isEmpty {
                self?.lastError = nil
                completion?(.success(()))
                self?.logNotificationEvent("Batch scheduling completed successfully for \(notifications.count) notifications.")
            } else {
                let aggregate = NSError(domain: "NotificationService.BatchScheduling", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("One or more notifications failed to schedule.", comment: ""),
                    "errors": errors
                ])
                self?.lastError = aggregate
                completion?(.failure(errors))
                self?.logNotificationEvent("Batch scheduling completed with errors: \(errors.map { $0.localizedDescription }.joined(separator: "; "))")
            }
        }
    }

    // MARK: - Cancellation

    func cancelNotification(id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        logNotificationEvent("Cancelled notification \(id).")
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        logNotificationEvent("Cancelled all pending notifications.")
    }

    // MARK: - Querying

    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Logging

    private func logNotificationEvent(_ message: String) {
        logger.info("\(message, privacy: .public)")
        #if DEBUG
        print("📡 NotificationService AUDIT: \(message)")
        #endif
    }

    // MARK: - NotificationConfig Struct

    /// A configuration model that defines a notification's content and delivery time.
    struct NotificationConfig {
        let id: String
        let title: String
        let body: String
        let date: Date
        let sound: UNNotificationSound
        let categoryIdentifier: String?

        init(
            id: String = UUID().uuidString,
            title: String,
            body: String,
            date: Date,
            sound: UNNotificationSound = .default,
            categoryIdentifier: String? = nil
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.date = date
            self.sound = sound
            self.categoryIdentifier = categoryIdentifier
        }
    }
}

// MARK: - Example Usage

/*
 // Request notification authorization with error handling
 NotificationService.shared.requestAuthorization { result in
     switch result {
     case .success(let granted):
         if granted {
             // Schedule a notification 10 minutes before an appointment
             guard let appointmentDate = appointment.date,
                   let notificationDate = Calendar.current.date(byAdding: .minute, value: -10, to: appointmentDate) else {
                 print("Invalid appointment date")
                 return
             }
             
             NotificationService.shared.scheduleNotification(
                 id: appointment.id.uuidString,
                 title: NSLocalizedString("Upcoming Appointment", comment: "Notification title"),
                 body: String(format: NSLocalizedString("You have an appointment for %@ soon.", comment: "Notification body"), appointment.dog?.name ?? NSLocalizedString("a pet", comment: "Default pet name")),
                 at: notificationDate,
                 categoryIdentifier: "APPOINTMENT_REMINDER"
             ) { scheduleResult in
                 switch scheduleResult {
                 case .success():
                     print("Notification scheduled successfully.")
                 case .failure(let error):
                     print("Failed to schedule notification: \(error.localizedDescription)")
                 }
             }
         } else {
             print("User denied notification permissions.")
         }
     case .failure(let error):
         print("Authorization request failed: \(error.localizedDescription)")
     }
 }
 
 // Batch scheduling example
 let notifications = [
     NotificationService.NotificationConfig(
         id: "task1",
         title: NSLocalizedString("Task Reminder", comment: ""),
         body: NSLocalizedString("Don't forget to complete your task.", comment: ""),
         date: Date().addingTimeInterval(3600),
         categoryIdentifier: "TASK_REMINDER"
     ),
     NotificationService.NotificationConfig(
         title: NSLocalizedString("Follow-up", comment: ""),
         body: NSLocalizedString("Please follow up with your client.", comment: ""),
         date: Date().addingTimeInterval(7200)
     )
 ]
 
 NotificationService.shared.scheduleNotifications(notifications) { result in
     switch result {
     case .success():
         print("All notifications scheduled successfully.")
     case .failure(let errors):
         for error in errors {
             print("Error scheduling notification: \(error.localizedDescription)")
         }
     }
 }
*/
