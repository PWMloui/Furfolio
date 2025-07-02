//
//  GroomingSession.swift
//  Furfolio
//
//  Enhanced for analytics, tokenization, auditing, accessibility, and export.
//  Author: ChatGPT

import Foundation
import SwiftData
import SwiftUI

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
    private var auditLog: [String]

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

        /// Localized display name for the badge.
        var localizedName: String {
            switch self {
            case .incident: return NSLocalizedString("Incident", comment: "Badge indicating an incident occurred")
            case .loyaltyReward: return NSLocalizedString("Loyalty Reward", comment: "Badge for loyalty reward")
            case .firstSession: return NSLocalizedString("First Session", comment: "Badge for first session")
            case .referral: return NSLocalizedString("Referral", comment: "Badge for referral")
            case .ownerPresent: return NSLocalizedString("Owner Present", comment: "Badge indicating owner was present")
            case .difficultDog: return NSLocalizedString("Difficult Dog", comment: "Badge for difficult dog")
            case .newStyle: return NSLocalizedString("New Style", comment: "Badge for new style")
            case .rebooked: return NSLocalizedString("Rebooked", comment: "Badge for rebooked session")
            case .rushed: return NSLocalizedString("Rushed", comment: "Badge for rushed session")
            }
        }
    }
    @Attribute
    private var badgeTokens: [String]

    private let auditQueue = DispatchQueue(label: "com.furfolio.groomingsession.auditQueue", attributes: .concurrent)

    // MARK: - Badge Management

    /// Adds a badge token safely using the internal serial queue.
    /// - Parameter badge: The badge to add.
    @MainActor
    func addBadge(_ badge: SessionBadge) async {
        await withCheckedContinuation { continuation in
            auditQueue.async(flags: .barrier) {
                if !self.badgeTokens.contains(badge.rawValue) {
                    self.badgeTokens.append(badge.rawValue)
                }
                continuation.resume()
            }
        }
    }

    /// Removes a badge token safely using the internal serial queue.
    /// - Parameter badge: The badge to remove.
    @MainActor
    func removeBadge(_ badge: SessionBadge) async {
        await withCheckedContinuation { continuation in
            auditQueue.async(flags: .barrier) {
                self.badgeTokens.removeAll { $0 == badge.rawValue }
                continuation.resume()
            }
        }
    }

    /// Checks if the session has a specific badge.
    /// - Parameter badge: The badge to check.
    /// - Returns: True if the badge is present, false otherwise.
    @MainActor
    func hasBadge(_ badge: SessionBadge) async -> Bool {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                continuation.resume(returning: self.badgeTokens.contains(badge.rawValue))
            }
        }
    }

    /// Returns all badges currently assigned to the session.
    @MainActor
    var badges: [SessionBadge] {
        get async {
            await withCheckedContinuation { continuation in
                auditQueue.async {
                    let badges = self.badgeTokens.compactMap { SessionBadge(rawValue: $0) }
                    continuation.resume(returning: badges)
                }
            }
        }
    }

    // MARK: - Business Intelligence

    /// Gross profit for this session (if revenue/cost available)
    @Attribute(.transient)
    var profit: Double? {
        guard let revenue = sessionRevenue, let cost = sessionCost else { return nil }
        return revenue - cost
    }

    /// Efficiency: Revenue per hour for this session
    @Attribute(.transient)
    var revenuePerHour: Double? {
        guard let revenue = sessionRevenue, durationMinutes > 0 else { return nil }
        return revenue * 60.0 / Double(durationMinutes)
    }

    /// Quick status string for UI, localized.
    @Attribute(.transient)
    @MainActor
    var quickStatus: String {
        get async {
            if await hasBadge(.incident) { return NSLocalizedString("Incident", comment: "Quick status for incident") }
            if rating <= 2 { return NSLocalizedString("Low Rating", comment: "Quick status for low rating") }
            if isFavorite { return NSLocalizedString("Favorite", comment: "Quick status for favorite") }
            return NSLocalizedString("Completed", comment: "Quick status for completed session")
        }
    }

    // MARK: - Audit Helpers

    /// Adds an audit entry asynchronously and safely using the internal serial queue.
    /// This method appends a timestamped entry to the audit log and updates lastModified.
    /// - Parameter entry: The audit entry message.
    @MainActor
    func addAuditEntry(_ entry: String) async {
        await withCheckedContinuation { continuation in
            auditQueue.async(flags: .barrier) {
                let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                self.auditLog.append("[\(stamp)] \(entry)")
                DispatchQueue.main.async {
                    self.lastModified = Date()
                }
                continuation.resume()
            }
        }
    }

    /// Retrieves the most recent audit entries asynchronously and safely.
    /// - Parameter count: Number of recent entries to retrieve. Defaults to 2.
    /// - Returns: A string concatenation of recent audit entries separated by newlines.
    @MainActor
    func recentAuditSummary(count: Int = 2) async -> String {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                let recentEntries = self.auditLog.suffix(count).joined(separator: "\n")
                continuation.resume(returning: recentEntries)
            }
        }
    }

    /// Exports the audit log as a JSON string asynchronously.
    /// - Returns: JSON string representation of the audit log or nil if encoding fails.
    @MainActor
    func exportAuditLogJSON() async -> String? {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(self.auditLog) {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Accessibility

    /// Accessibility label describing the grooming session dynamically, supporting concurrency and localization.
    @MainActor
    var accessibilityLabel: String {
        get async {
            let dogName = dog?.name ?? NSLocalizedString("unknown dog", comment: "Fallback dog name")
            let service = serviceType.rawValue
            let duration = durationMinutes
            let stars = rating
            let starSuffix = stars == 1 ? "" : "s"
            let staffName = staff?.name ?? NSLocalizedString("unknown", comment: "Fallback staff name")
            let favoriteText = isFavorite ? NSLocalizedString("Marked as favorite style.", comment: "Accessibility favorite") : ""
            let badgesList = await badges
            let badgesText = badgesList.isEmpty ? "" : NSLocalizedString("Badges:", comment: "Accessibility badges prefix") + " " + badgesList.map { $0.localizedName }.joined(separator: ", ") + "."

            return """
            \(NSLocalizedString("Grooming session for", comment: "Accessibility label start")) \(dogName). \(service), \(duration) \(NSLocalizedString("minutes", comment: "Duration unit")). \(NSLocalizedString("Rating", comment: "Rating label")): \(stars) \(NSLocalizedString("star", comment: "Star singular"))\(starSuffix).
            \(NSLocalizedString("Staff", comment: "Staff label")): \(staffName).
            \(favoriteText)
            \(badgesText)
            """
        }
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

    @Attribute(.transient)
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

    /// Asynchronously creates a preview instance and adds an audit entry.
    static var preview: GroomingSession {
        get async {
            let session = GroomingSession(
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
            await session.addAuditEntry(NSLocalizedString("Preview audit entry added", comment: "Audit log preview entry"))
            return session
        }
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

// MARK: - SwiftUI PreviewProvider to demonstrate async features

#if DEBUG
struct GroomingSession_Previews: PreviewProvider {
    static var previews: some View {
        GroomingSessionPreviewView()
            .padding()
            .previewLayout(.sizeThatFits)
    }

    struct GroomingSessionPreviewView: View {
        @StateObject private var session = GroomingSession(
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
            badgeTokens: [GroomingSession.SessionBadge.loyaltyReward.rawValue, GroomingSession.SessionBadge.newStyle.rawValue]
        )

        @State private var auditSummary: String = ""
        @State private var accessibilityLabel: String = ""
        @State private var badgesText: String = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Audit Log Summary:")
                    .font(.headline)
                Text(auditSummary)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                Text("Badges:")
                    .font(.headline)
                Text(badgesText)
                    .font(.body)

                Text("Accessibility Label:")
                    .font(.headline)
                Text(accessibilityLabel)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                HStack {
                    Button("Add Incident Badge") {
                        Task {
                            await session.addBadge(.incident)
                            await refreshData()
                        }
                    }
                    Button("Remove Incident Badge") {
                        Task {
                            await session.removeBadge(.incident)
                            await refreshData()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await refreshData()
                }
            }
        }

        private func refreshData() async {
            auditSummary = await session.recentAuditSummary()
            let badges = await session.badges
            badgesText = badges.map { $0.localizedName }.joined(separator: ", ")
            accessibilityLabel = await session.accessibilityLabel
        }
    }
}
#endif
