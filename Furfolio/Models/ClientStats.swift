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
}
