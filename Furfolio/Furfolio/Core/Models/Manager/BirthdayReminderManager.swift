//
//  BirthdayReminderManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData
import UserNotifications

/// Manages scheduling local notifications for dog birthdays.
public actor BirthdayReminderManager {
    private let modelContext: ModelContext

    /// Initialize with the SwiftData model context.
    public init(context: ModelContext) {
        self.modelContext = context
        Task { await requestNotificationPermission() }
    }

    /// Requests permission for sending local notifications.
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Checks for dogs whose birthday is today and schedules a notification for each.
    public func scheduleTodayBirthdayNotifications(atHour hour: Int = 9, minute: Int = 0) async {
        let allDogs = try? await modelContext.fetch(Dog.self)
        let todayComponents = Calendar.current.dateComponents([.month, .day], from: Date())
        guard let dogs = allDogs else { return }

        for dog in dogs {
            guard let birthdate = dog.birthdate else { continue }
            let components = Calendar.current.dateComponents([.month, .day], from: birthdate)
            if components.month == todayComponents.month && components.day == todayComponents.day {
                await scheduleNotification(for: dog, atHour: hour, minute: minute)
            }
        }
    }

    /// Schedules a single local notification for the given dog’s birthday.
    private func scheduleNotification(for dog: Dog, atHour hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "🎂 Birthday Reminder"
        content.body = "\(dog.name) has a birthday today! 🎉"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "birthday-\(dog.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
