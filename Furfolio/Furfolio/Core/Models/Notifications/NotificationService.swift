//
//  NotificationService.swift
//  Furfolio
//
//  Enhanced: Audit/analytics, diagnostics, multi-user, modular, scalable, tokenized, test/preview ready.
//

import Foundation
import UserNotifications
import OSLog
import SwiftUI

// MARK: - Audit/Analytics Protocols

public protocol NotificationAuditLogger {
    func log(event: NotificationAuditEvent) async
}
public struct NullNotificationAuditLogger: NotificationAuditLogger {
    public init() {}
    public func log(event: NotificationAuditEvent) async {}
}
public struct NotificationAuditEvent {
    public let type: String        // e.g. "schedule", "cancel", "error", "requestAuth"
    public let id: String?         // Notification ID if relevant
    public let userID: String?     // For multi-user/business accounts
    public let status: String?     // For auth/schedule status
    public let detail: String?     // Arbitrary extra info
    public let date: Date

    public init(type: String, id: String? = nil, userID: String? = nil, status: String? = nil, detail: String? = nil, date: Date = .init()) {
        self.type = type
        self.id = id
        self.userID = userID
        self.status = status
        self.detail = detail
        self.date = date
    }
}

/// A record of a NotificationService audit event.
public struct NotificationServiceAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: NotificationAuditEvent
    public init(id: UUID = UUID(), timestamp: Date = Date(), event: NotificationAuditEvent) {
        self.id = id; self.timestamp = timestamp; self.event = event
    }
}
/// Manages concurrency-safe audit logging for NotificationService.
public actor NotificationServiceAuditManager {
    private var buffer: [NotificationServiceAuditEntry] = []
    private let maxEntries = 100
    public static let shared = NotificationServiceAuditManager()
    public func add(_ entry: NotificationServiceAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }
    public func recent(limit: Int = 20) -> [NotificationServiceAuditEntry] {
        Array(buffer.suffix(limit))
    }
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

// MARK: - NotificationService

final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    private init() {}

    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Furfolio", category: "NotificationService")

    @Published private(set) var lastError: Error?

    // Inject for compliance/business analytics; preview/test with null logger.
    private let auditLogger: NotificationAuditLogger = NullNotificationAuditLogger()
    private let userID: String? = nil // For multi-user/business, inject this.

    // MARK: - Authorization

    /// Requests user authorization for notifications. Audits and logs for compliance.
    func requestAuthorization(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                let auditEvent = NotificationAuditEvent(
                    type: "requestAuth",
                    userID: self?.userID,
                    status: granted ? "granted" : "denied",
                    detail: error?.localizedDescription
                )
                Task {
                    await self?.auditLogger.log(event: auditEvent)
                    await NotificationServiceAuditManager.shared.add(.init(event: auditEvent))
                }
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

    /// Schedules a local notification and audits/analytics the operation.
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
                let auditEvent = NotificationAuditEvent(
                    type: error == nil ? "schedule" : "error",
                    id: id,
                    userID: self?.userID,
                    status: error == nil ? "scheduled" : "failed",
                    detail: error?.localizedDescription
                )
                Task {
                    await self?.auditLogger.log(event: auditEvent)
                    await NotificationServiceAuditManager.shared.add(.init(event: auditEvent))
                }

                if let error = error {
                    self?.lastError = error
                    completion?(.failure(error))
                    self?.logNotificationEvent(String(format: NSLocalizedString("Failed to schedule notification %@: %@", comment: "Notification scheduling failure log message"), id, error.localizedDescription))
                } else {
                    self?.lastError = nil
                    completion?(.success(()))
                    self?.logNotificationEvent(String(format: NSLocalizedString("Scheduled notification %@ for %@", comment: "Notification scheduling success log message"), id, date.description))
                }
            }
        }
    }

    /// Schedules multiple notifications in batch. Full diagnostics/audit logging for compliance.
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
            let auditEvent = NotificationAuditEvent(
                type: errors.isEmpty ? "batchSchedule" : "batchError",
                userID: self?.userID,
                status: errors.isEmpty ? "allScheduled" : "partialFailure",
                detail: errors.map { $0.localizedDescription }.joined(separator: "; ")
            )
            Task {
                await self?.auditLogger.log(event: auditEvent)
                await NotificationServiceAuditManager.shared.add(.init(event: auditEvent))
            }

            if errors.isEmpty {
                self?.lastError = nil
                completion?(.success(()))
                self?.logNotificationEvent(String(format: NSLocalizedString("Batch scheduling completed successfully for %d notifications.", comment: "Batch scheduling success log message"), notifications.count))
            } else {
                let aggregate = NSError(domain: "NotificationService.BatchScheduling", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("One or more notifications failed to schedule.", comment: "Batch scheduling failure error message"),
                    "errors": errors
                ])
                self?.lastError = aggregate
                completion?(.failure(errors))
                self?.logNotificationEvent(String(format: NSLocalizedString("Batch scheduling completed with errors: %@", comment: "Batch scheduling failure log message"), errors.map { $0.localizedDescription }.joined(separator: "; ")))
            }
        }
    }

    // MARK: - Canceling

    func cancelNotification(with identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task {
            await auditLogger.log(event: NotificationAuditEvent(
                type: "cancel",
                id: identifier,
                userID: userID,
                status: "cancelled"
            ))
            await NotificationServiceAuditManager.shared.add(.init(event: NotificationAuditEvent(
                type: "cancel",
                id: identifier,
                userID: userID,
                status: "cancelled"
            )))
        }
        logNotificationEvent(String(format: NSLocalizedString("Canceled notification with identifier %@", comment: "Notification cancellation log message"), identifier))
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        Task {
            await auditLogger.log(event: NotificationAuditEvent(
                type: "cancelAll",
                userID: userID,
                status: "allCancelled"
            ))
            await NotificationServiceAuditManager.shared.add(.init(event: NotificationAuditEvent(
                type: "cancelAll",
                userID: userID,
                status: "allCancelled"
            )))
        }
        logNotificationEvent(NSLocalizedString("Canceled all pending notifications.", comment: "All notifications cancellation log message"))
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

    // MARK: - Diagnostics/Analytics

    /// Diagnostics snapshot: returns a quick summary string for admin/owner panels.
    func diagnosticsSummary(completion: @escaping (String) -> Void) {
        getPendingNotifications { requests in
            let summary = String(format: NSLocalizedString("Pending: %d notification(s)", comment: "Diagnostics summary of notifications"), requests.count)
            completion(summary)
        }
    }

    // MARK: - Logging

    private func logNotificationEvent(_ message: String) {
        logger.info("\(message, privacy: .public)")
        #if DEBUG
        print("📡 NotificationService AUDIT: \(message)")
        #endif
    }

    /// Fetch recent service audit entries asynchronously.
    public func recentAuditEntries(limit: Int = 20) async -> [NotificationServiceAuditEntry] {
        await NotificationServiceAuditManager.shared.recent(limit: limit)
    }
    /// Export service audit log as JSON.
    public func exportAuditLogJSON() async -> String {
        await NotificationServiceAuditManager.shared.exportJSON()
    }

    // MARK: - NotificationConfig Struct

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
         let appointmentDate = Date().addingTimeInterval(3600)
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
