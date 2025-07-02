//
//  BackupManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Encapsulates all Furfolio data for backup and restore.
private struct FurfolioBackupData: Codable {
    let dogOwners: [DogOwner]
    let dogs: [Dog]
    let appointments: [Appointment]
    let charges: [Charge]
    let groomingSessions: [GroomingSession]
    let tasks: [Task]
    let behaviorLogs: [BehaviorLog]
    let incidentReports: [IncidentReport]
    let vaccinationRecords: [VaccinationRecord]
}

/// Errors that can occur during backup or restore.
public enum BackupError: Error {
    case fetchFailed
    case writeFailed
    case readFailed
    case decodeFailed
}

/// Manages exporting and restoring Furfolio data to/from JSON backups.
public class BackupManager {
    public static let shared = BackupManager()
    private init() {}

    /// Creates a JSON backup of all Furfolio data in the Documents directory.
    /// - Parameter fileName: Base name for the JSON file (without extension).
    /// - Returns: URL of the written backup file.
    /// - Throws: `BackupError` on failure.
    public func backup(to fileName: String = "FurfolioBackup", using context: ModelContext) async throws -> URL {
        // Fetch all data
        guard
            let dogOwners = try? await context.fetch(DogOwner.self),
            let dogs = try? await context.fetch(Dog.self),
            let appointments = try? await context.fetch(Appointment.self),
            let charges = try? await context.fetch(Charge.self),
            let groomingSessions = try? await context.fetch(GroomingSession.self),
            let tasks = try? await context.fetch(Task.self),
            let behaviorLogs = try? await context.fetch(BehaviorLog.self),
            let incidentReports = try? await context.fetch(IncidentReport.self),
            let vaccinationRecords = try? await context.fetch(VaccinationRecord.self)
        else {
            throw BackupError.fetchFailed
        }

        let backupData = FurfolioBackupData(
            dogOwners: dogOwners,
            dogs: dogs,
            appointments: appointments,
            charges: charges,
            groomingSessions: groomingSessions,
            tasks: tasks,
            behaviorLogs: behaviorLogs,
            incidentReports: incidentReports,
            vaccinationRecords: vaccinationRecords
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(backupData)
        } catch {
            throw BackupError.writeFailed
        }

        let docsURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let fileURL = docsURL.appendingPathComponent("\(fileName).json")

        do {
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            throw BackupError.writeFailed
        }

        return fileURL
    }

    /// Restores Furfolio data from a JSON backup file.
    /// - Parameter url: URL of the backup JSON file.
    /// - Throws: `BackupError` on failure.
    public func restore(from url: URL, using context: ModelContext) async throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.readFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData: FurfolioBackupData
        do {
            backupData = try decoder.decode(FurfolioBackupData.self, from: data)
        } catch {
            throw BackupError.decodeFailed
        }

        // Insert or update each entity
        for owner in backupData.dogOwners { context.insert(owner) }
        for dog in backupData.dogs { context.insert(dog) }
        for appointment in backupData.appointments { context.insert(appointment) }
        for charge in backupData.charges { context.insert(charge) }
        for session in backupData.groomingSessions { context.insert(session) }
        for task in backupData.tasks { context.insert(task) }
        for log in backupData.behaviorLogs { context.insert(log) }
        for incident in backupData.incidentReports { context.insert(incident) }
        for record in backupData.vaccinationRecords { context.insert(record) }
    }
}
