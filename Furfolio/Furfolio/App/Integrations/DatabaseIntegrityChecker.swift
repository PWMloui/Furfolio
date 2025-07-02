//
//  DatabaseIntegrityChecker.swift
//  Furfolio
//
//  Enhanced: role-aware, trust center/audit/analytics compliant, business-rule modular
//

import Foundation
import SwiftData
import OSLog

// MARK: - Logger Protocols

public protocol IntegrityAuditLogger {
    func log(issue: IntegrityIssue, source: String, role: FurfolioRole?)
}
public protocol IntegrityAnalyticsLogger {
    func track(issue: IntegrityIssue, extra: [String: Any]?)
}

// MARK: - Central Database Integrity Checker

final class DatabaseIntegrityChecker {
    static let shared = DatabaseIntegrityChecker()

    // MARK: - Dependencies (inject for modularity/testing/business roles)
    private let logger = Logger(subsystem: "com.furfolio.db.integrity", category: "integrity")
    private let auditLogger: IntegrityAuditLogger?
    private let analyticsLogger: IntegrityAnalyticsLogger?
    private let accessControl: AccessControl?
    private let trustCenter: TrustCenterPermissionManager?
    private let testMode: Bool
    private let customChecks: [(
        owners: [DogOwner], dogs: [Dog], appointments: [Appointment], charges: [Charge],
        staff: [StaffMember], users: [User], tasks: [Task], vaccinationRecords: [VaccinationRecord], context: IntegrityCheckContext
    ) async -> [IntegrityIssue]]

    // MARK: - Initialization

    init(
        auditLogger: IntegrityAuditLogger? = nil,
        analyticsLogger: IntegrityAnalyticsLogger? = nil,
        accessControl: AccessControl? = nil,
        trustCenter: TrustCenterPermissionManager? = nil,
        testMode: Bool = false,
        customChecks: [(
            owners: [DogOwner], dogs: [Dog], appointments: [Appointment], charges: [Charge],
            staff: [StaffMember], users: [User], tasks: [Task], vaccinationRecords: [VaccinationRecord], context: IntegrityCheckContext
        ) async -> [IntegrityIssue]] = []
    ) {
        self.auditLogger = auditLogger
        self.analyticsLogger = analyticsLogger
        self.accessControl = accessControl
        self.trustCenter = trustCenter
        self.testMode = testMode
        self.customChecks = customChecks
    }

    /// Default singleton for app-wide usage (no external logging by default)
    private init() {
        self.auditLogger = nil
        self.analyticsLogger = nil
        self.accessControl = nil
        self.trustCenter = nil
        self.testMode = false
        self.customChecks = []
    }

    // MARK: - Context (for role-aware, staff-aware checks)
    struct IntegrityCheckContext {
        var currentUser: User?
        var currentRole: FurfolioRole?
        var isAdmin: Bool { currentRole == .admin || currentRole == .owner }
        // Add trustCenter flags, featureFlags, etc as needed
    }

    // MARK: - Main Integrity Check API

    func runAllChecks(
        owners: [DogOwner],
        dogs: [Dog],
        appointments: [Appointment],
        charges: [Charge],
        staff: [StaffMember],
        users: [User],
        tasks: [Task],
        vaccinationRecords: [VaccinationRecord],
        context: IntegrityCheckContext = .init()
    ) async -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []
        issues += checkForOrphanedDogs(dogs, owners)
        issues += checkForOrphanedAppointments(appointments)
        issues += checkForOrphanedCharges(charges)
        issues += checkForDuplicateIDs(owners, dogs, appointments, charges, staff, users, tasks, vaccinationRecords)
        issues += checkForDogsWithoutAppointments(dogs)
        issues += checkForOwnersWithoutDogs(owners)
        issues += customBusinessRuleChecks(owners: owners, dogs: dogs, appointments: appointments, context: context)

        // Run injected custom checks (role-aware/context-aware)
        for customCheck in customChecks {
            let customIssues = await customCheck(
                owners, dogs, appointments, charges, staff, users, tasks, vaccinationRecords, context
            )
            issues += customIssues
        }

