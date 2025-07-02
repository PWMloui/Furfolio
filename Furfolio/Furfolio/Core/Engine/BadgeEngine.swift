//
//  BadgeEngine.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  RetentionAlertEngine is now fully merged into BadgeEngine.swift and should be deleted.
//
//
//  BadgeEngine.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  ──────────────────────────────────────────────────────────────────────────────
//  Furfolio BadgeEngine – Architecture, Extensibility, Analytics, Diagnostics,
//  Localization, Accessibility, Compliance, and Preview/Testability
//  ──────────────────────────────────────────────────────────────────────────────
//
//  ARCHITECTURE:
//  BadgeEngine is a modular, thread-safe, and extensible singleton responsible for
//  awarding, revoking, and auditing badges for Furfolio models (Dog, DogOwner,
//  Appointment, etc.). It supports custom badge rule injection, analytics, and
//  audit/trust center hooks. Its output is fully localizable, accessible, and
//  compliant with audit/reporting requirements.
//
//  EXTENSIBILITY:
//  - Custom badge logic can be injected for each model type via closure properties.
//  - Analytics, audit, and notification hooks are exposed for integration with
//    Trust Center, admin dashboards, and compliance systems.
//  - Designed for easy addition of new badge types, rules, and audit/analytics
//    integrations.
//
//  ANALYTICS / AUDIT / TRUST CENTER HOOKS:
//  - Every badge award/revocation is auditable, with events recorded in a capped
//    buffer for diagnostics, and optionally persisted to UserDefaults or other
//    storage for compliance.
//  - BadgeEngineAnalyticsLogger is async/await-ready and supports test/preview
//    mode for console-only logging.
//  - NullBadgeEngineAnalyticsLogger is provided for tests/previews.
//  - All analytics and audit messages are fully localized and designed for reporting.
//
//  DIAGNOSTICS:
//  - Recent analytics events (last 20) are buffered and can be fetched for admin,
//    diagnostics, or Trust Center review.
//  - PreviewProvider demonstrates diagnostics buffer and testMode in action.
//
//  LOCALIZATION:
//  - All user-facing strings, log/audit messages, and labels are localized via
//    NSLocalizedString with keys, values, and comments for translators.
//
//  ACCESSIBILITY:
//  - All badge labels and descriptions provide accessibility labels for VoiceOver.
//  - Accessibility is demonstrated in previews and enforced in public APIs.
//
//  COMPLIANCE:
//  - Audit logs and analytics are suitable for privacy/trust center review.
//  - All badge events are tokenized and exportable for reporting.
//
//  PREVIEW/TESTABILITY:
//  - NullBadgeEngineAnalyticsLogger and testMode are provided for clean preview
//    and test scenarios.
//  - PreviewProvider shows diagnostics, accessibility, and testMode behavior.
//
//  MAINTAINER NOTES:
//  - Extend badge rules by adding to the relevant badge logic closures or
//    modifying the badge assignment methods.
//  - Use the analytics logger for all new integrations with Trust Center,
//    compliance, or admin dashboards.
//  - All new user-facing strings must be localized.
//  - See doc-comments throughout for further guidance.
//  ──────────────────────────────────────────────────────────────────────────────
//


import Foundation

// MARK: - Audit Context (set at login/session)
public struct BadgeEngineAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "BadgeEngine"
}

// MARK: - BadgeEngineAnalyticsLogger Protocol & Implementations

/// Protocol for logging badge analytics events.
/// Use this for Trust Center, diagnostics, admin, or compliance integrations.
public protocol BadgeEngineAnalyticsLogger: AnyObject {
    /// If true, analytics events are only logged to the console (for test/preview/QA).
    var testMode: Bool { get set }
    /// Log a badge analytics event asynchronously with audit context.
    func log(event: BadgeAnalyticsEvent, role: String?, staffID: String?, context: String?, escalate: Bool) async
    /// Fetch the most recent analytics events (buffered, capped at 20).
    func recentEvents() -> [BadgeAnalyticsEventWithAudit]
}

