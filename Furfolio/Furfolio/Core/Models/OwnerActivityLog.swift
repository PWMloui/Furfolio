//
//  OwnerActivityLog.swift
//  Furfolio
//
//  Enhanced for analytics, export, accessibility, criticality, and business intelligence.
// (Keep OwnerActivityType enum as-is, or add more badges/icons as needed.)

//

import Foundation
import SwiftData

@Model
final class OwnerActivityLog: Identifiable, ObservableObject, Hashable {
    // MARK: - Properties

    @Attribute(.unique)
    var id: UUID = UUID()

    var auditID: String = UUID().uuidString

    @Relationship(deleteRule: .nullify, inverse: \DogOwner.activityLogs)
    var owner: DogOwner?

    var date: Date = Date()
    var type: OwnerActivityType = .custom
    var summary: String = ""
    var details: String?
    var relatedEntityID: String?
    var relatedEntityType: String?
    var user: String?
    var isCritical: Bool = false

    // MARK: - Enhancements

    /// Tag tokens for segmentation, analytics, UI badges, and compliance (can include "critical", "security", "retention", etc.)
    var badgeTokens: [String] = []

    // MARK: - Computed Properties

    var displayString: String {
        let icon = type.icon
        let formattedDate = Self.dateFormatter.string(from: date)
        return "\(icon) \(summary) (\(formattedDate))"
    }

    /// Time elapsed since activity for UI or analytics.
    var timeAgo: String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        return "\(days) d ago"
    }

    /// Human-readable summary for Trust Center/Compliance UI
    var auditSummary: String {
        "\(summary) by \(user ?? "system") on \(Self.dateFormatter.string(from: date))" + (isCritical ? " [CRITICAL]" : "")
    }

    /// Type-safe activity badges
    enum ActivityBadge: String, CaseIterable, Codable {
        case critical, retention, loyalty, security, financial, error
    }
    var badges: [ActivityBadge] { badgeTokens.compactMap { ActivityBadge(rawValue: $0) } }
    func addBadge(_ badge: ActivityBadge) {
        if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) }
    }
    func removeBadge(_ badge: ActivityBadge) {
        badgeTokens.removeAll { $0 == badge.rawValue }
    }
    func hasBadge(_ badge: ActivityBadge) -> Bool {
        badgeTokens.contains(badge.rawValue)
    }

    /// Computed risk/importance for dashboards (demo logic)
    var riskScore: Int {
        var score = 0
        if isCritical { score += 2 }
        if type == .chargeAdded || type == .chargePaid { score += 1 }
        if badges.contains(.error) { score += 2 }
        return score
    }

    /// Accessibility label for VoiceOver/compliance tooling
    var accessibilityLabel: String {
        "\(summary). \(type.displayName). Date: \(Self.dateFormatter.string(from: date)). \(isCritical ? "Critical activity." : "")"
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        auditID: String = UUID().uuidString,
        owner: DogOwner? = nil,
        date: Date = Date(),
        type: OwnerActivityType = .custom,
        summary: String = "",
        details: String? = nil,
        relatedEntityID: String? = nil,
        relatedEntityType: String? = nil,
        user: String? = nil,
        isCritical: Bool = false,
        badgeTokens: [String] = []
    ) {
        self.id = id
        self.auditID = auditID
        self.owner = owner
        self.date = date
        self.type = type
        self.summary = summary
        self.details = details
        self.relatedEntityID = relatedEntityID
        self.relatedEntityType = relatedEntityType
        self.user = user
        self.isCritical = isCritical
        self.badgeTokens = badgeTokens
    }

    // MARK: - Export

    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID, auditID: String, ownerID: UUID?, date: Date, type: String, summary: String, isCritical: Bool, badgeTokens: [String], user: String?
        }
        let export = Export(
            id: id,
            auditID: auditID,
            ownerID: owner?.id,
            date: date,
            type: type.rawValue,
            summary: summary,
            isCritical: isCritical,
            badgeTokens: badgeTokens,
            user: user
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Quick Filter Helpers

    static func filterCritical(_ logs: [OwnerActivityLog]) -> [OwnerActivityLog] {
        logs.filter { $0.isCritical || $0.badges.contains(.critical) }
    }
    static func filterRecent(_ logs: [OwnerActivityLog], withinDays days: Int = 7) -> [OwnerActivityLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return logs.filter { $0.date > cutoff }
    }
    static func filterByUser(_ logs: [OwnerActivityLog], user: String) -> [OwnerActivityLog] {
        logs.filter { $0.user == user }
    }

    // MARK: - Hashable

    static func == (lhs: OwnerActivityLog, rhs: OwnerActivityLog) -> Bool {
        lhs.id == rhs.id && lhs.auditID == rhs.auditID
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(auditID)
    }

    // MARK: - Static Date Formatter

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    // MARK: - Preview / Sample

    static var sample: OwnerActivityLog {
        let log = OwnerActivityLog(
            type: .appointmentBooked,
            summary: "Booked appointment for Max",
            details: "Service: Full Grooming. Staff: Jenny.",
            user: "jane_doe",
            isCritical: false
        )
        log.addBadge(.loyalty)
        return log
    }
}

