//
//  AppointmentGroup.swift
//  Furfolio
//
//  Provides utilities to group, sort, and section appointments by various criteria,
//  with safer unwrapping, generic grouping, and human-readable section headers.
//

import Foundation
import os
import FirebaseRemoteConfigService

/// Utilities for grouping and sectioning Appointment arrays by various criteria with shared formatters.
struct AppointmentGroup {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentGroup")
    /// Dynamic loyalty threshold from remote config
    private static var loyaltyThreshold: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .loyaltyThreshold)
    }
    
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
        logger.log("byHour called with \(appts.count) appointments")
        return groupBy(appts) { calendar.component(.hour, from: $0.date) }
    }
    
    /// Groups appointments by start of day.
    static func byDate(_ appts: [Appointment]) -> DateGroups {
        logger.log("byDate called with \(appts.count) appointments")
        return groupBy(appts) { calendar.startOfDay(for: $0.date) }
    }
    
    /// Groups appointments by weekday name (e.g., Monday).
    static func byWeekdayName(_ appts: [Appointment]) -> StringGroups {
        logger.log("byWeekdayName called with \(appts.count) appointments")
        return groupBy(appts) { weekdayNameFormatter.string(from: $0.date) }
    }
    
    /// Groups appointments by calendar week of year.
    static func byWeekOfYear(_ appts: [Appointment]) -> [Int: [Appointment]] {
        logger.log("byWeekOfYear called with \(appts.count) appointments")
        return groupBy(appts) { calendar.component(.weekOfYear, from: $0.date) }
    }
    
    /// Groups appointments by month and year (e.g., May 2025).
    static func byMonthYear(_ appts: [Appointment]) -> StringGroups {
        logger.log("byMonthYear called with \(appts.count) appointments")
        return groupBy(appts) { monthYearFormatter.string(from: $0.date) }
    }
    
    
    // MARK: – Date & Month Sections
    
    /// Sections appointments by exact date with formatted headers (e.g., "May 22, 2025").
    static func dateSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        logger.log("dateSections called with \(appts.count) appointments")
        return sections(appts, by: { calendar.startOfDay(for: $0.date) }) { dateFormatter.string(from: $0) }
    }
    
    /// Sections appointments by month and year with formatted headers.
    static func monthSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        logger.log("monthSections called with \(appts.count) appointments")
        return sections(appts, by: { monthYearFormatter.string(from: $0.date) }) { $0 }
    }
    
    
    // MARK: – Appointment Status
    
    /// Groups appointments by their status (confirmed, completed, cancelled).
    static func byStatus(_ appts: [Appointment]) -> StatusGroups {
        logger.log("byStatus called with \(appts.count) appointments")
        return groupBy(appts) { $0.status }
    }
    
    /// Sections appointments by status with header titles from status raw values.
    static func statusSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        logger.log("statusSections called with \(appts.count) appointments")
        return sections(appts, by: { $0.status }, header: { $0.rawValue })
    }
    
    
    // MARK: – Service Type
    
    /// Groups appointments by service type.
    static func byServiceType(_ appts: [Appointment]) -> ServiceTypeGroups {
        logger.log("byServiceType called with \(appts.count) appointments")
        return groupBy(appts) { $0.serviceType }
    }
    
    /// Sections appointments by service type with localized header text.
    static func serviceTypeSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        logger.log("serviceTypeSections called with \(appts.count) appointments")
        return sections(appts, by: { $0.serviceType }, header: { $0.serviceType.localized })
    }

    
    
    // MARK: – Upcoming vs. Past
    
    /// Sections appointments into upcoming and past based on the current date.
    static func upcomingSections(_ appts: [Appointment]) -> [(header: String, appointments: [Appointment])] {
        logger.log("upcomingSections called with \(appts.count) appointments")
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
        logger.log("byBehavior called with \(appts.count) appointments")
        return groupBy(appts) {
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
        logger.log("behaviorSections called with \(appts.count) appointments")
        return sections(appts, by: {
            let text = $0.behaviorLog.joined(separator: " ").lowercased()
            if text.contains("aggressive") || text.contains("bite") {
                return BehaviorCategory.aggressive
            } else if text.contains("calm") || text.contains("friendly") {
                return BehaviorCategory.calm
            } else {
                return BehaviorCategory.neutral
            }
        }, header: { $0.rawValue })
    }
    
    
    // MARK: – Loyalty Threshold
    
    enum LoyaltyCategory: String, CaseIterable, Identifiable {
        case earned      = "🎁 Reward Earned"
        case progressing = "🏆 In Progress"
        var id: String { rawValue }
    }
    
    /// Groups appointments by loyalty category based on loyaltyPoints and threshold.
    static func byLoyalty(_ appts: [Appointment], threshold: Int = loyaltyThreshold) -> LoyaltyGroups {
        logger.log("byLoyalty called with \(appts.count) appointments and threshold \(threshold)")
        return groupBy(appts) { $0.loyaltyPoints >= threshold ? .earned : .progressing }
    }
    
    /// Sections appointments by loyalty category with reward/progress headers.
    static func loyaltySections(_ appts: [Appointment], threshold: Int = loyaltyThreshold) -> [(header: String, appointments: [Appointment])] {
        logger.log("loyaltySections called with \(appts.count) appointments and threshold \(threshold)")
        return sections(appts, by: { $0.loyaltyPoints >= threshold ? .earned : .progressing }, header: { $0.rawValue })
    }
}