public struct BadgeAnalyticsEventWithAudit: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let type: String
    public let message: String
    public let modelDescription: String
    public let badge: Badge
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(event: BadgeAnalyticsEvent, role: String?, staffID: String?, context: String?, escalate: Bool) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.type = event.type
        self.message = event.message
        self.modelDescription = event.modelDescription
        self.badge = event.badge
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }
}

/// Represents a single analytics/log event for badge actions.
public struct BadgeAnalyticsEvent: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let type: String
    public let message: String
    public let modelDescription: String
    public let badge: Badge
    public init(type: String, message: String, modelDescription: String, badge: Badge, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.message = message
        self.modelDescription = modelDescription
        self.badge = badge
    }
}

/// Default analytics logger; async/await-ready, testMode for console-only, diagnostics buffer.
public final class DefaultBadgeEngineAnalyticsLogger: BadgeEngineAnalyticsLogger {
    /// If true, only logs to console (for previews/tests).
    public var testMode: Bool = false
    /// Internal buffer of recent events (last 20).
    private var buffer: [BadgeAnalyticsEventWithAudit] = []
    private let bufferLimit = 20
    private let queue = DispatchQueue(label: "BadgeEngineAnalyticsLoggerQueue")

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    /// Log an analytics event (async/await-ready) with audit context.
    public func log(event: BadgeAnalyticsEvent, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let auditEvent = BadgeAnalyticsEventWithAudit(event: event, role: role, staffID: staffID, context: context, escalate: escalate)
        queue.sync {
            buffer.append(auditEvent)
            if buffer.count > bufferLimit {
                buffer.removeFirst(buffer.count - bufferLimit)
            }
        }
        if testMode {
            print("[BadgeAnalytics][TEST] \(auditEvent.type): \(auditEvent.message) | model: \(auditEvent.modelDescription) | badge: \(auditEvent.badge.type.rawValue) | role: \(auditEvent.role ?? "nil") | staffID: \(auditEvent.staffID ?? "nil") | context: \(auditEvent.context ?? "nil") | escalate: \(auditEvent.escalate)")
        } else {
            // In production, integrate with Trust Center, Sentry, analytics, etc.
            // For demonstration, print to console (replace as needed).
            print("[BadgeAnalytics] \(auditEvent.type): \(auditEvent.message) | model: \(auditEvent.modelDescription) | badge: \(auditEvent.badge.type.rawValue) | role: \(auditEvent.role ?? "nil") | staffID: \(auditEvent.staffID ?? "nil") | context: \(auditEvent.context ?? "nil") | escalate: \(auditEvent.escalate)")
        }
    }

    /// Fetch recent analytics events.
    public func recentEvents() -> [BadgeAnalyticsEventWithAudit] {
        queue.sync { buffer }
    }
}

/// Null logger for previews/tests (does nothing).
public final class NullBadgeEngineAnalyticsLogger: BadgeEngineAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(event: BadgeAnalyticsEvent, role: String?, staffID: String?, context: String?, escalate: Bool) async { /* no-op */ }
    public func recentEvents() -> [BadgeAnalyticsEventWithAudit] { [] }
}

/// Types of badges available in Furfolio.
/// Represents predefined categories of badges that can be awarded to dogs, owners, or appointments.
/// This engine covers all badge awarding, revoking, and analytics—including retention/risk alerts.
public enum BadgeType: String, CaseIterable, Identifiable {
    case birthday
    case topSpender
    case loyaltyStar
    case newClient
    case retentionRisk
    case behaviorGood
    case behaviorChallenging
    case needsVaccine
    case custom // Use this for admin-defined or app-updated badges

    public var id: String { rawValue }

    /// Emoji or system icon for each badge.
    public var icon: String {
        switch self {
        case .birthday: return "🎂"
        case .topSpender: return "💸"
        case .loyaltyStar: return "🏆"
        case .newClient: return "✨"
        case .retentionRisk: return "⚠️"
        case .behaviorGood: return "🟢"
        case .behaviorChallenging: return "🔴"
        case .needsVaccine: return "💉"
        case .custom: return "🔖"
        }
    }

