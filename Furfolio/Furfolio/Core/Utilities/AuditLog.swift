//
//  AuditLog.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol AuditLogAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullAuditLogAnalyticsLogger: AuditLogAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol AuditLogTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullAuditLogTrustCenterDelegate: AuditLogTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
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
        Self.analyticsLogger.log(event: "created", info: [
            "actionType": actionType.rawValue,
            "entityType": entityType.rawValue,
            "entityID": entityID,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - Mutation/Audit Methods

    func updateDetails(_ newDetails: String, by user: String, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateDetails", context: [
            "id": id.uuidString,
            "user": user,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateDetails_denied", info: [
                "id": id.uuidString,
                "user": user,
                "auditTag": auditTag as Any
            ])
            return
        }
        self.details = newDetails
        Self.analyticsLogger.log(event: "updateDetails", info: [
            "id": id.uuidString,
            "user": user,
            "auditTag": auditTag as Any
        ])
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

// ... Keep enums AuditActionType, AuditEntityType as in your code, unchanged ...
