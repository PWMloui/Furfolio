//
//  NotificationManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//


import Foundation
import UserNotifications
import SwiftUI
import SwiftData

/// Types of notification actions.
public enum NotificationAuditAction: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case scheduledDate, scheduledInterval, cancelled, cancelledAll, fetchedPending
}

/// Records an audit event for notification actions.
@Model public struct NotificationAuditEvent: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var action: NotificationAuditAction
    public var identifier: String
    public var details: String?

    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(action.rawValue.capitalized) notification '\(identifier)' at \(dateStr)."
    }
}

/// Centralized manager for scheduling and handling local notifications.
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()
    private init() {
        Task { await requestAuthorization() }
    }

    private let center = UNUserNotificationCenter.current()

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) public var auditEvents: [NotificationAuditEvent]

    /// Requests notification authorization from the user.
    /// - Returns: `true` if granted, `false` otherwise.
    public func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Schedules a notification at the specified date components.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    ///   - dateComponents: The date components to trigger the notification.
    ///   - identifier: Unique identifier for the notification request.
    public func scheduleNotification(
        title: String,
        body: String,
        dateComponents: DateComponents,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
        modelContext.insert(NotificationAuditEvent(
            action: .scheduledDate,
            identifier: identifier,
            details: "Scheduled for \(dateComponents)"
        ))
    }

    /// Schedules a one-time notification after a time interval.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    ///   - seconds: Number of seconds from now to trigger.
    ///   - identifier: Unique identifier for the notification request.
    public func scheduleNotification(
        title: String,
        body: String,
        in seconds: TimeInterval,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule time interval notification: \(error)")
            }
        }
        modelContext.insert(NotificationAuditEvent(
            action: .scheduledInterval,
            identifier: identifier,
            details: "Scheduled after \(seconds) seconds"
        ))
    }

    /// Cancels a scheduled notification by identifier.
    /// - Parameter identifier: The identifier of the notification to cancel.
    public func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        modelContext.insert(NotificationAuditEvent(
            action: .cancelled,
            identifier: identifier,
            details: nil
        ))
    }

    /// Cancels all pending notifications.
    public func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        modelContext.insert(NotificationAuditEvent(
            action: .cancelledAll,
            identifier: "all",
            details: nil
        ))
    }

    /// Retrieves all pending notification requests.
    /// - Parameter completion: Closure called with the array of pending requests.
    public func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            completion(requests)
            modelContext.insert(NotificationAuditEvent(
                action: .fetchedPending,
                identifier: "pending",
                details: "\(requests.count) requests"
            ))
        }
    }

    /// Exports the last notification audit event as a pretty-printed JSON string.
    public func exportLastNotificationAuditJSON() async -> String? {
        guard let last = auditEvents.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Clears all notification audit events.
    public func clearAllNotificationAuditEvents() async {
        auditEvents.forEach { modelContext.delete($0) }
    }

    /// Accessibility summary for the last notification audit event.
    public var notificationAuditAccessibilitySummary: String {
        get async {
            return auditEvents.last?.accessibilityLabel
                ?? NSLocalizedString("No notification audit events recorded.", comment: "")
        }
    }
}