    /// User-facing label.
    public var label: String {
        switch self {
        case .birthday:
            return NSLocalizedString("badge.label.birthday", value: "Birthday", comment: "Badge label: Birthday")
        case .topSpender:
            return NSLocalizedString("badge.label.topSpender", value: "Top Spender", comment: "Badge label: Top Spender")
        case .loyaltyStar:
            return NSLocalizedString("badge.label.loyaltyStar", value: "Loyalty Star", comment: "Badge label: Loyalty Star")
        case .newClient:
            return NSLocalizedString("badge.label.newClient", value: "New Client", comment: "Badge label: New Client")
        case .retentionRisk:
            return NSLocalizedString("badge.label.retentionRisk", value: "Retention Risk", comment: "Badge label: Retention Risk")
        case .behaviorGood:
            return NSLocalizedString("badge.label.behaviorGood", value: "Good Behavior", comment: "Badge label: Good Behavior")
        case .behaviorChallenging:
            return NSLocalizedString("badge.label.behaviorChallenging", value: "Challenging Behavior", comment: "Badge label: Challenging Behavior")
        case .needsVaccine:
            return NSLocalizedString("badge.label.needsVaccine", value: "Needs Vaccine", comment: "Badge label: Needs Vaccine")
        case .custom:
            return NSLocalizedString("badge.label.custom", value: "Custom", comment: "Badge label: Custom")
        }
    }

    /// Description for tooltip or info view.
    public var description: String {
        switch self {
        case .birthday:
            return NSLocalizedString("badge.desc.birthday", value: "This pet’s birthday is this month!", comment: "Badge description: Birthday")
        case .topSpender:
            return NSLocalizedString("badge.desc.topSpender", value: "Client is among your top spenders.", comment: "Badge description: Top Spender")
        case .loyaltyStar:
            return NSLocalizedString("badge.desc.loyaltyStar", value: "This owner is a loyalty program star.", comment: "Badge description: Loyalty Star")
        case .newClient:
            return NSLocalizedString("badge.desc.newClient", value: "Recently added to Furfolio.", comment: "Badge description: New Client")
        case .retentionRisk:
            return NSLocalizedString("badge.desc.retentionRisk", value: "This client hasn’t booked in a while—reach out!", comment: "Badge description: Retention Risk")
        case .behaviorGood:
            return NSLocalizedString("badge.desc.behaviorGood", value: "Pet consistently shows good behavior.", comment: "Badge description: Good Behavior")
        case .behaviorChallenging:
            return NSLocalizedString("badge.desc.behaviorChallenging", value: "Extra care needed: challenging grooming behavior.", comment: "Badge description: Challenging Behavior")
        case .needsVaccine:
            return NSLocalizedString("badge.desc.needsVaccine", value: "Pet has a vaccination due.", comment: "Badge description: Needs Vaccine")
        case .custom:
            return NSLocalizedString("badge.desc.custom", value: "Custom badge.", comment: "Badge description: Custom")
        }
    }
}

/// Represents a badge awarded to a model (dog, owner, etc.).
/// Contains metadata about the badge type, award date, and optional notes.
public struct Badge: Identifiable, Hashable {
    public let id = UUID()
    public let type: BadgeType
    public let dateAwarded: Date
    public let notes: String?

    public init(type: BadgeType, dateAwarded: Date = Date(), notes: String? = nil) {
        self.type = type
        self.dateAwarded = dateAwarded
        self.notes = notes
    }
}

// MARK: - Preview / Mock Data Extension

public extension Badge {
    /// Provides sample badges for preview or testing purposes.
    static var previewBadges: [Badge] {
        [
            Badge(type: .birthday),
            Badge(type: .topSpender),
            Badge(type: .loyaltyStar),
            Badge(type: .newClient),
            Badge(type: .retentionRisk),
            Badge(type: .behaviorGood),
            Badge(type: .behaviorChallenging),
            Badge(type: .needsVaccine),
            Badge(type: .custom, notes: NSLocalizedString("badge.preview.notes.specialEvent", value: "Special event", comment: "Preview badge notes: Special event"))
        ]
    }
}
// ... Existing imports, enums, BadgeType and Badge structs remain ...
// MARK: - ENHANCED: BadgeType Analytics, Criticality, Accessibility