        await processAuditLogging(for: issues, context: context)
        return issues
    }

    // MARK: - Logging & Reporting

    private func processAuditLogging(for issues: [IntegrityIssue], context: IntegrityCheckContext) async {
        if !issues.isEmpty {
            logger.error("Integrity check: \(issues.count) issue(s).")
            for issue in issues {
                logger.warning("\(issue.type.rawValue): \(issue.message)")
                if !testMode {
                    auditLogger?.log(issue: issue, source: "DatabaseIntegrityChecker", role: context.currentRole)
                    analyticsLogger?.track(issue: issue, extra: [
                        "role": context.currentRole?.rawValue ?? "unknown",
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    // Optionally: escalate certain issue types to Trust Center or AccessControl.
                    if issue.requiresEscalation, let trustCenter {
                        trustCenter.escalateIntegrityIssue(issue, role: context.currentRole)
                    }
                }
            }
        } else {
            logger.info("Database passed all integrity checks.")
        }
    }

    // MARK: - Filtering/Diagnostics Utilities

    func issues(ofType type: IntegrityIssue.IssueType, from issues: [IntegrityIssue]) -> [IntegrityIssue] {
        issues.filter { $0.type == type }
    }
    func issues(forEntityID entityID: String, from issues: [IntegrityIssue]) -> [IntegrityIssue] {
        issues.filter { $0.entityID == entityID }
    }
    func issues(forRole role: FurfolioRole, from issues: [IntegrityIssue]) -> [IntegrityIssue] {
        issues.filter { $0.affectedRole == role }
    }

    // MARK: - Built-in Checks (with business-aware context)

    private func checkForOrphanedDogs(_ dogs: [Dog], _ owners: [DogOwner]) -> [IntegrityIssue] {
        dogs.filter { $0.owner == nil }.map {
            IntegrityIssue(
                type: .orphanedDog,
                message: String(
                    format: NSLocalizedString("Dog %@ (%@) is not linked to any owner.",
                                              comment: "Integrity issue message for dog without owner"),
                    $0.name, $0.id.uuidString
                ),
                entityID: $0.id.uuidString,
                entityType: "Dog",
                affectedRole: .unknown
            )
        }
    }
    private func checkForOrphanedAppointments(_ appointments: [Appointment]) -> [IntegrityIssue] {
        appointments.flatMap { appt in
            var issues: [IntegrityIssue] = []
            if appt.owner == nil {
                issues.append(IntegrityIssue(
                    type: .orphanedAppointment,
                    message: String(
                        format: NSLocalizedString("Appointment (%@) has no owner linked.", comment: "Integrity issue for appointment with no owner"),
                        appt.id.uuidString
                    ),
                    entityID: appt.id.uuidString,
                    entityType: "Appointment",
                    affectedRole: .unknown
                ))
            }
            if appt.dog == nil {
                issues.append(IntegrityIssue(
                    type: .orphanedAppointment,
                    message: String(
                        format: NSLocalizedString("Appointment (%@) has no dog linked.", comment: "Integrity issue for appointment with no dog"),
                        appt.id.uuidString
                    ),
                    entityID: appt.id.uuidString,
                    entityType: "Appointment",
                    affectedRole: .unknown
                ))
            }
            return issues
        }
    }
    private func checkForOrphanedCharges(_ charges: [Charge]) -> [IntegrityIssue] {
        charges.flatMap { charge in
            var issues: [IntegrityIssue] = []
            if charge.owner == nil {
                issues.append(IntegrityIssue(
                    type: .orphanedCharge,
                    message: String(
                        format: NSLocalizedString("Charge (%@) is not linked to any owner.", comment: "Integrity issue for charge with no owner"),
                        charge.id.uuidString
                    ),
                    entityID: charge.id.uuidString,
                    entityType: "Charge",
                    affectedRole: .unknown
                ))
            }
            if charge.dog == nil {
                issues.append(IntegrityIssue(
                    type: .orphanedCharge,
                    message: String(
                        format: NSLocalizedString("Charge (%@) is not linked to any dog.", comment: "Integrity issue for charge with no dog"),
                        charge.id.uuidString
                    ),
                    entityID: charge.id.uuidString,
                    entityType: "Charge",
                    affectedRole: .unknown
                ))
            }
            if charge.appointment == nil {
                issues.append(IntegrityIssue(
                    type: .orphanedCharge,
                    message: String(
                        format: NSLocalizedString("Charge (%@) is not linked to any appointment.", comment: "Integrity issue for charge with no appointment"),
                        charge.id.uuidString
                    ),
                    entityID: charge.id.uuidString,
                    entityType: "Charge",
                    affectedRole: .unknown
                ))
            }
            return issues
        }
    }
    private func checkForDuplicateIDs(
        _ owners: [DogOwner],
        _ dogs: [Dog],
        _ appointments: [Appointment],
        _ charges: [Charge],
        _ staff: [StaffMember],
        _ users: [User],
        _ tasks: [Task],
        _ vaccinationRecords: [VaccinationRecord]
    ) -> [IntegrityIssue] {
        var allIDs: [UUID: Set<String>] = [:]
        let collect: (UUID, String) -> Void = { id, type in
            allIDs[id, default: []].insert(type)
        }
        owners.forEach { collect($0.id, "DogOwner") }
        dogs.forEach { collect($0.id, "Dog") }
        appointments.forEach { collect($0.id, "Appointment") }
        charges.forEach { collect($0.id, "Charge") }
        staff.forEach { collect($0.id, "StaffMember") }
        users.forEach { collect($0.id, "User") }
        tasks.forEach { collect($0.id, "Task") }
        vaccinationRecords.forEach { collect($0.id, "VaccinationRecord") }
        return allIDs.filter { $0.value.count > 1 }.map { (id, types) in
            IntegrityIssue(
                type: .duplicateID,
                message: String(
                    format: NSLocalizedString("Duplicate ID (%@) found in: %@.", comment: "Integrity issue for duplicate UUID across entity types"),
                    id.uuidString, types.sorted().joined(separator: ", ")
                ),
                entityID: id.uuidString,
                entityType: "Multiple",
                affectedRole: .unknown
            )
        }
    }
    private func checkForDogsWithoutAppointments(_ dogs: [Dog]) -> [IntegrityIssue] {
        dogs.filter { $0.appointments.isEmpty }.map {
            IntegrityIssue(
                type: .dogNoAppointments,
                message: String(
                    format: NSLocalizedString("Dog %@ (%@) has no appointments.", comment: "Integrity issue for dog with no appointments"),
                    $0.name, $0.id.uuidString
                ),
                entityID: $0.id.uuidString,
                entityType: "Dog",
                affectedRole: .unknown
            )
        }
    }
    private func checkForOwnersWithoutDogs(_ owners: [DogOwner]) -> [IntegrityIssue] {
        owners.filter { $0.dogs.isEmpty }.map {
            IntegrityIssue(
                type: .ownerNoDogs,
                message: String(
                    format: NSLocalizedString("Owner %@ (%@) has no dogs.", comment: "Integrity issue for owner with no dogs"),
                    $0.ownerName, $0.id.uuidString
                ),
                entityID: $0.id.uuidString,
                entityType: "DogOwner",
                affectedRole: .unknown
            )
        }
    }
    // Extendable: Custom business checks using staff/role/context if needed
    private func customBusinessRuleChecks(
        owners: [DogOwner],
        dogs: [Dog],
        appointments: [Appointment],
        context: IntegrityCheckContext
    ) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []

        // Example: Escalate VIP owners with no VIP dogs only to admins/owner roles
        if context.isAdmin {
            for owner in owners where owner.tags.contains("VIP") {
                let hasVipDog = owner.dogs.contains { $0.tags.contains("VIP") }
                if !hasVipDog {
                    issues.append(
                        IntegrityIssue(
                            type: .businessRuleViolation,
                            message: String(
                                format: NSLocalizedString("VIP Owner %@ (%@) has no VIP dogs.", comment: "Custom rule: VIP owner no VIP dogs"),
                                owner.ownerName, owner.id.uuidString
                            ),
                            entityID: owner.id.uuidString,
                            entityType: "DogOwner",
                            affectedRole: context.currentRole ?? .owner
                        )
                    )
                }
            }
        }
        // Extend as needed for more staff/role-specific rules...
        return issues
    }
}

// MARK: - Issue Model

struct IntegrityIssue: Identifiable, Hashable {
    enum IssueType: String, CaseIterable, Codable {
        case orphanedDog
        case orphanedAppointment
        case orphanedCharge
        case duplicateID
        case dogNoAppointments
        case ownerNoDogs
        case businessRuleViolation
        // Extend for: incidentEscalation, healthAlertMismatch, loyaltyInconsistency, staffIncident, etc.
    }

    let id = UUID()
    let type: IssueType
    let message: String
    let entityID: String
    let entityType: String
    /// Which staff role/user this issue should be flagged to (for escalations, incident routing, etc)
    let affectedRole: FurfolioRole

    /// Use this for certain issues to auto-escalate to Trust Center or audit compliance
    var requiresEscalation: Bool {
        switch type {
            case .duplicateID, .businessRuleViolation: return true
            default: return false
        }
    }
}

// MARK: - Trust Center (Stub for Compliance/Escalation)

public class TrustCenterPermissionManager {
    public init() {}
    public func escalateIntegrityIssue(_ issue: IntegrityIssue, role: FurfolioRole?) {
        // Route critical compliance issues to trust/audit center or alert admins/owner.
        // Example: Send to incident report dashboard, compliance log, or business owner notification.
    }
}
