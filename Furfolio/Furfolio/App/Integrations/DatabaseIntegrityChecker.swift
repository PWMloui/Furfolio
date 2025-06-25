//
//  DatabaseIntegrityChecker.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, auditable, diagnostics/analytics-ready, and future-proof.
//

import Foundation
import SwiftData
import OSLog

/// Centralized class for performing comprehensive database integrity checks.
/// All checks are auditable, extensible, and support business diagnostics and Trust Center compliance.
final class DatabaseIntegrityChecker {
    static let shared = DatabaseIntegrityChecker()
    private let logger = Logger(subsystem: "com.furfolio.db.integrity", category: "integrity")

    // Dependency injection for audit/analytics engines.
    private let auditLogger: ((IntegrityIssue) -> Void)?
    private let analyticsLogger: ((IntegrityIssue) -> Void)?

    /// For production, audit/analytics hooks can be provided here.
    init(auditLogger: ((IntegrityIssue) -> Void)? = nil,
         analyticsLogger: ((IntegrityIssue) -> Void)? = nil) {
        self.auditLogger = auditLogger
        self.analyticsLogger = analyticsLogger
    }

    /// Default singleton for app-wide usage.
    private init() {
        self.auditLogger = nil
        self.analyticsLogger = nil
    }

    /// Runs all integrity checks and returns found issues. All issues are logged/audited.
    func runAllChecks(
        owners: [DogOwner],
        dogs: [Dog],
        appointments: [Appointment],
        charges: [Charge],
        staff: [StaffMember],
        users: [User],
        tasks: [Task],
        vaccinationRecords: [VaccinationRecord]
    ) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []
        issues += checkForOrphanedDogs(dogs, owners)
        issues += checkForOrphanedAppointments(appointments)
        issues += checkForOrphanedCharges(charges)
        issues += checkForDuplicateIDs(
            owners, dogs, appointments, charges, staff, users, tasks, vaccinationRecords
        )
        issues += checkForDogsWithoutAppointments(dogs)
        issues += checkForOwnersWithoutDogs(owners)
        issues += customBusinessRuleChecks(owners: owners, dogs: dogs, appointments: appointments)
        processAuditLogging(for: issues)
        return issues
    }

    /// Logs/audits all integrity issues and prints diagnostics.
    private func processAuditLogging(for issues: [IntegrityIssue]) {
        if !issues.isEmpty {
            logger.error("Integrity check: \(issues.count) issue(s).")
            for issue in issues {
                logger.warning("\(issue.type.rawValue): \(issue.message)")
                auditLogger?(issue)
                analyticsLogger?(issue)
                // TODO: Replace with Trust Center/business audit/analytics integration.
            }
        } else {
            logger.info("Database passed all integrity checks.")
        }
    }

    /// Finds dogs without an associated owner.
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
                entityType: "Dog"
            )
        }
    }

    /// Finds appointments missing either a dog or an owner.
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
                    entityType: "Appointment"
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
                    entityType: "Appointment"
                ))
            }
            return issues
        }
    }

    /// Finds charges missing a dog, owner, or appointment.
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
                    entityType: "Charge"
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
                    entityType: "Charge"
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
                    entityType: "Charge"
                ))
            }
            return issues
        }
    }

    /// Detects duplicate UUIDs across all entities (by type).
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
                entityType: "Multiple"
            )
        }
    }

    /// Flags any dogs without appointments.
    private func checkForDogsWithoutAppointments(_ dogs: [Dog]) -> [IntegrityIssue] {
        dogs.filter { $0.appointments.isEmpty }.map {
            IntegrityIssue(
                type: .dogNoAppointments,
                message: String(
                    format: NSLocalizedString("Dog %@ (%@) has no appointments.", comment: "Integrity issue for dog with no appointments"),
                    $0.name, $0.id.uuidString
                ),
                entityID: $0.id.uuidString,
                entityType: "Dog"
            )
        }
    }

    /// Flags owners without any dogs.
    private func checkForOwnersWithoutDogs(_ owners: [DogOwner]) -> [IntegrityIssue] {
        owners.filter { $0.dogs.isEmpty }.map {
            IntegrityIssue(
                type: .ownerNoDogs,
                message: String(
                    format: NSLocalizedString("Owner %@ (%@) has no dogs.", comment: "Integrity issue for owner with no dogs"),
                    $0.ownerName, $0.id.uuidString
                ),
                entityID: $0.id.uuidString,
                entityType: "DogOwner"
            )
        }
    }

    /// Place to add custom business rules (e.g., VIPs with missing badges, health alert mismatches, etc).
    private func customBusinessRuleChecks(
        owners: [DogOwner],
        dogs: [Dog],
        appointments: [Appointment]
    ) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []

        // Example: Check for owners marked "VIP" with no dogs tagged as "VIP"
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
                        entityType: "DogOwner"
                    )
                )
            }
        }

        // Extend as needed...
        return issues
    }
}

/// Represents a single integrity issue found during database checks.
/// Type, message, entityID, and entityType allow for auditing, deep linking, and diagnostics.
struct IntegrityIssue: Identifiable, Hashable {
    enum IssueType: String, CaseIterable, Codable {
        case orphanedDog
        case orphanedAppointment
        case orphanedCharge
        case duplicateID
        case dogNoAppointments
        case ownerNoDogs
        case businessRuleViolation
        // Expand as needed.
    }

    let id = UUID()
    let type: IssueType
    let message: String
    let entityID: String
    let entityType: String
}
