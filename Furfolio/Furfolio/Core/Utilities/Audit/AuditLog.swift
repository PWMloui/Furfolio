//
//  AuditLog.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

/**
 AuditLog
 --------
 Enhanced audit log model with async analytics, trust-center checks, in-memory audit actor, and diagnostics.

 - **Concurrency & Async Logging**: Analytics calls are now async; uses `AuditLogAuditManager` actor for in-memory audit entries.
 - **Trust Center**: Synchronous permission checks retained.
 - **Diagnostics & Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics/Audit Protocol

public protocol AuditLogAnalyticsLogger {
    /// Log an audit event asynchronously.
    func log(event: String, info: [String: Any]?) async
}
public struct NullAuditLogAnalyticsLogger: AuditLogAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol AuditLogTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullAuditLogTrustCenterDelegate: AuditLogTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - In-Memory Audit Actor

/// A record of an in-memory audit event.
public struct AuditLogAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let info: [String: Any]?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, info: [String: Any]?) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.info = info
    }
}

/// Concurrency-safe actor for recording in-memory audit log events.
public actor AuditLogAuditManager {
    private var buffer: [AuditLogAuditEntry] = []
    private let maxEntries = 100
    public static let shared = AuditLogAuditManager()

    /// Add a new audit entry, trimming oldest beyond maxEntries.
    public func add(_ entry: AuditLogAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to limit.
    public func recent(limit: Int = 20) -> [AuditLogAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as pretty-printed JSON.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - AuditLog (Enterprise Enhanced)

@Model
final class AuditLog: Identifiable, ObservableObject {
    // MARK: - Primary Attributes
    @Attribute(.unique) var id: UUID = UUID()
    var timestamp: Date = Date()
    var actionType: AuditActionType
    var entityType: AuditEntityType
    var entityID: String
    var summary: String
    var details: String?
    var user: String?

    // MARK: - Relationships to Entities
    @Relationship(inverse: \DogOwner.auditLogs)
    var dogOwner: DogOwner?
    @Relationship(inverse: \Dog.auditLogs)
    var dog: Dog?
    @Relationship(inverse: \Appointment.auditLogs)
    var appointment: Appointment?
    @Relationship(inverse: \Charge.auditLogs)
    var charge: Charge?
    @Relationship(inverse: \User.auditLogs)
    var userEntity: User?
    @Relationship(inverse: \Task.auditLogs)
    var task: Task?
    @Relationship(inverse: \Setting.auditLogs)
    var setting: Setting?
    @Relationship(inverse: \Business.auditLogs)
    var business: Business?
    @Relationship
    var customEntity: AnyObject?

    // MARK: - Analytics/Trust Center (Injectable)
    static var analyticsLogger: AuditLogAnalyticsLogger = NullAuditLogAnalyticsLogger()
    static var trustCenterDelegate: AuditLogTrustCenterDelegate = NullAuditLogTrustCenterDelegate()

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: AuditActionType,
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        details: String? = nil,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        auditTag: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.entityType = entityType
        self.entityID = entityID
        self.summary = summary
        self.details = details
        self.user = user
        self.dogOwner = dogOwner
        self.dog = dog
        self.appointment = appointment
        self.charge = charge
        self.userEntity = userEntity
        self.task = task
        self.setting = setting
        self.business = business
        self.customEntity = customEntity

        // Log creation
        Task {
            let info: [String: Any] = [
                "actionType": actionType.rawValue,
                "entityType": entityType.rawValue,
                "entityID": entityID,
                "user": user as Any,
                "auditTag": auditTag as Any
            ]
            await Self.analyticsLogger.log(event: "created", info: info)
            await AuditLogAuditManager.shared.add(
                AuditLogAuditEntry(event: "created", info: info)
            )
        }
    }

    // MARK: - Mutation/Audit Methods

    func updateDetails(_ newDetails: String, by user: String, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateDetails", context: [
            "id": id.uuidString,
            "user": user,
            "auditTag": auditTag as Any
        ]) else {
            Task {
                let info: [String: Any] = [
                    "id": id.uuidString,
                    "user": user,
                    "auditTag": auditTag as Any
                ]
                await Self.analyticsLogger.log(event: "updateDetails_denied", info: info)
                await AuditLogAuditManager.shared.add(
                    AuditLogAuditEntry(event: "updateDetails_denied", info: info)
                )
            }
            return
        }
        self.details = newDetails
        Task {
            let info: [String: Any] = [
                "id": id.uuidString,
                "user": user,
                "auditTag": auditTag as Any
            ]
            await Self.analyticsLogger.log(event: "updateDetails", info: info)
            await AuditLogAuditManager.shared.add(
                AuditLogAuditEntry(event: "updateDetails", info: info)
            )
        }
    }

    // MARK: - Computed Properties

    var shortLabel: String {
        "\(actionType.displayName) \(entityType.displayName)"
    }

    // MARK: - Static Helpers for Common Audit Log Creation

    static func created(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil,
        auditTag: String? = nil
    ) -> AuditLog {
        guard trustCenterDelegate.permission(for: "create", context: [
            "entityType": entityType.rawValue,
            "entityID": entityID,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            analyticsLogger.log(event: "create_denied", info: [
                "entityType": entityType.rawValue,
                "entityID": entityID,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            fatalError("AuditLog creation denied by Trust Center.")
        }
        return AuditLog(
            actionType: .create,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity,
            auditTag: auditTag
        )
    }

    static func updated(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil,
        auditTag: String? = nil
    ) -> AuditLog {
        guard trustCenterDelegate.permission(for: "update", context: [
            "entityType": entityType.rawValue,
            "entityID": entityID,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            analyticsLogger.log(event: "update_denied", info: [
                "entityType": entityType.rawValue,
                "entityID": entityID,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            fatalError("AuditLog update denied by Trust Center.")
        }
        return AuditLog(
            actionType: .update,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity,
            auditTag: auditTag
        )
    }

    static func deleted(
        entityType: AuditEntityType,
        entityID: String,
        summary: String,
        user: String? = nil,
        dogOwner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        charge: Charge? = nil,
        userEntity: User? = nil,
        task: Task? = nil,
        setting: Setting? = nil,
        business: Business? = nil,
        customEntity: AnyObject? = nil,
        details: String? = nil,
        auditTag: String? = nil
    ) -> AuditLog {
        guard trustCenterDelegate.permission(for: "delete", context: [
            "entityType": entityType.rawValue,
            "entityID": entityID,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            analyticsLogger.log(event: "delete_denied", info: [
                "entityType": entityType.rawValue,
                "entityID": entityID,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            fatalError("AuditLog delete denied by Trust Center.")
        }
        return AuditLog(
            actionType: .delete,
            entityType: entityType,
            entityID: entityID,
            summary: summary,
            details: details,
            user: user,
            dogOwner: dogOwner,
            dog: dog,
            appointment: appointment,
            charge: charge,
            userEntity: userEntity,
            task: task,
            setting: setting,
            business: business,
            customEntity: customEntity,
            auditTag: auditTag
        )
    }
}

// MARK: - Diagnostics

public extension AuditLog {
    /// Fetch recent in-memory audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [AuditLogAuditEntry] {
        await AuditLogAuditManager.shared.recent(limit: limit)
    }

    /// Export in-memory audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AuditLogAuditManager.shared.exportJSON()
    }
}

// ... Keep enums AuditActionType, AuditEntityType as in your code, unchanged ...