public extension BadgeType {
    /// Tokenized tag for analytics, automation, and segmentation.
    var badgeTag: String { rawValue }

    /// Priority score for analytics/alerts (higher = more important)
    var priorityScore: Int {
        switch self {
        case .retentionRisk: return 3
        case .needsVaccine: return 2
        case .behaviorChallenging: return 2
        case .topSpender, .loyaltyStar: return 1
        case .birthday, .newClient, .behaviorGood: return 0
        case .custom: return -1
        }
    }

    /// Whether this badge signals risk or critical attention (for Trust Center/alerts)
    var isCritical: Bool {
        self == .retentionRisk || self == .needsVaccine || self == .behaviorChallenging
    }

    /// Accessibility/VoiceOver summary for each badge
    var accessibilityLabel: String {
        switch self {
        case .retentionRisk:
            return NSLocalizedString("badge.accessibility.retentionRisk", value: "Retention risk: client hasn't booked in a while.", comment: "Accessibility: Retention risk badge")
        case .needsVaccine:
            return NSLocalizedString("badge.accessibility.needsVaccine", value: "Pet needs vaccination.", comment: "Accessibility: Needs vaccine badge")
        case .behaviorChallenging:
            return NSLocalizedString("badge.accessibility.behaviorChallenging", value: "Challenging behavior recorded.", comment: "Accessibility: Challenging behavior badge")
        case .behaviorGood:
            return NSLocalizedString("badge.accessibility.behaviorGood", value: "Good behavior.", comment: "Accessibility: Good behavior badge")
        case .birthday:
            return NSLocalizedString("badge.accessibility.birthday", value: "Birthday this month.", comment: "Accessibility: Birthday badge")
        case .loyaltyStar:
            return NSLocalizedString("badge.accessibility.loyaltyStar", value: "Loyalty star client.", comment: "Accessibility: Loyalty star badge")
        case .topSpender:
            return NSLocalizedString("badge.accessibility.topSpender", value: "Top spender.", comment: "Accessibility: Top spender badge")
        case .newClient:
            return NSLocalizedString("badge.accessibility.newClient", value: "Recently added client.", comment: "Accessibility: New client badge")
        case .custom:
            return NSLocalizedString("badge.accessibility.custom", value: "Custom badge.", comment: "Accessibility: Custom badge")
        }
    }
}

public extension Badge {
    /// All tags (BadgeType, plus user/app tokens if desired)
    var tags: [String] { [type.badgeTag] }

    /// Analytics: Is this badge "critical"?
    var isCritical: Bool { type.isCritical }

    /// Score for analytics/prioritization.
    var priorityScore: Int { type.priorityScore }

    /// Accessibility label for UI and VoiceOver.
    var accessibilityLabel: String {
        "\(type.label). \(type.accessibilityLabel)"
    }

    /// JSON export for audit/integration/reporting.
    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID, type: String, dateAwarded: Date, notes: String?
        }
        let export = Export(id: id, type: type.rawValue, dateAwarded: dateAwarded, notes: notes)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - ENHANCED: BadgeEngine Analytics, Audit, Quick Filters

public extension BadgeEngine {
    /// Returns only "critical" badges (risk, needs vaccine, etc.)
    func filterCritical(_ badges: [Badge]) -> [Badge] {
        badges.filter { $0.isCritical }
    }
    /// Returns badges awarded in the last X days.
    func filterRecent(_ badges: [Badge], withinDays days: Int = 30) -> [Badge] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return badges.filter { $0.dateAwarded >= cutoff }
    }
    /// Returns badges of a specific type.
    func filter(byType type: BadgeType, in badges: [Badge]) -> [Badge] {
        badges.filter { $0.type == type }
    }

    /// Quick badge analytics: badge counts by type.
    func badgeCounts(_ badges: [Badge]) -> [BadgeType: Int] {
        Dictionary(grouping: badges, by: { $0.type }).mapValues(\.count)
    }
}

