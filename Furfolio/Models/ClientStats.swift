//
//  ClientStats.swift
//  Furfolio
//
//  Aggregates stats for each dog owner: loyalty, risk, spend, and activity.

import Foundation

struct ClientStats {
    let owner: DogOwner

    var totalAppointments: Int {
        owner.appointments.count
    }

    var totalCharges: Double {
        owner.charges.reduce(0) { $0 + $1.amount }
    }

    var loyaltyStatus: String {
        switch totalAppointments {
        case 0: return "New"
        case 1: return "🐾 First Timer"
        case 2...9: return "🔁 Monthly Regular"
        default: return "🏅 Loyal Client"
        }
    }

    var isRetentionRisk: Bool {
        guard let last = owner.lastActivityDate else { return true }
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? .distantPast
        return last < sixtyDaysAgo
    }

    var isTopSpender: Bool {
        totalCharges > 1000
    }

    var hasBirthdayThisMonth: Bool {
        guard let birthdate = owner.birthdate else { return false }
        let now = Date()
        return Calendar.current.component(.month, from: birthdate) == Calendar.current.component(.month, from: now)
    }
    /// Returns a loyalty progress tag like “🏆 3 more to free bath” or reward earned.
    var loyaltyProgressTag: String {
        let remaining = max(0, 10 - totalAppointments)
        return remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath"
    }

    /// Returns the most recent 3 behavior-related tags from appointments or charges.
    var recentBehaviorBadges: [String] {
        let combined: [Any] = owner.charges as [Any] + owner.appointments as [Any]
        let badges = combined.compactMap {
            if let c = $0 as? Charge { return c.behaviorBadge }
            if let a = $0 as? Appointment, let log = a.behaviorLog.last { return log }
            return nil
        }
        return Array(badges.prefix(3))
    }
    /// Returns the average duration of all appointments in minutes.
    var averageAppointmentDuration: Int {
        let durations = owner.appointments.map { $0.estimatedDurationMinutes }
        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0) { $0 + ($1 ?? 0) }
        return total / durations.count
    }

    /// Returns the most common service type the owner has booked.
    var mostFrequentService: String {
        let grouped = Dictionary(grouping: owner.appointments, by: { $0.serviceType.rawValue })
        let sorted = grouped.sorted { $0.value.count > $1.value.count }
        return sorted.first?.key ?? "N/A"
    }

    /// Revenue this client has brought in over the last 30 days.
    var revenueLast30Days: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        return owner.charges.filter { $0.date >= cutoff }
                            .reduce(0) { $0 + $1.amount }
    }

    /// The most recent appointment date.
    var lastAppointmentDate: Date? {
        owner.appointments.map { $0.date }.max()
    }

}
