//
//  ReminderManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications

/// A scheduled reminder for appointments or tasks.
@Model public struct Reminder: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// When the reminder should fire.
    public var date: Date
    /// Message to display in the notification.
    public var message: String
    /// Unique identifier for the notification request.
    public var identifier: String
    /// Optional repeat interval (in seconds) for recurring reminders.
    public var repeatInterval: TimeInterval?
    /// Whether this reminder is active.
    public var isActive: Bool = true

    /// Formatted date string for display.
    @Attribute(.transient)
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        "\(message), scheduled for \(formattedDate)"
    }
}

/// Manages creation, scheduling, and persistence of reminders.
public class ReminderManager: ObservableObject {
    public static let shared = ReminderManager()
    private init() {
        Task { await requestNotificationAuthorization() }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.date, order: .forward) public var reminders: [Reminder]

    private let center = UNUserNotificationCenter.current()

    /// Requests local notification permission.
    public func requestNotificationAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Adds and schedules a reminder.
    public func addReminder(
        date: Date,
        message: String,
        identifier: String = UUID().uuidString,
        repeatInterval: TimeInterval? = nil
    ) async {
        // Persist the reminder
        let reminder = Reminder(date: date, message: message, identifier: identifier, repeatInterval: repeatInterval)
        modelContext.insert(reminder)

        // Schedule the notification
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Reminder", comment: "")
        content.body = message
        content.sound = .default

        var trigger: UNNotificationTrigger
        if let interval = repeatInterval {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Cancels and removes a reminder.
    public func removeReminder(_ reminder: Reminder) {
        // Remove persistence
        modelContext.delete(reminder)
        // Cancel notification
        center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
    }

    /// Cancels all reminders and clears persistence.
    public func clearAllReminders() async {
        for reminder in reminders {
            center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
            modelContext.delete(reminder)
        }
    }

    /// Exports all reminders as pretty-printed JSON.
    public func exportAllRemindersJSON() async -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(reminders)
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for the next upcoming reminder.
    public var nextReminderAccessibilitySummary: String {
        get async {
            guard let next = reminders.first(where: { $0.date >= Date() }) else {
                return NSLocalizedString("No upcoming reminders.", comment: "")
            }
            return next.accessibilityLabel
        }
    }
}