// MARK: - ENHANCED: Auditing trail for badge awards/revocations

public extension BadgeEngine {
    private static let badgeAuditLogKey = "BadgeEngine_AuditLog"
    /// Simple audit: record a badge event in UserDefaults (replace with database as needed)
    func recordAuditEvent(_ action: String, badge: Badge, recipient: Any) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let desc = String(format: NSLocalizedString("badge.audit.event", value: "[%@] %@: %@ to %@", comment: "Audit log event. Params: timestamp, action, badge label, recipient"),
                          stamp, NSLocalizedString("badge.audit.\(action.lowercased())", value: action, comment: "Audit action (Awarded/Revoked)"),
                          badge.type.label, String(describing: recipient))
        var log = UserDefaults.standard.stringArray(forKey: Self.badgeAuditLogKey) ?? []
        log.append(desc)
        UserDefaults.standard.set(log, forKey: Self.badgeAuditLogKey)
    }

    /// Retrieve audit log (for reporting or trust center)
    func getAuditLog() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.badgeAuditLogKey) ?? []
    }
}

// MARK: - ENHANCED: Override audit() and auditRevocation() to also record audit trail

extension BadgeEngine {
    /// Audit a badge award event (calls analytics logger, audit hooks, notifications).
    private func audit(badge: Badge, for model: Any) {
        badgeAwardedHandler?(badge, model)
        NotificationCenter.default.post(name: .badgeAwarded, object: self, userInfo: ["badge": badge, "model": model])
        recordAuditEvent("Awarded", badge: badge, recipient: model)
        // Analytics logging (if available)
        let event = BadgeAnalyticsEvent(
            type: NSLocalizedString("badge.analytics.awarded", value: "Awarded", comment: "Analytics type: Awarded"),
            message: String(format: NSLocalizedString("badge.analytics.awarded.message", value: "Badge %@ awarded to %@", comment: "Analytics message: badge awarded. Params: badge label, model"), badge.type.label, String(describing: model)),
            modelDescription: String(describing: model),
            badge: badge
        )
        let role = BadgeEngineAuditContext.role
        let staffID = BadgeEngineAuditContext.staffID
        let context = BadgeEngineAuditContext.context
        let escalate = (
            event.type.lowercased().contains("danger") ||
            event.type.lowercased().contains("critical") ||
            event.type.lowercased().contains("delete") ||
            event.message.lowercased().contains("danger") ||
            event.message.lowercased().contains("critical") ||
            event.message.lowercased().contains("delete") ||
            badge.type.isCritical
        )
        Task {
            await analyticsLogger?.log(event: event, role: role, staffID: staffID, context: context, escalate: escalate)
        }
    }
    /// Audit a badge revocation event (calls analytics logger, audit hooks, notifications).
    private func auditRevocation(badge: Badge, for model: Any) {
        badgeRevokedHandler?(badge, model)
        NotificationCenter.default.post(name: .badgeRevoked, object: self, userInfo: ["badge": badge, "model": model])
        recordAuditEvent("Revoked", badge: badge, recipient: model)
        // Analytics logging (if available)
        let event = BadgeAnalyticsEvent(
            type: NSLocalizedString("badge.analytics.revoked", value: "Revoked", comment: "Analytics type: Revoked"),
            message: String(format: NSLocalizedString("badge.analytics.revoked.message", value: "Badge %@ revoked from %@", comment: "Analytics message: badge revoked. Params: badge label, model"), badge.type.label, String(describing: model)),
            modelDescription: String(describing: model),
            badge: badge
        )
        let role = BadgeEngineAuditContext.role
        let staffID = BadgeEngineAuditContext.staffID
        let context = BadgeEngineAuditContext.context
        let escalate = (
            event.type.lowercased().contains("danger") ||
            event.type.lowercased().contains("critical") ||
            event.type.lowercased().contains("delete") ||
            event.message.lowercased().contains("danger") ||
            event.message.lowercased().contains("critical") ||
            event.message.lowercased().contains("delete") ||
            badge.type.isCritical
        )
        Task {
            await analyticsLogger?.log(event: event, role: role, staffID: staffID, context: context, escalate: escalate)
        }
    }
}

