//
//  AppointmentGroup.swift
//  Furfolio
//
//  Provides utilities to group, sort, and section appointments by various criteria,
//  with safer unwrapping, generic grouping, and human-readable section headers.
//

import Foundation

/// Utilities for grouping and sectioning Appointment arrays by various criteria with shared formatters.
struct AppointmentGroup {
    
    // MARK: – Shared Resources
    
    private static let calendar = Calendar.current
    
    /// “MMM yyyy”, e.g. “May 2025”
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        f.locale = .current
        return f
    }()
    
    /// “EEEE”, e.g. “Thursday”
    private static let weekdayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        f.locale = .current
        return f
    }()
    
    /// “MMM d, yyyy”, e.g. “May 22, 2025”
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    
    // MARK: – Typealiases
    
    /// Shorthand typealiases for grouped appointment collections.
    typealias HourGroups         = [Int: [Appointment]]
    typealias DateGroups         = [Date: [Appointment]]
    typealias StringGroups       = [String: [Appointment]]
    typealias ServiceTypeGroups  = [Appointment.ServiceType: [Appointment]]
    typealias StatusGroups       = [Appointment.AppointmentStatus: [Appointment]]
    typealias BehaviorGroups     = [BehaviorCategory: [Appointment]]
    typealias LoyaltyGroups      = [LoyaltyCategory: [Appointment]]
    
    
    // MARK: – Generic Helper
    
    /// Groups appointments into a dictionary keyed by the given hashable key.
    static func groupBy<K: Hashable>(
        _ appts: [Appointment],
        key: (Appointment) -> K
    ) -> [K: [Appointment]] {
        Dictionary(grouping: appts, by: key)
    }
    
    /// Builds ordered sections from grouped appointments, converting keys to headers.
    private static func sections<K: Hashable & Comparable>(
        _ appts: [Appointment],
        by keyFunc: (Appointment) -> K,
        header titleFunc: (K) -> String
    ) -> [(header: String, appointments: [Appointment])] {
        Dictionary(grouping: appts, by: keyFunc)
            .sorted { $0.key < $1.key }
            .map { (titleFunc($0.key), $0.value) }
    }
    
    
    // MARK: – Basic Groupings
    
    /// Groups appointments by the hour component of their date.
    static func byHour(_ appts: [Appointment]) -> HourGroups {
        groupBy(appts) { calendar.component(.hour, from: $0.date) }
    }
    
    /// Groups appointments by start of day.
    static func byDate(_ appts: [Appointment]) -> DateGroups {
        groupBy(appts) { calendar.startOfDay(for: $0.date) }
    }
    
    /// Groups appointments by weekday name (e.g., Monday).
    static func byWeekdayName(_ appts: [Appointment]) -> StringGroups {
        groupBy(appts) { weekdayNameFormatter.string(from: $0.date) }
    }
    
    /// Groups appointments by calendar week of year.
    static func byWeekOfYear(_ appts: [Appointment]) -> [Int: [Appointment]] {
        groupBy(appts) { calendar.component(.weekOfYear, from: $0.date) }
    }
    
    /// Groups appointments by month and year (e.g., May 2025).
    static func byMonthYear(_ appts: [Appointment]) -> StringGroups {
        groupBy(appts) { monthYearFormatter.string(from: $0.date) }
    }
    
    
    // MARK: – Date & Month Sections
    
    /// Sections appointments by exact date with formatted headers (e.g., "May 22, 2025").
    static func dateSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        sections(appts, by: { calendar.startOfDay(for: $0.date) }) { dateFormatter.string(from: $0) }
    }
    
    /// Sections appointments by month and year with formatted headers.
    static func monthSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        sections(appts, by: { monthYearFormatter.string(from: $0.date) }) { $0 }
    }
    
    
    // MARK: – Appointment Status
    
    /// Groups appointments by their status (confirmed, completed, cancelled).
    static func byStatus(_ appts: [Appointment]) -> StatusGroups {
        groupBy(appts) { $0.status }
    }
    
    /// Sections appointments by status with header titles from status raw values.
    /// Now uses allCases to avoid Comparable constraint.
    static func statusSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
      return Appointment.AppointmentStatus.allCases
        .map { status in
          let matches = appts.filter { $0.status == status }
          return (status.rawValue, matches)
        }
        .filter { !$0.appointments.isEmpty }
    }
    
    
    // MARK: – Service Type
    
    /// Groups appointments by service type.
    static func byServiceType(_ appts: [Appointment]) -> ServiceTypeGroups {
        groupBy(appts) { $0.serviceType }
    }
    
    /// Sections appointments by service type, ordered according to ServiceType.allCases.
    /// Sections appointments by service type with localized header text.
    static func serviceTypeSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
      return Appointment.ServiceType.allCases
        .map { type in
          let matches = appts.filter { $0.serviceType == type }
          return (type.localized, matches)
        }
        .filter { !$0.appointments.isEmpty }
    }

    
    
    // MARK: – Upcoming vs. Past
    
    /// Sections appointments into upcoming and past based on the current date.
    static func upcomingSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        let now = Date.now
        let upcoming = appts.filter { $0.date > now }
        let past     = appts.filter { $0.date <= now }
        return [
            ("Upcoming", upcoming),
            ("Past", past)
        ]
    }
    
    
    // MARK: – Behavior Categories
    
    enum BehaviorCategory: String, CaseIterable, Identifiable {
        case calm       = "🟢 Calm"
        case aggressive = "🔴 Aggressive"
        case neutral    = "😐 Neutral"
        var id: String { rawValue }
    }
    
    /// Groups appointments by derived behavior category from behavior log.
    static func byBehavior(_ appts: [Appointment]) -> BehaviorGroups {
        groupBy(appts) {
            let text = $0.behaviorLog.joined(separator: " ").lowercased()
            if text.contains("aggressive") || text.contains("bite") {
                return .aggressive
            } else if text.contains("calm") || text.contains("friendly") {
                return .calm
            } else {
                return .neutral
            }
        }
    }
    
    /// Sections grouped by behavior category with emoji headers.
    static func behaviorSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
      return BehaviorCategory.allCases
        .map { category in
          let matches = appts.filter { appt in
            let text = appt.behaviorLog.joined(separator: " ").lowercased()
            switch category {
            case .aggressive:
              return text.contains("aggressive") || text.contains("bite")
            case .calm:
              return text.contains("calm") || text.contains("friendly")
            case .neutral:
              return !text.contains("aggressive") && !text.contains("bite") &&
                     !text.contains("calm") && !text.contains("friendly")
            }
          }
          return (category.rawValue, matches)
        }
        .filter { !$0.appointments.isEmpty }
    }
    
    
    // MARK: – Loyalty Threshold
    
    enum LoyaltyCategory: String, CaseIterable, Identifiable {
        case earned      = "🎁 Reward Earned"
        case progressing = "🏆 In Progress"
        var id: String { rawValue }
    }
    
    /// Groups appointments by loyalty category based on loyaltyPoints and threshold.
    static func byLoyalty(_ appts: [Appointment], threshold: Int = 10) -> LoyaltyGroups {
        groupBy(appts) { $0.loyaltyPoints >= threshold ? .earned : .progressing }
    }
    
    /// Sections appointments by loyalty category with reward/progress headers.
    static func loyaltySections(_ appts: [Appointment], threshold: Int = 10) -> [(header: String, appointments: [Appointment])] {
      return LoyaltyCategory.allCases
        .map { category in
          let matches = appts.filter { appt in
            switch category {
            case .earned:
              return appt.loyaltyPoints >= threshold
            case .progressing:
              return appt.loyaltyPoints < threshold
            }
          }
          return (category.rawValue, matches)
        }
        .filter { !$0.appointments.isEmpty }
    }
}
