//
//  DatabaseIntegrityChecker.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated, enhanced, and unified for Furfolio 2.0 architecture.
//

import Foundation
import SwiftData
import OSLog

/// Utility for verifying the integrity of the Furfolio database.
/// Checks for orphaned records, broken relationships, duplicate IDs, etc.
/// Modular, extensible, and ready for diagnostics dashboard integration.
final class DatabaseIntegrityChecker {
    static let shared = DatabaseIntegrityChecker()
    private let logger = Logger(subsystem: "com.furfolio.db.integrity", category: "integrity")

    private init() {}

    /// Runs all integrity checks and returns any found issues.
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

        if !issues.isEmpty {
            logger.error("🧩 Integrity check completed with \(issues.count) issue(s).")
            for issue in issues {
                logger.warning("⚠️ \(issue.type.rawValue): \(issue.message)")
            }
        } else {
            logger.info("✅ Database passed all integrity checks.")
        }

        return issues
    }

    // MARK: - Integrity Checks

    private func checkForOrphanedDogs(_ dogs: [Dog], _ owners: [DogOwner]) -> [IntegrityIssue] {
        dogs.filter { $0.owner == nil }.map {
            IntegrityIssue(
                type: .orphanedDog,
                message: "Dog \($0.name) (\($0.id)) is not linked to any owner.",
                entityID: $0.id.uuidString
            )
        }
    }

    private func checkForOrphanedAppointments(_ appointments: [Appointment]) -> [IntegrityIssue] {
        appointments.compactMap { appt in
            if appt.owner == nil {
                return IntegrityIssue(
                    type: .orphanedAppointment,
                    message: "Appointment (\(appt.id)) has no owner linked.",
                    entityID: appt.id.uuidString
                )
            }
            if appt.dog == nil {
                return IntegrityIssue(
                    type: .orphanedAppointment,
                    message: "Appointment (\(appt.id)) has no dog linked.",
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
                    message: "Charge (\(charge.id)) is not linked to any owner.",
                    entityID: charge.id.uuidString
                )
            }
            if charge.dog == nil {
                return IntegrityIssue(
                    type: .orphanedCharge,
                    message: "Charge (\(charge.id)) is not linked to any dog.",
                    entityID: charge.id.uuidString
                )
            }
            if charge.appointment == nil {
                return IntegrityIssue(
                    type: .orphanedCharge,
                    message: "Charge (\(charge.id)) is not linked to any appointment.",
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
                message: "Duplicate ID (\(id)) found in: \(types.sorted().joined(separator: \", \")).",
                entityID: id.uuidString
            )
        }
    }

    private func checkForDogsWithoutAppointments(_ dogs: [Dog]) -> [IntegrityIssue] {
        dogs.filter { $0.appointments.isEmpty }.map {
            IntegrityIssue(
                type: .dogNoAppointments,
                message: "Dog \($0.name) (\($0.id)) has no appointments.",
                entityID: $0.id.uuidString
            )
        }
    }

    private func checkForOwnersWithoutDogs(_ owners: [DogOwner]) -> [IntegrityIssue] {
        owners.filter { $0.dogs.isEmpty }.map {
            IntegrityIssue(
                type: .ownerNoDogs,
                message: "Owner \($0.ownerName) (\($0.id)) has no dogs.",
                entityID: $0.id.uuidString
            )
        }
    }

    // Future extensibility
    func futureIntegrityChecks() {
        // Add new checks as Furfolio grows.
    }
}

/// Describes a database integrity problem, ready for SwiftUI diagnostics dashboard or audit trail.
struct IntegrityIssue: Identifiable, Hashable {
    enum IssueType: String, CaseIterable, Codable {
        case orphanedDog
        case orphanedAppointment
        case orphanedCharge
        case duplicateID
        case dogNoAppointments
        case ownerNoDogs
        // Expand as needed (e.g., orphanedStaff, businessMismatch, etc)
    }

    let id = UUID()
    let type: IssueType
    let message: String
    let entityID: String
}
