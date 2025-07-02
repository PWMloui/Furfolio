//
//  Badge.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct BadgeAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Badge"
}

public struct BadgeAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let badgeID: UUID
    public let badgeType: String
    public let entityType: String?
    public let entityID: UUID?
    public let awardedBy: UUID?
    public let status: String
    public let error: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        badgeID: UUID,
        badgeType: String,
        entityType: String?,
        entityID: UUID?,
        awardedBy: UUID?,
        status: String,
        error: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.badgeID = badgeID
        self.badgeType = badgeType
        self.entityType = entityType
        self.entityID = entityID
        self.awardedBy = awardedBy
        self.status = status
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = "[\(dateStr)] Badge \(operation) [\(status)]"
        let details = [
            "BadgeID: \(badgeID)",
            "Type: \(badgeType)",
            entityType != nil ? "EntityType: \(entityType!)" : nil,
            entityID != nil ? "EntityID: \(entityID!)" : nil,
            awardedBy != nil ? "AwardedBy: \(awardedBy!)" : nil,
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class BadgeAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.badge.audit.logger")
    private static var log: [BadgeAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        operation: String,
        badge: Badge,
        status: String,
        error: String? = nil
    ) {
        let escalate = operation.lowercased().contains("danger") || operation.lowercased().contains("critical") || operation.lowercased().contains("delete") || (error?.lowercased().contains("danger") ?? false)
        let event = BadgeAuditEvent(
            timestamp: Date(),
            operation: operation,
            badgeID: badge.id,
            badgeType: badge.type.rawValue,
            entityType: badge.entityType,
            entityID: badge.entityID,
            awardedBy: badge.awardedBy,
            status: status,
            error: error,
            role: BadgeAuditContext.role,
            staffID: BadgeAuditContext.staffID,
            context: BadgeAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([BadgeAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    public static func exportLogJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(log)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
}

// MARK: - Analytics/Audit Protocol

public protocol BadgeAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
    func log(event: String, info: [String: Any]?) async
}
public struct NullBadgeAnalyticsLogger: BadgeAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol BadgeTrustCenterDelegate {
    func permission(for action: String, badge: Badge, context: [String: Any]?) -> Bool
    func permission(for action: String, badge: Badge, context: [String: Any]?) async -> Bool
}
public struct NullBadgeTrustCenterDelegate: BadgeTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, badge: Badge, context: [String: Any]?) -> Bool { true }
    public func permission(for action: String, badge: Badge, context: [String: Any]?) async -> Bool { true }
}

// MARK: - BadgeType (unchanged, but always add to this enum ONLY)

enum BadgeType: String, CaseIterable, Identifiable, Codable {
    case birthday
    case topSpender
    case loyaltyStar
    case newClient
    case retentionRisk
    case behaviorGood
    case behaviorChallenging
    case needsVaccine
    case custom

    var id: String { rawValue }

    var icon: String {
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

    var label: String {
        switch self {
        case .birthday: return "Birthday"
        case .topSpender: return "Top Spender"
        case .loyaltyStar: return "Loyalty Star"
        case .newClient: return "New Client"
        case .retentionRisk: return "Retention Risk"
        case .behaviorGood: return "Good Behavior"
        case .behaviorChallenging: return "Challenging Behavior"
        case .needsVaccine: return "Needs Vaccine"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .birthday: return "It's this pet’s birthday month!"
        case .topSpender: return "This owner is among your top spenders."
        case .loyaltyStar: return "This owner is a loyalty program star."
        case .newClient: return "Recently added to Furfolio."
        case .retentionRisk: return "This client hasn’t booked in a while."
        case .behaviorGood: return "Pet consistently shows good behavior."
        case .behaviorChallenging: return "Challenging grooming behavior."
        case .needsVaccine: return "Pet has a vaccination due."
        case .custom: return "Custom badge."
        }
    }
}

// MARK: - Badge

struct Badge: Identifiable, Codable, Hashable, Equatable {
    // MARK: - Identifiers
    let id: UUID
    let type: BadgeType
    let dateAwarded: Date
    let notes: String?
    let entityType: String?
    let entityID: UUID?
    let awardedBy: UUID?
    let customIcon: String?
    let customLabel: String?

    // MARK: - Audit/Analytics/Trust Center Injectables
    static var analyticsLogger: BadgeAnalyticsLogger = NullBadgeAnalyticsLogger()
    static var trustCenterDelegate: BadgeTrustCenterDelegate = NullBadgeTrustCenterDelegate()

    // MARK: - Initialization

    init(
        type: BadgeType,
        dateAwarded: Date = Date(),
        notes: String? = nil,
        entityType: String? = nil,
        entityID: UUID? = nil,
        awardedBy: UUID? = nil,
        customIcon: String? = nil,
        customLabel: String? = nil,
        auditTag: String? = nil
    ) async {
        let badge = Self._newInstance(
            type: type, dateAwarded: dateAwarded, notes: notes,
            entityType: entityType, entityID: entityID,
            awardedBy: awardedBy, customIcon: customIcon, customLabel: customLabel
        )

        let permitted = await Self.checkPermission(for: "create", badge: badge, context: ["auditTag": auditTag as Any])
        guard permitted else {
            await Self.logAsync(event: "badge_create_denied", info: [
                "type": type.rawValue,
                "entityType": entityType as Any,
                "entityID": entityID as Any,
                "awardedBy": awardedBy as Any,
                "auditTag": auditTag as Any
            ])
            BadgeAuditLogger.record(operation: "create_denied", badge: badge, status: "denied")
            fatalError("Badge creation denied by Trust Center.")
        }
        self = badge
        await Self.logAsync(event: "badge_created", info: [
            "type": type.rawValue,
            "entityType": entityType as Any,
            "entityID": entityID as Any,
            "awardedBy": awardedBy as Any,
            "auditTag": auditTag as Any
        ])
        BadgeAuditLogger.record(operation: "create", badge: badge, status: "created")
    }

    private static func _newInstance(
        type: BadgeType,
        dateAwarded: Date,
        notes: String?,
        entityType: String?,
        entityID: UUID?,
        awardedBy: UUID?,
        customIcon: String?,
        customLabel: String?
    ) -> Badge {
        Badge(
            id: UUID(),
            type: type,
            dateAwarded: dateAwarded,
            notes: notes,
            entityType: entityType,
            entityID: entityID,
            awardedBy: awardedBy,
            customIcon: customIcon,
            customLabel: customLabel
        )
    }

    var displayString: String {
        let iconToUse = customIcon ?? type.icon
        let labelToUse = customLabel ?? type.label
        return "\(iconToUse) \(labelToUse)"
    }

    var accessibilityLabel: String {
        "\(customLabel ?? type.label) badge, \(type.description)"
    }

    static func birthdayBadge(
        for entityType: String,
        entityID: UUID,
        awardedBy: UUID? = nil,
        auditTag: String? = nil
    ) async -> Badge {
        await Badge(type: .birthday, entityType: entityType, entityID: entityID, awardedBy: awardedBy, auditTag: auditTag)
    }

    static func behaviorBadge(
        isGoodBehavior: Bool,
        for entityType: String,
        entityID: UUID,
        notes: String? = nil,
        awardedBy: UUID? = nil,
        auditTag: String? = nil
    ) async -> Badge {
        let badgeType: BadgeType = isGoodBehavior ? .behaviorGood : .behaviorChallenging
        return await Badge(type: badgeType, notes: notes, entityType: entityType, entityID: entityID, awardedBy: awardedBy, auditTag: auditTag)
    }

    func revoke(by user: UUID?, auditTag: String? = nil) async -> Badge? {
        let permitted = await Self.checkPermission(for: "revoke", badge: self, context: [
            "revokedBy": user as Any,
            "auditTag": auditTag as Any
        ])
        guard permitted else {
            await Self.logAsync(event: "badge_revoke_denied", info: [
                "id": id.uuidString,
                "type": type.rawValue,
                "revokedBy": user as Any,
                "auditTag": auditTag as Any
            ])
            BadgeAuditLogger.record(operation: "revoke_denied", badge: self, status: "denied")
            return nil
        }
        await Self.logAsync(event: "badge_revoked", info: [
            "id": id.uuidString,
            "type": type.rawValue,
            "revokedBy": user as Any,
            "auditTag": auditTag as Any
        ])
        BadgeAuditLogger.record(operation: "revoke", badge: self, status: "revoked")
        return nil
    }

    func copyWithUpdates(
        type: BadgeType? = nil,
        notes: String?? = nil,
        customIcon: String?? = nil,
        customLabel: String?? = nil,
        auditTag: String? = nil
    ) async -> Badge {
        let updatedBadge = Badge(
            id: self.id,
            type: type ?? self.type,
            dateAwarded: self.dateAwarded,
            notes: notes ?? self.notes,
            entityType: self.entityType,
            entityID: self.entityID,
            awardedBy: self.awardedBy,
            customIcon: customIcon ?? self.customIcon,
            customLabel: customLabel ?? self.customLabel
        )

        let permitted = await Self.checkPermission(for: "update", badge: updatedBadge, context: ["auditTag": auditTag as Any])
        guard permitted else {
            await Self.logAsync(event: "badge_update_denied", info: [
                "id": id.uuidString,
                "type": updatedBadge.type.rawValue,
                "auditTag": auditTag as Any
            ])
            BadgeAuditLogger.record(operation: "update_denied", badge: updatedBadge, status: "denied")
            return self
        }
        await Self.logAsync(event: "badge_updated", info: [
            "id": id.uuidString,
            "type": updatedBadge.type.rawValue,
            "auditTag": auditTag as Any
        ])
        BadgeAuditLogger.record(operation: "update", badge: updatedBadge, status: "updated")
        return updatedBadge
    }

    static func logAsync(event: String, info: [String: Any]?) async {
        Task.detached {
            await analyticsLogger.log(event: event, info: info)
        }
    }

    static func checkPermission(for action: String, badge: Badge, context: [String: Any]?) async -> Bool {
        await trustCenterDelegate.permission(for: action, badge: badge, context: context)
    }
}

// MARK: - Unit Test Stubs

#if DEBUG
import XCTest

final class BadgeAsyncTests: XCTestCase {
    func testAsyncLogging() async {
        class TestLogger: BadgeAnalyticsLogger {
            var loggedEvents: [(String, [String: Any]?)] = []
            func log(event: String, info: [String : Any]?) {
                loggedEvents.append((event, info))
            }
            func log(event: String, info: [String : Any]?) async {
                loggedEvents.append((event, info))
            }
        }
        let logger = TestLogger()
        Badge.analyticsLogger = logger
        await Badge.logAsync(event: "test_event", info: ["key": "value"])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(logger.loggedEvents.contains(where: { $0.0 == "test_event" }))
    }

    func testAsyncPermissionCheck() async {
        class TestDelegate: BadgeTrustCenterDelegate {
            func permission(for action: String, badge: Badge, context: [String : Any]?) -> Bool {
                false
            }
            func permission(for action: String, badge: Badge, context: [String : Any]?) async -> Bool {
                return action == "create"
            }
        }
        Badge.trustCenterDelegate = TestDelegate()
        let badge = Badge._newInstance(type: .birthday, dateAwarded: Date(), notes: nil, entityType: nil, entityID: nil, awardedBy: nil, customIcon: nil, customLabel: nil)
        let permitted = await Badge.checkPermission(for: "create", badge: badge, context: nil)
        XCTAssertTrue(permitted)
        let denied = await Badge.checkPermission(for: "revoke", badge: badge, context: nil)
        XCTAssertFalse(denied)
    }

    func testAsyncRevoke() async {
        class TestDelegate: BadgeTrustCenterDelegate {
            func permission(for action: String, badge: Badge, context: [String : Any]?) -> Bool {
                true
            }
            func permission(for action: String, badge: Badge, context: [String : Any]?) async -> Bool {
                return true
            }
        }
        class TestLogger: BadgeAnalyticsLogger {
            var events: [String] = []
            func log(event: String, info: [String : Any]?) {}
            func log(event: String, info: [String : Any]?) async {
                events.append(event)
            }
        }
        Badge.trustCenterDelegate = TestDelegate()
        let logger = TestLogger()
        Badge.analyticsLogger = logger
        let badge = Badge._newInstance(type: .birthday, dateAwarded: Date(), notes: nil, entityType: nil, entityID: nil, awardedBy: nil, customIcon: nil, customLabel: nil)
        let result = await badge.revoke(by: UUID(), auditTag: "test_audit")
        XCTAssertNil(result)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(logger.events.contains("badge_revoked"))
    }
}
#endif
