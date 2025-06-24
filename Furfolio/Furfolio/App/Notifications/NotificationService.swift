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

// TODO: Any UI related to notification banners should use AppColors, AppFonts, and AppSpacing tokens for consistent design.

/**
 NotificationService is a centralized, unified notification management service designed for the multi-platform Furfolio app ecosystem.

 Architecturally, it serves as the single source of truth for scheduling, managing, and auditing local notifications across iOS, macOS, and other supported platforms.
 This service is built with extensibility in mind, providing hooks for future Trust Center integrations and audit logging to support security, privacy, and operational transparency.
 */

/// Service for handling in-app and local notifications.
/// Centralizes scheduling, canceling, and business/audit logic.
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    private init() {}

    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Furfolio", category: "NotificationService")

    @Published private(set) var lastError: Error?

    // MARK: - Authorization

    /// Requests user authorization for notifications.
    /// - Parameter completion: Completion handler with Result indicating success or failure.
    func requestAuthorization(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    completion?(.failure(error))
                    self?.logNotificationEvent(NSLocalizedString("Authorization request failed: \(error.localizedDescription)", comment: "Notification authorization failure message"))
                    return
                }

                if !granted {
                    let denial = NSError(domain: "NotificationService", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("Notification permission was denied by the user.", comment: "User denied notification permission error message")
                    ])
                    self?.lastError = denial
                    completion?(.failure(denial))
                    self?.logNotificationEvent(NSLocalizedString("Authorization denied by user.", comment: "Notification authorization denied log message"))
                    return
                }

                self?.lastError = nil
                completion?(.success(true))
                self?.logNotificationEvent(NSLocalizedString("Authorization granted.", comment: "Notification authorization granted log message"))
            }
        }
    }

    // MARK: - Scheduling

    /// Schedules a local notification.
    /// - Parameters:
    ///   - id: Identifier for the notification (default is a new UUID string).
    ///   - title: Notification title.
    ///   - body: Notification body text.
    ///   - at: Date when the notification should fire.
    ///   - sound: Notification sound, default is `.default`.
    ///   - categoryIdentifier: Optional category identifier for actionable notifications.
    ///   - completion: Completion handler with success or failure result.
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
                    self?.logNotificationEvent(String(format: NSLocalizedString("Failed to schedule notification %@: %@", comment: "Notification scheduling failure log message"), id, error.localizedDescription))
                    // TODO: Integrate error reporting with Trust Center / analytics here.
                } else {
                    self?.lastError = nil
                    completion?(.success(()))
                    self?.logNotificationEvent(String(format: NSLocalizedString("Scheduled notification %@ for %@", comment: "Notification scheduling success log message"), id, date.description))
                    // TODO: Integrate success event reporting with Trust Center / analytics here.
                }
            }
        }
    }

    /// Schedules multiple notifications in batch.
    /// - Parameters:
    ///   - notifications: Array of NotificationConfig objects to schedule.
    ///   - completion: Completion handler with success or failure containing array of errors.
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
                self?.logNotificationEvent(String(format: NSLocalizedString("Batch scheduling completed successfully for %d notifications.", comment: "Batch scheduling success log message"), notifications.count))
                // TODO: Integrate batch success event reporting with Trust Center / analytics here.
            } else {
                let aggregate = NSError(domain: "NotificationService.BatchScheduling", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("One or more notifications failed to schedule.", comment: "Batch scheduling failure error message"),
                    "errors": errors
                ])
                self?.lastError = aggregate
                completion?(.failure(errors))
                self?.logNotificationEvent(String(format: NSLocalizedString("Batch scheduling completed with errors: %@", comment: "Batch scheduling failure log message"), errors.map { $0.localizedDescription }.joined(separator: "; ")))
                // TODO: Integrate batch failure error reporting with Trust Center / analytics here.
            }
        }
    }

    // MARK: - Canceling

    /// Cancels a pending notification by identifier.
    /// - Parameter identifier: The notification identifier to cancel.
    func cancelNotification(with identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        logNotificationEvent(String(format: NSLocalizedString("Canceled notification with identifier %@", comment: "Notification cancellation log message"), identifier))
        // TODO: Integrate cancellation event reporting with Trust Center / analytics here.
    }

    /// Cancels all pending notifications.
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        logNotificationEvent(NSLocalizedString("Canceled all pending notifications.", comment: "All notifications cancellation log message"))
        // TODO: Integrate cancellation event reporting with Trust Center / analytics here.
    }

    // MARK: - Querying

    /// Retrieves all pending notification requests.
    /// - Parameter completion: Completion handler with array of UNNotificationRequest.
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }

    /// Checks the current authorization status for notifications.
    /// - Parameter completion: Completion handler with UNAuthorizationStatus.
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

/**
 Usage Example:

 NotificationService.shared.requestAuthorization { result in
     switch result {
     case .success(let granted):
         guard granted else {
             print(NSLocalizedString("User denied notification permissions.", comment: "User denied notification permission log"))
             return
         }
         let appointmentDate = Date().addingTimeInterval(3600) // Example appointment date one hour from now
         guard let notificationDate = Calendar.current.date(byAdding: .minute, value: -10, to: appointmentDate) else {
             print(NSLocalizedString("Invalid appointment date", comment: "Invalid appointment date error message"))
             return
         }

         NotificationService.shared.scheduleNotification(
             id: UUID().uuidString,
             title: NSLocalizedString("Upcoming Appointment", comment: "Notification title"),
             body: String(format: NSLocalizedString("You have an appointment for %@ soon.", comment: "Notification body"), NSLocalizedString("your pet", comment: "Default pet name")),
             at: notificationDate,
             categoryIdentifier: "APPOINTMENT_REMINDER"
         ) { scheduleResult in
             switch scheduleResult {
             case .success():
                 print(NSLocalizedString("Notification scheduled successfully.", comment: "Notification success message"))
             case .failure(let error):
                 print(String(format: NSLocalizedString("Failed to schedule notification: %@", comment: "Notification failure message"), error.localizedDescription))
             }
         }

     case .failure(let error):
         print(String(format: NSLocalizedString("Authorization request failed: %@", comment: "Authorization failure message"), error.localizedDescription))
     }
 }

 */
