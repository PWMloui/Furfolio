//
//  OwnerActivityLog.swift
//  Furfolio
//
//  Enhanced for analytics, export, accessibility, criticality, and business intelligence.
// (Keep OwnerActivityType enum as-is, or add more badges/icons as needed.)
//

import Foundation
import SwiftData
import SwiftUI

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
    private var badgeTokens: [String] = []

    // MARK: - Concurrency

    /// Serial queue to ensure thread-safe access and mutation of audit logs and badges.
    private let auditQueue = DispatchQueue(label: "com.furfolio.owneractivitylog.auditQueue")

    // MARK: - Computed Properties

    @Attribute(.transient)
    var displayString: String {
        let icon = type.icon
        let formattedDate = Self.dateFormatter.string(from: date)
        return "\(icon) \(summary) (\(formattedDate))"
    }

    /// Time elapsed since activity for UI or analytics.
    @Attribute(.transient)
    var timeAgo: String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 60 { return String(format: NSLocalizedString("%d min ago", comment: "Time ago in minutes"), minutes) }
        let hours = minutes / 60
        if hours < 24 { return String(format: NSLocalizedString("%d hr ago", comment: "Time ago in hours"), hours) }
        let days = hours / 24
        return String(format: NSLocalizedString("%d d ago", comment: "Time ago in days"), days)
    }

    /// Human-readable summary for Trust Center/Compliance UI
    @Attribute(.transient)
    var auditSummary: String {
        String(format: NSLocalizedString("%@ by %@ on %@", comment: "Audit summary format"), summary, user ?? NSLocalizedString("system", comment: "Default user system"), Self.dateFormatter.string(from: date)) + (isCritical ? " [\(NSLocalizedString("CRITICAL", comment: "Critical badge"))]" : "")
    }

    /// Type-safe activity badges
    enum ActivityBadge: String, CaseIterable, Codable {
        case critical, retention, loyalty, security, financial, error

        /// Localized display name for badges
        var displayName: String {
            switch self {
            case .critical: return NSLocalizedString("Critical", comment: "Badge name")
            case .retention: return NSLocalizedString("Retention", comment: "Badge name")
            case .loyalty: return NSLocalizedString("Loyalty", comment: "Badge name")
            case .security: return NSLocalizedString("Security", comment: "Badge name")
            case .financial: return NSLocalizedString("Financial", comment: "Badge name")
            case .error: return NSLocalizedString("Error", comment: "Badge name")
            }
        }
    }

    /// Access badges in a thread-safe manner
    @Attribute(.transient)
    var badges: [ActivityBadge] {
        auditQueue.sync {
            badgeTokens.compactMap { ActivityBadge(rawValue: $0) }
        }
    }

    /// Computed risk/importance for dashboards (demo logic)
    @Attribute(.transient)
    var riskScore: Int {
        var score = 0
        if isCritical { score += 2 }
        if type == .chargeAdded || type == .chargePaid { score += 1 }
        if badges.contains(.error) { score += 2 }
        return score
    }

    /// Accessibility label for VoiceOver/compliance tooling
    /// This is async to support concurrency-safe access and localization.
    @Attribute(.transient)
    var accessibilityLabel: String {
        get async {
            let badgeDescriptions = await auditQueue.async { badgeTokens.compactMap { ActivityBadge(rawValue: $0)?.displayName } }
            let badgesString = badgeDescriptions.isEmpty ? "" : String(format: NSLocalizedString(" Badges: %@", comment: "Accessibility badge description"), badgeDescriptions.joined(separator: ", "))
            let criticalString = isCritical ? NSLocalizedString("Critical activity.", comment: "Accessibility critical activity") : ""
            let formattedDate = Self.dateFormatter.string(from: date)
            return String(format: NSLocalizedString("%@. %@. Date: %@.%@", comment: "Accessibility label format"), summary, type.displayName, formattedDate, criticalString + badgesString)
        }
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

    // MARK: - Async Badge Management

    /// Adds a badge in a concurrency-safe manner.
    /// - Parameter badge: The badge to add.
    func addBadge(_ badge: ActivityBadge) async {
        await auditQueue.async {
            if !self.badgeTokens.contains(badge.rawValue) {
                self.badgeTokens.append(badge.rawValue)
            }
        }
    }

    /// Removes a badge in a concurrency-safe manner.
    /// - Parameter badge: The badge to remove.
    func removeBadge(_ badge: ActivityBadge) async {
        await auditQueue.async {
            self.badgeTokens.removeAll { $0 == badge.rawValue }
        }
    }

    /// Checks if the log has a badge in a concurrency-safe manner.
    /// - Parameter badge: The badge to check.
    /// - Returns: True if the badge is present.
    func hasBadge(_ badge: ActivityBadge) async -> Bool {
        await auditQueue.async {
            self.badgeTokens.contains(badge.rawValue)
        }
    }

    // MARK: - Export

    /// Exports audit data as a JSON string asynchronously.
    /// - Throws: An error if encoding fails.
    /// - Returns: JSON string representing the audit log.
    func exportAuditJSON() async throws -> String {
        struct Export: Codable {
            let id: UUID
            let auditID: String
            let ownerID: UUID?
            let date: Date
            let type: String
            let summary: String
            let isCritical: Bool
            let badgeTokens: [String]
            let user: String?
        }
        let export = await auditQueue.sync {
            Export(
                id: self.id,
                auditID: self.auditID,
                ownerID: self.owner?.id,
                date: self.date,
                type: self.type.rawValue,
                summary: self.summary,
                isCritical: self.isCritical,
                badgeTokens: self.badgeTokens,
                user: self.user
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(export)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "OwnerActivityLog", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Failed to encode JSON string", comment: "JSON encode error")])
            }
            return jsonString
        } catch {
            throw NSError(domain: "OwnerActivityLog", code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Failed to encode audit log JSON", comment: "JSON encode error")])
        }
    }

    // MARK: - Quick Filter Helpers (Async)

    /// Filters logs for critical entries asynchronously.
    /// - Parameter logs: Array of logs to filter.
    /// - Returns: Filtered array containing only critical logs.
    static func filterCritical(_ logs: [OwnerActivityLog]) async -> [OwnerActivityLog] {
        await withTaskGroup(of: OwnerActivityLog?.self) { group in
            for log in logs {
                group.addTask {
                    if log.isCritical || await log.hasBadge(.critical) {
                        return log
                    } else {
                        return nil
                    }
                }
            }
            var results = [OwnerActivityLog]()
            for await result in group {
                if let log = result {
                    results.append(log)
                }
            }
            return results
        }
    }

    /// Filters logs for entries within recent days asynchronously.
    /// - Parameters:
    ///   - logs: Array of logs to filter.
    ///   - days: Number of days to look back.
    /// - Returns: Filtered array containing logs within the specified days.
    static func filterRecent(_ logs: [OwnerActivityLog], withinDays days: Int = 7) async -> [OwnerActivityLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return logs.filter { $0.date > cutoff }
    }

    /// Filters logs by user asynchronously.
    /// - Parameters:
    ///   - logs: Array of logs to filter.
    ///   - user: Username to filter by.
    /// - Returns: Filtered array containing logs by the specified user.
    static func filterByUser(_ logs: [OwnerActivityLog], user: String) async -> [OwnerActivityLog] {
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
            summary: NSLocalizedString("Booked appointment for Max", comment: "Sample summary"),
            details: NSLocalizedString("Service: Full Grooming. Staff: Jenny.", comment: "Sample details"),
            user: "jane_doe",
            isCritical: false
        )
        Task {
            await log.addBadge(.loyalty)
        }
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

#if DEBUG
import PlaygroundSupport

@available(iOS 15.0, *)
struct OwnerActivityLogPreview: PreviewProvider {
    static var previews: some View {
        OwnerActivityLogView()
    }

    struct OwnerActivityLogView: View {
        @StateObject private var log = OwnerActivityLog.sample

        @State private var exportedJSON: String = ""
        @State private var accessibilityText: String = ""

        var body: some View {
            VStack(spacing: 16) {
                Text(log.displayString)
                    .font(.headline)
                Text("Badges: \(log.badges.map { $0.displayName }.joined(separator: ", "))")
                    .font(.subheadline)
                Button(NSLocalizedString("Add Critical Badge", comment: "Button to add critical badge")) {
                    Task {
                        await log.addBadge(.critical)
                        await updateAccessibilityLabel()
                    }
                }
                Button(NSLocalizedString("Remove Critical Badge", comment: "Button to remove critical badge")) {
                    Task {
                        await log.removeBadge(.critical)
                        await updateAccessibilityLabel()
                    }
                }
                Button(NSLocalizedString("Export Audit JSON", comment: "Button to export audit JSON")) {
                    Task {
                        do {
                            exportedJSON = try await log.exportAuditJSON()
                        } catch {
                            exportedJSON = NSLocalizedString("Failed to export JSON", comment: "Export error message")
                        }
                    }
                }
                ScrollView {
                    Text(exportedJSON)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                Text(accessibilityText)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding()
            }
            .padding()
            .task {
                await updateAccessibilityLabel()
            }
        }

        private func updateAccessibilityLabel() async {
            accessibilityText = await log.accessibilityLabel
        }
    }
}
#endif
