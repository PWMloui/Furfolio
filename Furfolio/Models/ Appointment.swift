//
//  Appointment.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jul 15, 2025 — refactored for SwiftData conventions and modular services.
//

import Foundation
import SwiftData
import os

extension Appointment {
  /// Default pet birthdays array.
  static let petBirthdaysDefault: [Date] = []
  /// Default profile badges array.
  static let profileBadgesDefault: [String] = []
  /// Default behavior log array.
  static let behaviorLogDefault: [String] = []
}

@Model
final class Appointment: Identifiable {
  
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Appointment")
  
  /// Shared calendar and formatter for display and comparisons.
  private static let calendar = Calendar.current
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
  }()
    
  // MARK: – Persistent Properties
    
  @Attribute(.unique)                 var id: UUID = UUID()
  @Attribute                           var date: Date
  @Relationship(deleteRule: .nullify) var dogOwner: DogOwner
    
  @Attribute(.transformable(by: Appointment.dateArrayTransformerName))
                                   var petBirthdays: [Date] = Appointment.petBirthdaysDefault
    
  @Attribute                           var chargeID: UUID?
  @Attribute                           var serviceType: ServiceType
  @Attribute                           var notes: String?
  @Attribute                           var durationMinutes: Int?
  @Attribute                           var estimatedDurationMinutes: Int?
  @Attribute                           var status: AppointmentStatus = AppointmentStatus.confirmed
  @Attribute                           var isRecurring: Bool = false
  @Attribute                           var recurrenceFrequency: RecurrenceFrequency?
  @Attribute                           var isNotified: Bool = false
    
  @Attribute(.transformable(by: Appointment.stringArrayTransformerName))
                                   var profileBadges: [String] = Appointment.profileBadgesDefault
    
  @Attribute                           var reminderOffset: Int = 30
    
  // Consider switching these to file-backed attachments rather than raw Data BLOBs
  @Attribute                           var beforePhoto: Data?
  @Attribute                           var afterPhoto: Data?
    
  @Attribute                           var loyaltyPoints: Int = 0
    
  @Attribute(.transformable(by: Appointment.stringArrayTransformerName))
                                   var behaviorLog: [String] = Appointment.behaviorLogDefault
    
  // MARK: – Enums
    
  enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case basicPackage  = "Basic Package"
    case fullPackage   = "Full Package"
    case customPackage = "Custom Package"
        
    var id: String { rawValue }
    var localized: String { NSLocalizedString(rawValue, comment: "") }
  }
  enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
        
    var id: String { rawValue }
  }
  enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily   = "Daily"
    case weekly  = "Weekly"
    case monthly = "Monthly"
        
    var id: String { rawValue }
  }
    
  // MARK: – Transformer Names (for external registration)
    
  static let dateArrayTransformerName   = "DateArrayTransformer"
  static let stringArrayTransformerName = "StringArrayTransformer"
    
  // MARK: – Computed Properties
    
  /// True if this appointment’s date is in the future.
  @Transient var isUpcoming: Bool {
    date > Date.now
  }
  /// Minutes remaining until this appointment, or nil if in the past.
  @Transient var minutesUntil: Int? {
    guard isUpcoming else { return nil }
    return Self.calendar
      .dateComponents([.minute], from: Date.now, to: date)
      .minute
  }
  /// Formatted string representation of the appointment’s date.
  @Transient var formattedDate: String {
    return Self.dateFormatter.string(from: date)
  }
  /// Formatted duration string (e.g., "1h 15m") or "—" if unknown.
  @Transient var durationFormatted: String {
    guard let m = durationMinutes, m > 0 else { return "—" }
    let h = m / 60, mm = m % 60
    return h > 0 ? "\(h)h \(mm)m" : "\(mm)m"
  }
  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
  }()
  /// Relative time string until the appointment (e.g., "in 2 hours").
  @Transient var relativeTimeUntil: String {
    Appointment.relativeFormatter.localizedString(for: date, relativeTo: Date.now)
  }
  /// Summary string combining date, service, status, and notes.
  @Transient var summary: String {
    let base = "\(formattedDate) • \(serviceType.localized) • \(status.rawValue)"
    if let txt = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty {
      return base + " • Notes: \(txt)"
    }
    return base
  }
  
  /// Designated initializer for Appointment model.
  init(
    date: Date,
    dogOwner: DogOwner,
    serviceType: ServiceType,
    notes: String? = nil,
    durationMinutes: Int? = nil,
    estimatedDurationMinutes: Int? = nil,
    status: AppointmentStatus = AppointmentStatus.confirmed,
    isRecurring: Bool = false,
    recurrenceFrequency: RecurrenceFrequency? = nil,
    petBirthdays: [Date]? = nil,
    profileBadges: [String]? = nil,
    behaviorLog: [String]? = nil,
    chargeID: UUID? = nil,
    loyaltyPoints: Int = 0,
    beforePhoto: Data? = nil,
    afterPhoto: Data? = nil
  ) {
    self.date = date
    self.dogOwner = dogOwner
    self.serviceType = serviceType
    self.notes = notes
    self.petBirthdays = petBirthdays ?? Appointment.petBirthdaysDefault
    self.profileBadges = profileBadges ?? Appointment.profileBadgesDefault
    self.behaviorLog = behaviorLog ?? Appointment.behaviorLogDefault
    self.durationMinutes = durationMinutes
    self.estimatedDurationMinutes = estimatedDurationMinutes
    self.status = status
    self.isRecurring = isRecurring
    self.recurrenceFrequency = recurrenceFrequency
    self.reminderOffset = 30
    self.chargeID = chargeID
    self.loyaltyPoints = loyaltyPoints
    self.beforePhoto = beforePhoto
    self.afterPhoto = afterPhoto
  }
    
  // MARK: – Reminder Actions
    
  /// Schedules a local notification for this appointment with the given offset.
  func scheduleReminder() {
      guard isUpcoming else { 
          logger.log("Attempted to schedule reminder for past appointment \(id)")
          return 
      }
      logger.log("Scheduling reminder for appointment \(id) with offset \(reminderOffset) minutes")
      ReminderScheduler.shared.scheduleReminder(
          id: id.uuidString,
          date: Calendar.current.date(byAdding: .minute, value: -reminderOffset, to: date)!,
          title: "Upcoming Appointment",
          body: summary
      )
      isNotified = true
      logger.log("Scheduled reminder, isNotified set to true for appointment \(id)")
  }
  /// Cancels any previously scheduled notification for this appointment.
  func cancelReminder() {
      logger.log("Cancelling reminder for appointment \(id)")
      ReminderScheduler.shared.cancelReminder(id: id.uuidString)
      isNotified = false
      logger.log("Cancelled reminder, isNotified set to false for appointment \(id)")
  }
    
  // MARK: – Behavior Logging
    
  /// Logs a behavior entry and updates the pet’s profile badges if needed.
  func logBehavior(_ entry: String) {
      logger.log("Logging behavior entry for appointment \(id): '\(entry)'")
      behaviorLog.append(entry)
      let badge = BadgeEngine.behaviorBadge(from: entry)
      logger.log("Computed behavior badge '\(badge.rawValue)' for entry")
      if !profileBadges.contains(badge.rawValue) {
          profileBadges.append(badge.rawValue)
          logger.log("Appended new profile badge '\(badge.rawValue)' to appointment \(id)")
      }
  }
}

// MARK: – Notification Identifiers

extension Appointment {
  static let notificationCategory         = "APPOINTMENT_REMINDER"
  static let notificationActionReschedule = "RESCHEDULE_APPOINTMENT"
  static let notificationActionCancel     = "CANCEL_APPOINTMENT"
}