// MARK: - BadgeEngine

/// BadgeEngine computes and manages awarding and revoking badges.
/// Thread-safe singleton class responsible for business logic related to awarding, revoking badges and analytics.
/// Supports injection of custom badge assignment rules and auditing hooks.
/// This engine fully covers all badge awarding, revoking, and analytics—including retention/risk alerts.
@MainActor
public final class BadgeEngine {

    // MARK: - Singleton Instance

    /// Shared singleton instance of BadgeEngine.
    public static let shared = BadgeEngine()

    private init() {}

    // MARK: - Types

    /// Type alias for custom badge assignment closure.
    /// Allows injecting custom business logic to award badges for a given model.
    public typealias CustomBadgeLogic<T> = (T) -> [Badge]

    /// Type alias for custom badge revocation closure.
    /// Allows injecting custom business logic to revoke badges from a given model.
    public typealias CustomBadgeRevocationLogic<T> = (T, Badge) -> Bool

    // MARK: - Properties

    /// Custom badge assignment logic for dogs.
    /// Can be set by business logic to extend or override default dog badge rules.
    public var customDogBadgeLogic: CustomBadgeLogic<Dog>?

    /// Custom badge assignment logic for owners.
    /// Can be set by business logic to extend or override default owner badge rules.
    public var customOwnerBadgeLogic: CustomBadgeLogic<DogOwner>?

    /// Custom badge assignment logic for appointments.
    /// Can be set by business logic to extend or override default appointment badge rules.
    public var customAppointmentBadgeLogic: CustomBadgeLogic<Appointment>?

    /// Closure called whenever a badge is awarded.
    /// Provides an audit hook for logging or analytics.
    public var badgeAwardedHandler: ((Badge, Any) -> Void)?

    /// Closure called whenever a badge is revoked.
    /// Provides an audit hook for logging or analytics.
    public var badgeRevokedHandler: ((Badge, Any) -> Void)?

    /// Analytics logger for badge events (admin/diagnostics/Trust Center).
    /// Set to NullBadgeEngineAnalyticsLogger() for tests/previews.
    public var analyticsLogger: BadgeEngineAnalyticsLogger? = DefaultBadgeEngineAnalyticsLogger()

    // MARK: - Badge Assignment Logic (Dog)