// (Keep OwnerActivityType enum as-is, or add more badges/icons as needed.)
/// Enum for owner-related activity log types.
/// Provides localized display names and SF Symbol icons for UI consistency, audit categorization, analytics event grouping, and business logic triggers.
/// Designed to integrate with UI tokens, badges, and event reporting systems.
enum OwnerActivityType: String, Codable, CaseIterable, Identifiable, Hashable {
    case profileCreated
    case profileEdited
    case appointmentBooked
    case appointmentCancelled
    case appointmentCompleted
    case chargeAdded
    case chargePaid
    case retentionStatusChanged
    case loyaltyReward
    case noteAdded
    case custom

    var id: String { rawValue }

    /// Localized display name used for UI labels, badges, analytics event naming, and business reporting.
    var displayName: String {
        switch self {
        case .profileCreated: return NSLocalizedString("Profile Created", comment: "Owner activity type")
        case .profileEdited: return NSLocalizedString("Profile Edited", comment: "Owner activity type")
        case .appointmentBooked: return NSLocalizedString("Appointment Booked", comment: "Owner activity type")
        case .appointmentCancelled: return NSLocalizedString("Appointment Cancelled", comment: "Owner activity type")
        case .appointmentCompleted: return NSLocalizedString("Appointment Completed", comment: "Owner activity type")
        case .chargeAdded: return NSLocalizedString("Charge Added", comment: "Owner activity type")
        case .chargePaid: return NSLocalizedString("Charge Paid", comment: "Owner activity type")
        case .retentionStatusChanged: return NSLocalizedString("Retention Status Changed", comment: "Owner activity type")
        case .loyaltyReward: return NSLocalizedString("Loyalty Reward", comment: "Owner activity type")
        case .noteAdded: return NSLocalizedString("Note Added", comment: "Owner activity type")
        case .custom: return NSLocalizedString("Other", comment: "Owner activity type")
        }
    }

    /// SF Symbol icon name used for UI tokens, badges, audit visual cues, and analytics dashboards.
    var icon: String {
        switch self {
        case .profileCreated: return "person.crop.circle.badge.plus"
        case .profileEdited: return "pencil.circle"
        case .appointmentBooked: return "calendar.badge.plus"
        case .appointmentCancelled: return "calendar.badge.minus"
        case .appointmentCompleted: return "checkmark.circle"
        case .chargeAdded: return "creditcard"
        case .chargePaid: return "checkmark.seal"
        case .retentionStatusChanged: return "arrow.2.squarepath"
        case .loyaltyReward: return "star.circle"
        case .noteAdded: return "note.text"
        case .custom: return "ellipsis.circle"
        }
    }
}
