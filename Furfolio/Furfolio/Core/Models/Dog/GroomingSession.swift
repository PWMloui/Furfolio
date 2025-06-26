//
//  GroomingSession.swift
//  Furfolio
//
//  Enhanced for analytics, tokenization, auditing, accessibility, and export.
//  Author: ChatGPT

import Foundation
import SwiftData

@Model
final class GroomingSession: Identifiable, ObservableObject {
    @Attribute(.unique) @Attribute(.required)
    var id: UUID

    @Attribute(.required)
    var date: Date

    @Relationship(deleteRule: .nullify, inverse: nil)
    var staff: StaffMember?

    @Relationship(deleteRule: .nullify, inverse: \Dog.groomingSessions)
    var dog: Dog?

    @Relationship(deleteRule: .nullify, inverse: nil)
    var appointment: Appointment?

    @Relationship(deleteRule: .cascade, inverse: nil)
    var behaviorLog: BehaviorLog?

    @Attribute(.required)
    var auditLog: [String]

    @Attribute(.required)
    var serviceType: ServiceType

    @Attribute(.required)
    var durationMinutes: Int

    var notes: String?

    @Attribute(.required)
    var productsUsed: [String]

    @Attribute(.required)
    var outcomes: [String]

    @Attribute(.required)
    var isFavorite: Bool

    @Attribute(.required)
    var rating: Int

    @Attribute(.required)
    var routeOrder: Int

    var beforePhoto: Data?
    var afterPhoto: Data?

    @Attribute(.required)
    var createdAt: Date

    @Attribute(.required)
    var lastModified: Date

    @Attribute(.required)
    var createdBy: String

    @Attribute(.required)
    var lastModifiedBy: String

    // --- ENHANCEMENTS ---

    // MARK: - Financials
    @Attribute
    var sessionCost: Double? // Internal cost for analysis
    @Attribute
    var sessionRevenue: Double? // Amount charged for session
    @Attribute
    var tip: Double? // Tip received

    // MARK: - Tokenization: Badges/Tags
    enum SessionBadge: String, CaseIterable, Codable {
        case incident, loyaltyReward, firstSession, referral, ownerPresent, difficultDog, newStyle, rebooked, rushed
    }
    @Attribute
    var badgeTokens: [String]

    var badges: [SessionBadge] { badgeTokens.compactMap { SessionBadge(rawValue: $0) } }
    func addBadge(_ badge: SessionBadge) {
        if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) }
    }
    func removeBadge(_ badge: SessionBadge) {
        badgeTokens.removeAll { $0 == badge.rawValue }
    }
    func hasBadge(_ badge: SessionBadge) -> Bool {
        badgeTokens.contains(badge.rawValue)
    }

    // MARK: - Business Intelligence

    /// Gross profit for this session (if revenue/cost available)
    var profit: Double? {
        guard let revenue = sessionRevenue, let cost = sessionCost else { return nil }
        return revenue - cost
    }

    /// Efficiency: Revenue per hour for this session
    var revenuePerHour: Double? {
        guard let revenue = sessionRevenue, durationMinutes > 0 else { return nil }
        return revenue * 60.0 / Double(durationMinutes)
    }

    /// Quick status string for UI
    var quickStatus: String {
        if hasBadge(.incident) { return "Incident" }
        if rating <= 2 { return "Low Rating" }
        if isFavorite { return "Favorite" }
        return "Completed"
    }

    // MARK: - Audit Helpers

    func addAuditEntry(_ entry: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(stamp)] \(entry)")
        lastModified = Date()
    }

    var recentAuditSummary: String {
        auditLog.suffix(2).joined(separator: "\n")
    }

    // MARK: - Accessibility

    var accessibilityLabel: String {
        """
        Grooming session for \(dog?.name ?? "unknown dog"). \(serviceType.rawValue), \(durationMinutes) minutes. Rating: \(rating) star\(rating == 1 ? "" : "s").
        Staff: \(staff?.name ?? "unknown").
        \(isFavorite ? "Marked as favorite style." : "")
        \(badges.isEmpty ? "" : "Badges: \(badges.map { $0.rawValue }.joined(separator: ", ")).")
        """
    }

    // MARK: - Export Utility

    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID
            let date: Date
            let dogName: String?
            let staffName: String?
            let serviceType: String
            let duration: Int
            let productsUsed: [String]
            let outcomes: [String]
            let isFavorite: Bool
            let rating: Int
            let sessionRevenue: Double?
            let sessionCost: Double?
            let tip: Double?
            let badgeTokens: [String]
        }
        let export = Export(
            id: id, date: date,
            dogName: dog?.name, staffName: staff?.name,
            serviceType: serviceType.rawValue,
            duration: durationMinutes,
            productsUsed: productsUsed,
            outcomes: outcomes,
            isFavorite: isFavorite,
            rating: rating,
            sessionRevenue: sessionRevenue,
            sessionCost: sessionCost,
            tip: tip,
            badgeTokens: badgeTokens
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(export) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    // MARK: - Service Summary

    var displayServiceSummary: String {
        "\(serviceType.rawValue) - \(durationMinutes) min"
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        serviceType: ServiceType,
        durationMinutes: Int = 60,
        notes: String? = nil,
        staff: StaffMember? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        beforePhoto: Data? = nil,
        afterPhoto: Data? = nil,
        productsUsed: [String] = [],
        outcomes: [String] = [],
        behaviorLog: BehaviorLog? = nil,
        isFavorite: Bool = false,
        rating: Int = 3,
        routeOrder: Int = 0,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        createdBy: String = "system",
        lastModifiedBy: String = "system",
        auditLog: [String] = [],
        sessionCost: Double? = nil,
        sessionRevenue: Double? = nil,
        tip: Double? = nil,
        badgeTokens: [String] = []
    ) {
        self.id = id
        self.date = date
        self.serviceType = serviceType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.staff = staff
        self.dog = dog
        self.appointment = appointment
        self.beforePhoto = beforePhoto
        self.afterPhoto = afterPhoto
        self.productsUsed = productsUsed
        self.outcomes = outcomes
        self.behaviorLog = behaviorLog
        self.isFavorite = isFavorite
        self.rating = rating
        self.routeOrder = routeOrder
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
        self.sessionCost = sessionCost
        self.sessionRevenue = sessionRevenue
        self.tip = tip
        self.badgeTokens = badgeTokens
    }

    // MARK: - Preview

    static var preview: GroomingSession {
        GroomingSession(
            date: Date(),
            serviceType: .fullGroom,
            durationMinutes: 90,
            notes: "Calm and cooperative. Used lavender shampoo.",
            staff: nil,
            dog: nil,
            appointment: nil,
            productsUsed: ["Lavender Shampoo", "Conditioner"],
            outcomes: ["Nail Trimmed", "Ear Cleaned"],
            behaviorLog: nil,
            isFavorite: true,
            rating: 5,
            routeOrder: 1,
            createdAt: Date(),
            lastModified: Date(),
            createdBy: "previewUser",
            lastModifiedBy: "previewUser",
            auditLog: ["Created preview session"],
            sessionCost: 32.50,
            sessionRevenue: 80.00,
            tip: 10.00,
            badgeTokens: [SessionBadge.loyaltyReward.rawValue, SessionBadge.newStyle.rawValue]
        )
    }
}

// MARK: - Extend Dog to relate to grooming sessions

extension Dog {
    @Relationship(deleteRule: .cascade, inverse: \GroomingSession.dog)
    var groomingSessions: [GroomingSession] {
        get { [] }
        set { /* SwiftData synthesized */ }
    }
}
