//
//  Appointment.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhancements for personalization, feedback, and improved data handling.

import Foundation
import SwiftData
import UserNotifications

@Model
final class Appointment: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    @Relationship(deleteRule: .nullify) var dogOwner: DogOwner
    var petBirthdays: [Date] // Track pet birthdays for reminders

    enum ServiceType: String, Codable, CaseIterable {
        case basic = "Basic Package"
        case full = "Full Package"
        case custom = "Custom Package"

        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }

    var serviceType: ServiceType
    var notes: String?
    var isRecurring: Bool
    var recurrenceFrequency: RecurrenceFrequency?
    var isNotified: Bool = false
    var profileBadges: [String] // Profile badges for pets
    
    /// Customizable reminder offset in minutes (default is 30 minutes)
    var reminderOffset: Int = 30

    enum RecurrenceFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }

    // MARK: - Initializer
    init(
        date: Date,
        dogOwner: DogOwner,
        serviceType: ServiceType,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrenceFrequency: RecurrenceFrequency? = nil,
        petBirthdays: [Date] = [],
        profileBadges: [String] = [],
        reminderOffset: Int = 30
    ) {
        self.id = UUID()
        self.date = date
        self.dogOwner = dogOwner
        self.serviceType = serviceType
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceFrequency = recurrenceFrequency
        self.petBirthdays = petBirthdays
        self.profileBadges = profileBadges
        self.reminderOffset = reminderOffset
    }

    // MARK: - Computed Properties

    /// Check if the appointment is valid (future date)
    var isValid: Bool {
        date > Date()
    }

    /// Check if the appointment is a past event
    var isPast: Bool {
        date <= Date()
    }

    /// Time until the appointment in minutes
    var timeUntil: Int? {
        guard isValid else { return nil }
        return Calendar.current.dateComponents([.minute], from: Date(), to: date).minute
    }
    
    /// Relative time string until the appointment (e.g., "in 2 hours")
    var relativeTimeUntil: String {
        let interval = date.timeIntervalSince(Date())
        if interval < 60 {
            return NSLocalizedString("Soon", comment: "Appointment time is soon")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: NSLocalizedString("in %d minutes", comment: "Relative time in minutes"), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(format: NSLocalizedString("in %d hours", comment: "Relative time in hours"), hours)
        } else {
            let days = Int(interval / 86400)
            return String(format: NSLocalizedString("in %d days", comment: "Relative time in days"), days)
        }
    }

    /// Format the appointment date for display
    var formattedDate: String {
        date.formatted(.dateTime.month().day().hour().minute())
    }

    /// Check for upcoming pet birthdays
    var upcomingBirthdays: [Date] {
        petBirthdays.filter { Calendar.current.isDateInToday($0) }
    }

    // MARK: - Methods

    /// Check for conflicts with another appointment using a buffer time (default: 60 minutes)
    func conflictsWith(other: Appointment, bufferMinutes: Int = 60) -> Bool {
        abs(self.date.timeIntervalSince(other.date)) < TimeInterval(bufferMinutes * 60)
    }

    /// Generate a series of recurring appointments based on the specified frequency until the given end date
    func generateRecurrences(until endDate: Date) -> [Appointment] {
        guard isRecurring, let recurrenceFrequency = recurrenceFrequency else { return [] }
        
        var appointments: [Appointment] = []
        var nextDate = date
        
        while nextDate <= endDate {
            let newAppointment = Appointment(
                date: nextDate,
                dogOwner: dogOwner,
                serviceType: serviceType,
                notes: notes,
                isRecurring: true,
                recurrenceFrequency: recurrenceFrequency,
                petBirthdays: petBirthdays,
                profileBadges: profileBadges,
                reminderOffset: reminderOffset
            )
            appointments.append(newAppointment)
            
            switch recurrenceFrequency {
            case .daily:
                nextDate = Calendar.current.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            case .weekly:
                nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: nextDate) ?? nextDate
            case .monthly:
                nextDate = Calendar.current.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            }
        }
        
        return appointments
    }

    /// Schedule a notification for the appointment with a customizable offset
    func scheduleNotification() {
        guard !isNotified, isValid else { return }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Upcoming Appointment", comment: "Notification title")
        content.body = String(format: NSLocalizedString("You have a %@ appointment for %@ at %@.", comment: "Notification body"), serviceType.localized, dogOwner.ownerName, formattedDate)
        content.sound = .default

        // Calculate the trigger date using the customizable reminder offset
        guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -reminderOffset, to: date) else {
            print("Failed to compute trigger date using reminder offset.")
            return
        }
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)

        // Schedule the notification asynchronously to keep the UI responsive
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for appointment at \(self.formattedDate) with offset \(self.reminderOffset) minutes.")
            }
        }

        isNotified = true
    }

    /// Cancel a scheduled notification
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        isNotified = false
    }

    /// Add a badge to a pet profile if it is not already added
    func addBadge(_ badge: String) {
        guard !profileBadges.contains(badge) else { return }
        profileBadges.append(badge)
    }

    /// Analyze pet behavior based on profile notes and return a localized analysis string
    func analyzeBehavior() -> String {
        if let notes = notes?.lowercased() {
            if notes.contains("anxious") {
                return NSLocalizedString("The pet is anxious and may need extra care during appointments.", comment: "Behavior analysis: Anxious")
            } else if notes.contains("aggressive") {
                return NSLocalizedString("The pet has shown signs of aggression. Please handle with caution.", comment: "Behavior analysis: Aggressive")
            }
        }
        return NSLocalizedString("No significant behavioral issues noted.", comment: "Behavior analysis: Neutral")
    }
}
