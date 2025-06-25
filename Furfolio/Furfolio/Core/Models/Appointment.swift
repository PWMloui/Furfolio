//
//  Appointment.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Audit/Analytics Protocol

public protocol AppointmentAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullAppointmentAnalyticsLogger: AppointmentAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol AppointmentTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullAppointmentTrustCenterDelegate: AppointmentTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - Appointment (Unified, Modular, Tokenized, Auditable Appointment Model)

@Model
final class Appointment: Identifiable, ObservableObject {
    // MARK: - Core Properties
    @Attribute(.unique)
    var id: UUID = UUID()
    var date: Date
    var durationMinutes: Int
    var serviceType: ServiceType
    var notes: String?
    var status: AppointmentStatus
    var tags: [String]

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.appointments)
    var owner: DogOwner?
    @Relationship(deleteRule: .nullify, inverse: \Dog.appointments)
    var dog: Dog?

    // MARK: - Behavior & Logs
    @Relationship(deleteRule: .cascade)
    var behaviorLog: BehaviorLog?

    // MARK: - Audit & Metadata
    var lastEdited: Date
    var createdBy: String?
    var lastModifiedBy: String?
    var createdAt: Date
    var auditLog: [AuditEntry]

    // MARK: - Analytics/Trust Center Loggers (Injectable)
    static var analyticsLogger: AppointmentAnalyticsLogger = NullAppointmentAnalyticsLogger()
    static var trustCenterDelegate: AppointmentTrustCenterDelegate = NullAppointmentTrustCenterDelegate()

    // MARK: - Computed Properties
    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: date) ?? date
    }
    var isPast: Bool { endDate < Date() }
    var isUpcoming: Bool { date > Date() }
    var isActive: Bool { status.isActive }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        date: Date,
        durationMinutes: Int = 60,
        serviceType: ServiceType,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        notes: String? = nil,
        status: AppointmentStatus = .scheduled,
        tags: [String] = [],
        behaviorLog: BehaviorLog? = nil,
        lastEdited: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil,
        createdAt: Date = Date(),
        auditLog: [AuditEntry] = []
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.serviceType = serviceType
        self.owner = owner
        self.dog = dog
        self.notes = notes
        self.status = status
        self.tags = tags
        self.behaviorLog = behaviorLog
        self.lastEdited = lastEdited
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.auditLog = auditLog
    }

    // MARK: - Methods

    /// Adds a new audit entry and updates metadata, with analytics/audit protocol log and Trust Center permission check.
    func addAudit(action: AuditAction, user: String?, context: [String: Any]? = nil, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "addAudit", context: [
            "action": action.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "addAudit_denied", info: [
                "action": action.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        let entry = AuditEntry(
            date: Date(),
            action: action,
            user: user
        )
        auditLog.append(entry)
        lastEdited = entry.date
        lastModifiedBy = user
        Self.analyticsLogger.log(event: "addAudit", info: [
            "action": action.rawValue,
            "user": user as Any,
            "timestamp": entry.date,
            "auditTag": auditTag as Any
        ])
    }

    /// Updates the appointment status with full audit/analytics protocol logging and Trust Center hook.
    func updateStatus(_ newStatus: AppointmentStatus, user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateStatus", context: [
            "from": status.rawValue,
            "to": newStatus.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateStatus_denied", info: [
                "from": status.rawValue,
                "to": newStatus.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        let oldStatus = status
        status = newStatus
        addAudit(action: .statusChanged, user: user, context: [
            "from": oldStatus.rawValue,
            "to": newStatus.rawValue
        ], auditTag: auditTag)
        Self.analyticsLogger.log(event: "updateStatus", info: [
            "from": oldStatus.rawValue,
            "to": newStatus.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Adds a note to the appointment, with audit logging.
    func addNote(_ note: String, user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "addNote", context: [
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "addNote_denied", info: [
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        notes = (notes?.isEmpty ?? true) ? note : "\(notes ?? "")\n\(note)"
        addAudit(action: .noteAdded, user: user, auditTag: auditTag)
        Self.analyticsLogger.log(event: "addNote", info: [
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Route optimization location coordinate (read-only)
    var locationCoordinate: Coordinate? {
        owner?.address?.coordinate
    }
}

// MARK: - Enums & Supporting Types

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case fullGroom, basicBath, nailTrim, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .custom: return "Custom"
        }
    }
    var durationEstimate: Int {
        switch self {
        case .fullGroom: return 90
        case .basicBath: return 45
        case .nailTrim: return 20
        case .custom: return 60
        }
    }
}

enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled, completed, cancelled, noShow, inProgress
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .inProgress: return "In Progress"
        }
    }
    var isActive: Bool {
        self == .scheduled || self == .inProgress
    }
}

// MARK: - Audit Trail Types

struct AuditEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var action: AuditAction
    var user: String?
}

enum AuditAction: String, Codable, CaseIterable, Identifiable {
    case created, modified, deleted, statusChanged, noteAdded
    var id: String { rawValue }
    var description: String {
        switch self {
        case .created: return "Created appointment"
        case .modified: return "Edited appointment"
        case .deleted: return "Deleted appointment"
        case .statusChanged: return "Changed status"
        case .noteAdded: return "Added note"
        }
    }
}

// MARK: - Coordinate

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}