    /// Returns badges for a given dog.
    ///
    /// - Parameter dog: The dog model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// This method is modular, tokenized, and fully auditable. All logic and styling for badge determination
    /// should use the app’s business logic engines. All badge assignment or display must be accessible,
    /// localized, and maintainable.
    ///
    /// **Add new dog badge rules in this method or via `customDogBadgeLogic`.**
    public func badges(for dog: Dog) -> [Badge] {
        // TODO: Refactor to move all hardcoded logic to dedicated badge rule engines,
        // allow dynamic badge rule configuration, and support tokenized badge presentation via design system.
        var awarded: [Badge] = []

        // Birthday Badge:
        // Award if the dog's birthdate month matches the current month.
        if let birthday = dog.birthdate,
           Calendar.current.isDate(birthday, equalTo: Date(), toGranularity: .month) {
            let badge = Badge(type: .birthday)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Behavior Badges:
        // Award good behavior badge if any positive mood behavior logs exist.
        if let logs = dog.behaviorLogs,
           logs.contains(where: { $0.mood == .positive }) {
            let badge = Badge(type: .behaviorGood)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Award challenging behavior badge if any aggressive mood behavior logs exist.
        if let logs = dog.behaviorLogs,
           logs.contains(where: { $0.mood == .aggressive }) {
            let badge = Badge(type: .behaviorChallenging)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Needs Vaccine Badge:
        // Award if any vaccination record is due.
        if let vaccines = dog.vaccinationRecords,
           vaccines.contains(where: { $0.isDue }) {
            let badge = Badge(type: .needsVaccine)
            awarded.append(badge)
            audit(badge: badge, for: dog)
        }

        // Insert additional dog-specific badge assignment logic here...

        // Apply custom dog badge logic if provided.
        if let customLogic = customDogBadgeLogic {
            let customBadges = customLogic(dog)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: dog)
            }
        }

        return awarded
    }

    /// Returns badges for a given owner.
    ///
    /// - Parameter owner: The dog owner model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// **Add new owner badge rules in this method or via `customOwnerBadgeLogic`.**
    public func badges(for owner: DogOwner) -> [Badge] {
        var awarded: [Badge] = []

        // New Client Badge:
        // Award if the owner was added within the last 14 days.
        if let created = owner.dateAdded,
           Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 99 < 14 {
            let badge = Badge(type: .newClient)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Loyalty Star Badge:
        // Award if the owner has completed 10 or more appointments.
        if let count = owner.completedAppointments?.count,
           count >= 10 {
            let badge = Badge(type: .loyaltyStar)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Top Spender Badge:
        // Award if the total spent by the owner exceeds 500.
        if let total = owner.totalSpent,
           total > 500 {
            let badge = Badge(type: .topSpender)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Retention Risk Badge:
        // Award if the owner's last appointment was over 60 days ago.
        if let last = owner.lastAppointmentDate,
           Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0 > 60 {
            let badge = Badge(type: .retentionRisk)
            awarded.append(badge)
            audit(badge: badge, for: owner)
        }

        // Insert additional owner-specific badge assignment logic here...

        // Apply custom owner badge logic if provided.
        if let customLogic = customOwnerBadgeLogic {
            let customBadges = customLogic(owner)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: owner)
            }
        }

        return awarded
    }

    /// Returns badges for an appointment (example: behavioral).
    ///
    /// - Parameter appointment: The appointment model to evaluate.
    /// - Returns: An array of awarded badges based on predefined and custom logic.
    ///
    /// **Add new appointment badge rules in this method or via `customAppointmentBadgeLogic`.**
    public func badges(for appointment: Appointment) -> [Badge] {
        var awarded: [Badge] = []

        // Behavior Badge:
        // Award badges based on the mood recorded in the appointment's behavior log.
        if let behavior = appointment.behaviorLog?.mood {
            switch behavior {
            case .positive:
                let badge = Badge(type: .behaviorGood)
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            case .aggressive:
                let badge = Badge(type: .behaviorChallenging)
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            default:
                break
            }
        }

        // Insert additional appointment-specific badge assignment logic here...

        // Apply custom appointment badge logic if provided.
        if let customLogic = customAppointmentBadgeLogic {
            let customBadges = customLogic(appointment)
            for badge in customBadges {
                awarded.append(badge)
                audit(badge: badge, for: appointment)
            }
        }

        return awarded
    }

    // MARK: - Badge Revocation Logic

    /// Revokes a badge from a given model (dog, owner, appointment).
    ///
    /// - Parameters:
    ///   - badge: The badge to revoke.
    ///   - model: The model instance (Dog, DogOwner, Appointment) from which to revoke the badge.
    ///
    /// This method enables centralized badge revocation, completing the full badge lifecycle management.
    public func revokeBadge(_ badge: Badge, from model: Any) {
        // Perform revocation logic here.
        // Since Badge instances are immutable and models are external,
        // actual removal should be handled by the caller's data store or model layer.
        // This method triggers the auditRevocation hook and posts notifications for analytics.

        auditRevocation(badge: badge, for: model)
    }

    // MARK: - Utility Methods

    /// Human-readable string summary for a list of badges.
    ///
    /// - Parameter badges: The badges to summarize.
    /// - Returns: A concatenated string of badge icons and labels.
    public func badgeSummary(_ badges: [Badge]) -> String {
        badges.map { "\($0.type.icon) \($0.type.label)" }.joined(separator: NSLocalizedString("badge.summary.separator", value: "   ", comment: "Separator between badges in summary"))
    }

    // MARK: - Auditing

    /// Internal method to trigger auditing hooks when a badge is awarded.
    ///
    /// - Parameters:
    ///   - badge: The badge awarded.
    ///   - model: The model instance (Dog, DogOwner, Appointment) the badge was awarded for.
    // See extension above for audit and auditRevocation (with analytics logger)
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Notification posted when a badge is awarded.
    static let badgeAwarded = Notification.Name("BadgeEngineBadgeAwardedNotification")

    /// Notification posted when a badge is revoked.
    static let badgeRevoked = Notification.Name("BadgeEngineBadgeRevokedNotification")
}

// MARK: - SwiftUI PreviewProvider (Diagnostics, Accessibility, Test Mode)
#if canImport(SwiftUI)
import SwiftUI

/// PreviewProvider demonstrating BadgeEngine with analytics testMode, accessibility, and diagnostics buffer.
struct BadgeEngine_Previews: PreviewProvider {
    static var previewLogger: DefaultBadgeEngineAnalyticsLogger = {
        let logger = DefaultBadgeEngineAnalyticsLogger(testMode: true)
        return logger
    }()

    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("badge.preview.title", value: "BadgeEngine Diagnostics Preview", comment: "Preview title"))
                .font(.headline)
            Text(NSLocalizedString("badge.preview.testmode", value: "Analytics Logger Test Mode: ON", comment: "Preview: testMode enabled"))
                .foregroundColor(.orange)
            Divider()
            ForEach(Badge.previewBadges) { badge in
                HStack {
                    Text("\(badge.type.icon)")
                        .accessibilityLabel(Text(badge.accessibilityLabel))
                    VStack(alignment: .leading) {
                        Text(badge.type.label)
                        Text(badge.type.description).font(.footnote).foregroundColor(.secondary)
                        Text(NSLocalizedString("badge.preview.accessibility", value: "Accessibility: ", comment: "Preview: accessibility label")) +
                            Text(badge.accessibilityLabel).italic().font(.caption)
                    }
                }
                .onAppear {
                    Task {
                        await previewLogger.log(
                            event: BadgeAnalyticsEvent(
                                type: NSLocalizedString("badge.analytics.preview", value: "Preview", comment: "Analytics type: Preview"),
                                message: String(format: NSLocalizedString("badge.analytics.preview.message", value: "Preview badge: %@", comment: "Analytics message: preview badge. Param: badge label"), badge.type.label),
                                modelDescription: "Preview",
                                badge: badge
                            ),
                            role: BadgeEngineAuditContext.role,
                            staffID: BadgeEngineAuditContext.staffID,
                            context: BadgeEngineAuditContext.context,
                            escalate: (
                                "preview".contains("danger") ||
                                "preview".contains("critical") ||
                                "preview".contains("delete") ||
                                badge.type.isCritical
                            )
                        )
                    }
                }
            }
            Divider()
            Text(NSLocalizedString("badge.preview.diagnostics", value: "Recent Analytics Events (Diagnostics Buffer):", comment: "Preview: diagnostics buffer title"))
                .font(.subheadline)
            ScrollView {
                ForEach(previewLogger.recentEvents()) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.type): \(event.message)")
                            .font(.caption)
                        Text("Model: \(event.modelDescription)").font(.caption2)
                        Text("Badge: \(event.badge.type.label)").font(.caption2)
                        Text("Role: \(event.role ?? "nil") | StaffID: \(event.staffID ?? "nil")").font(.caption2)
                        Text("Context: \(event.context ?? "nil") | Escalate: \(event.escalate ? "Yes" : "No")").font(.caption2)
                        Text(event.timestamp, style: .time)
                            .font(.caption2).foregroundColor(.gray)
                    }
                    .padding(.bottom, 2)
                }
            }.frame(maxHeight: 160)
        }
        .padding()
        .onAppear {
            // Ensure analyticsLogger is set to previewLogger for demonstration.
            BadgeEngine.shared.analyticsLogger = previewLogger
        }
    }
}
#endif
