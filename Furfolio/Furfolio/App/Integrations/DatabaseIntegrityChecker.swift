//
//  DatabaseIntegrityChecker.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, unified, diagnostics/audit-ready.
//

import Foundation
import SwiftData
import OSLog

/// Responsible for performing comprehensive integrity checks on the database entities.
/// Designed for extensibility to add new checks and supports detailed logging for diagnostics and audit purposes.
final class DatabaseIntegrityChecker {
    static let shared = DatabaseIntegrityChecker()
    private let logger = Logger(subsystem: "com.furfolio.db.integrity", category: "integrity")
    // TODO: Migrate logger usage to a centralized AppLogger or diagnostics engine if/when one is introduced.

    private init() {}

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
        if !issues.isEmpty {
            logger.error("Integrity check: \(issues.count) issue(s).")
            for issue in issues {
                logger.warning("\(issue.type.rawValue): \(issue.message)")
            }
            // TODO: Call Trust Center / audit / analytics logging here for integrity issues detected.
        } else {
            logger.info("Database passed all integrity checks.")
        }
        return issues
    }

    private func checkForOrphanedDogs(_ dogs: [Dog], _ owners: [DogOwner]) -> [IntegrityIssue] {
        dogs.filter { $0.owner == nil }.map {
            IntegrityIssue(
                type: .orphanedDog,
                message: NSLocalizedString(
                    "Dog \($0.name) (\($0.id)) is not linked to any owner.",
                    comment: "Integrity issue message indicating a dog without an owner"
                ),
                entityID: $0.id.uuidString
            )
        }
    }

    private func checkForOrphanedAppointments(_ appointments: [Appointment]) -> [IntegrityIssue] {
        appointments.compactMap { appt in
            if appt.owner == nil {
                return IntegrityIssue(
                    type: .orphanedAppointment,
                    message: NSLocalizedString(
                        "Appointment (\(appt.id)) has no owner linked.",
                        comment: "Integrity issue message indicating an appointment without an owner"
                    ),
                    entityID: appt.id.uuidString
                )
            }
            if appt.dog == nil {
                return IntegrityIssue(
                    type: .orphanedAppointment,
                    message: NSLocalizedString(
                        "Appointment (\(appt.id)) has no dog linked.",
                        comment: "Integrity issue message indicating an appointment without a dog"
                    ),
                    entityID: appt.id.uuidString
                )
            }
            return nil
        }
    }

    private func checkForOrphanedCharges(_ charges: [Charge]) -> [IntegrityIssue] {
        charges.compactMap { charge in
            if charge.owner == nil {
                return IntegrityIssue(
                    type: .orphanedCharge,
                    message: NSLocalizedString(
                        "Charge (\(charge.id)) is not linked to any owner.",
                        comment: "Integrity issue message indicating a charge without an owner"
                    ),
                    entityID: charge.id.uuidString
                )
            }
            if charge.dog == nil {
                return IntegrityIssue(
                    type: .orphanedCharge,
                    message: NSLocalizedString(
                        "Charge (\(charge.id)) is not linked to any dog.",
                        comment: "Integrity issue message indicating a charge without a dog"
                    ),
                    entityID: charge.id.uuidString
                )
            }
            if charge.appointment == nil {
                return IntegrityIssue(
                    type: .orphanedCharge,
                    message: NSLocalizedString(
                        "Charge (\(charge.id)) is not linked to any appointment.",
                        comment: "Integrity issue message indicating a charge without an appointment"
                    ),
                    entityID: charge.id.uuidString
                )
            }
            return nil
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
                message: NSLocalizedString(
                    "Duplicate ID (\(id)) found in: \(types.sorted().joined(separator: \", \")).",
                    comment: "Integrity issue message indicating a duplicate UUID found across multiple entity types"
                ),
                entityID: id.uuidString
            )
        }
    }

    private func checkForDogsWithoutAppointments(_ dogs: [Dog]) -> [IntegrityIssue] {
        dogs.filter { $0.appointments.isEmpty }.map {
            IntegrityIssue(
                type: .dogNoAppointments,
                message: NSLocalizedString(
                    "Dog \($0.name) (\($0.id)) has no appointments.",
                    comment: "Integrity issue message indicating a dog with no appointments"
                ),
                entityID: $0.id.uuidString
            )
        }
    }

    private func checkForOwnersWithoutDogs(_ owners: [DogOwner]) -> [IntegrityIssue] {
        owners.filter { $0.dogs.isEmpty }.map {
            IntegrityIssue(
                type: .ownerNoDogs,
                message: NSLocalizedString(
                    "Owner \($0.ownerName) (\($0.id)) has no dogs.",
                    comment: "Integrity issue message indicating an owner with no dogs"
                ),
                entityID: $0.id.uuidString
            )
        }
    }

    private func customBusinessRuleChecks(
        owners: [DogOwner],
        dogs: [Dog],
        appointments: [Appointment]
    ) -> [IntegrityIssue] {
        // Add more business rules as needed.
        return []
    }
}

/// Represents an integrity issue found during database checks.
/// Includes the type of issue, a localized descriptive message, and the related entity's ID.
/// Designed to be easily extendable for new issue types and to support consistent logging and diagnostics.
struct IntegrityIssue: Identifiable, Hashable {
    enum IssueType: String, CaseIterable, Codable {
        case orphanedDog
        case orphanedAppointment
        case orphanedCharge
        case duplicateID
        case dogNoAppointments
        case ownerNoDogs
        // Expand as needed.
    }

    let id = UUID()
    let type: IssueType
    let message: String
    let entityID: String
}
