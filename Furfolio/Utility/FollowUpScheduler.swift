//
//  FollowUpScheduler.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData
import UserNotifications
import os

final class FollowUpScheduler {
    static let shared = FollowUpScheduler()
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FollowUpScheduler")
    private init() {
        requestAuthorization()
    }

    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                self.logger.log("Notification authorization granted")
            } else {
                self.logger.log("Notification authorization denied")
            }
        }
    }

    func scheduleFollowUp(for appointmentID: UUID, appointmentDate: Date, after days: Int) {
        guard let followUpDate = Calendar.current.date(byAdding: .day, value: days, to: appointmentDate) else {
            logger.error("Could not calculate follow-up date for appointment \(appointmentID)")
            return
        }
        let id = "followup_\(appointmentID.uuidString)"
        logger.log("Scheduling follow-up \(id) on \(String(describing: followUpDate))")
        let content = UNMutableNotificationContent()
        content.title = "Time for a follow-up!"
        content.body = "Hope \(days)-day follow-up goes well."
        content.sound = .default
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: followUpDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule follow-up \(id): \(error.localizedDescription)")
            } else {
                self.logger.log("Scheduled follow-up \(id)")
            }
        }
    }

    func cancelFollowUp(for appointmentID: UUID) {
        let id = "followup_\(appointmentID.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        logger.log("Cancelled follow-up \(id)")
    }

    func cancelAllFollowUps() {
        // remove all identifiers with prefix "followup_"
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("followup_") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            self.logger.log("Cancelled all follow-up notifications")
        }
    }
}
