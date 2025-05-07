//
//  Appointment.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhanced documentation, additional computed properties, and refactored code structure for improved clarity and scalability.

import Foundation
import SwiftData
import UserNotifications

@Model
final class Appointment: Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for the appointment.
    @Attribute(.unique) var id: UUID
    
    /// The scheduled date of the appointment.
    @Attribute var date: Date
    
    /// The associated dog owner.
    @Relationship(deleteRule: .nullify) var dogOwner: DogOwner

    /// An array of dates representing pet birthdays. Stored securely.
    @Attribute()
    var petBirthdays: [Date] = []
    
    /// Optional identifier to link the appointment with its corresponding charge record.
    var chargeID: UUID?

    /// Enum representing available service types.
    enum ServiceType: String, Codable, CaseIterable {
        case basic = "Basic Package"
        case full = "Full Package"
        case custom = "Custom Package"
        
        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }
    
    /// The service type for the appointment.
    var serviceType: ServiceType
    
    /// Optional appointment notes.
    var notes: String?

    /// The duration of the appointment in minutes.
    var durationMinutes: Int?

    /// Optional estimated time for the appointment in minutes (used for planning).
    @Attribute
    var estimatedDurationMinutes: Int?
    
    /// Enum representing the status of the appointment.
    enum AppointmentStatus: String, Codable, CaseIterable {
        case confirmed = "Confirmed"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }
    
    /// The current status of the appointment.
    var status: AppointmentStatus = AppointmentStatus.confirmed
    
    /// Indicates whether the appointment is recurring.
    var isRecurring: Bool
    
    /// The frequency of recurrence.
    var recurrenceFrequency: RecurrenceFrequency?
    
    /// Flag to indicate if a notification has already been scheduled.
    var isNotified: Bool = false
    
    /// An array of strings for profile badges. Stored securely.
    @Attribute()
    var profileBadges: [String] = []
    
    /// The reminder offset in minutes before the appointment.
    var reminderOffset: Int = 30
    
    /// Enum representing recurrence frequencies.
    enum RecurrenceFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }
    
    /// Optional data for the before photo log.
    var beforePhoto: Data?
    
    /// Optional data for the after photo log.
    var afterPhoto: Data?
    
    /// Loyalty points tracking the number of visits.
    var loyaltyPoints: Int = 0
    
    /// Behavior notes log with timeline-based mood entries and tags.
    var behaviorLog: [String] = []
    
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
        reminderOffset: Int = 30,
        chargeID: UUID? = nil,
        status: AppointmentStatus = .confirmed,
        beforePhoto: Data? = nil,
        afterPhoto: Data? = nil
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
        self.chargeID = chargeID
        self.status = status
        self.beforePhoto = beforePhoto
        self.afterPhoto = afterPhoto
    }
    
    // MARK: - Computed Properties
    
    /// Returns `true` if the appointment is scheduled for a future date.
    var isValid: Bool {
        date > Date()
    }
    
    /// Returns `true` if the appointment date is in the past.
    var isPast: Bool {
        date <= Date()
    }
    
    /// Returns the time until the appointment in minutes, if in the future.
    var timeUntil: Int? {
        guard isValid else { return nil }
        return Calendar.current.dateComponents([.minute], from: Date(), to: date).minute
    }
    
    /// Returns a relative time string until the appointment (e.g., "in 2 hours").
    /// Formats the duration in a user-friendly string, e.g., "1h 30m" or "45m".
    var durationFormatted: String {
        guard let duration = durationMinutes else { return "—" }
        let hours = duration / 60
        let minutes = duration % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// Display-friendly text for estimated duration.
    var estimatedDurationDisplay: String {
        if let minutes = estimatedDurationMinutes {
            return "\(minutes) mins"
        } else {
            return "—"
        }
    }
    var relativeTimeUntil: String {
        let interval = date.timeIntervalSince(Date())
        switch interval {
        case ..<60:
            return NSLocalizedString("Soon", comment: "Appointment time is soon")
        case ..<3600:
            let minutes = Int(interval / 60)
            return String(format: NSLocalizedString("in %d minutes", comment: "Relative time in minutes"), minutes)
        case ..<86400:
            let hours = Int(interval / 3600)
            return String(format: NSLocalizedString("in %d hours", comment: "Relative time in hours"), hours)
        default:
            let days = Int(interval / 86400)
            return String(format: NSLocalizedString("in %d days", comment: "Relative time in days"), days)
        }
    }
    
    /// Formats the appointment date as a string for display.
    var formattedDate: String {
        date.formatted(.dateTime.month().day().hour().minute())
    }
    
    /// Filters pet birthdays to those occurring today.
    var upcomingBirthdays: [Date] {
        petBirthdays.filter { Calendar.current.isDateInToday($0) }
    }
    
    /// A textual description summarizing the appointment.
    var description: String {
        """
        Appointment on \(formattedDate)
        Service: \(serviceType.localized)
        Status: \(status.rawValue)
        \(notes != nil ? "Notes: \(notes!)" : "")
        """
    }
    
    /// Visits until reward progress tag.
    var rewardProgressTag: String? {
        let remaining = max(0, 10 - loyaltyPoints)
        return remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath"
    }
    
    // MARK: - Methods
    
    /// Checks for conflicts with another appointment using a default buffer of 60 minutes.
    func conflictsWith(other: Appointment, bufferMinutes: Int = 60) -> Bool {
        abs(self.date.timeIntervalSince(other.date)) < TimeInterval(bufferMinutes * 60)
    }
    
    /// Generates a series of recurring appointments until the given end date.
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
                reminderOffset: reminderOffset,
                chargeID: chargeID,
                status: status,
                beforePhoto: beforePhoto,
                afterPhoto: afterPhoto
            )
            newAppointment.loyaltyPoints = self.loyaltyPoints + 1
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
    
    /// Schedules a local notification for the appointment.
    func scheduleNotification() {
        guard !isNotified, isValid else { return }
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Upcoming Appointment", comment: "Notification title")
        content.body = String(format: NSLocalizedString("You have a %@ appointment for %@ at %@.", comment: "Notification body"), serviceType.localized, dogOwner.ownerName, formattedDate)
        content.sound = .default
        guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -reminderOffset, to: date) else {
            print("Failed to compute trigger date using reminder offset.")
            return
        }
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for appointment at \(self.formattedDate) with offset \(self.reminderOffset) minutes.")
            }
        }
        isNotified = true
    }
    
    /// Cancels the scheduled notification.
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        isNotified = false
    }
    
    /// Adds a badge to the appointment's pet profile if not already present.
    func addBadge(_ badge: String) {
        guard !profileBadges.contains(badge) else { return }
        profileBadges.append(badge)
    }
    
    /// Updates behavior badges based on behavior log trends.
    func updateBehaviorBadge() {
        let moods = behaviorLog.map { $0.lowercased() }
        if moods.filter({ $0.contains("calm") }).count >= 3 {
            addBadge("🟢 Calm Pet")
        } else if moods.filter({ $0.contains("bite") || $0.contains("aggressive") }).count >= 2 {
            addBadge("🔴 Aggressive Behavior")
        }
    }
    
    /// Logs a new behavior entry and updates badges accordingly.
    func logBehavior(_ entry: String) {
        behaviorLog.append(entry)
        updateBehaviorBadge()
    }
    
    /// Analyzes behavioral notes to provide a localized summary.
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

// MARK: - Appointment Statistics & Utilities
extension Appointment {
    /// Calculates the average duration (in minutes) for appointments of a given service type.
    static func averageDuration(for appointments: [Appointment], serviceType: ServiceType) -> Double {
        let durations = appointments.filter { $0.serviceType == serviceType && $0.durationMinutes != nil }.map { Double($0.durationMinutes!) }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    /// Returns a dictionary of service type frequencies for the given appointments.
    static func serviceTypeFrequency(for appointments: [Appointment]) -> [ServiceType: Int] {
        Dictionary(grouping: appointments, by: \.serviceType).mapValues { $0.count }
    }
}
