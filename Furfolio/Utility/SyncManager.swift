
//
//  SyncManager.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import SwiftData
import os

/// Central service responsible for syncing local data with a remote backend.
final class SyncManager {
    static let shared = SyncManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "SyncManager")
    private var isSyncing = false
    private let session = URLSession.shared
    private init() {}

    /// Starts a full sync of all entities.
    func syncAll(context: ModelContext) async {
        guard !isSyncing else {
            logger.log("Sync already in progress; skipping syncAll")
            return
        }
        isSyncing = true
        logger.log("Starting full data sync")
        defer {
            isSyncing = false
            logger.log("Completed full data sync")
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.syncOwners(context: context) }
            group.addTask { await self.syncAppointments(context: context) }
            group.addTask { await self.syncCharges(context: context) }
        }
    }

    /// Syncs DogOwner records to the backend.
    private func syncOwners(context: ModelContext) async {
        logger.log("Syncing DogOwner records")
        // Fetch local owners
        let owners: [DogOwner] = (try? context.fetch(FetchDescriptor<DogOwner>())) ?? []
        guard !owners.isEmpty else {
            logger.log("No DogOwner records to sync")
            return
        }
        // Encode and send to backend (stubbed)
        do {
            let data = try JSONEncoder().encode(owners)
            var request = URLRequest(url: URL(string: "https://api.furfolioapp.com/owners/sync")!)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await session.data(for: request)
            logger.log("Owners sync response: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
        } catch {
            logger.error("Failed to sync owners: \(error.localizedDescription)")
        }
    }

    /// Syncs Appointment records to the backend.
    private func syncAppointments(context: ModelContext) async {
        logger.log("Syncing Appointment records")
        let appts: [Appointment] = (try? context.fetch(FetchDescriptor<Appointment>())) ?? []
        guard !appts.isEmpty else {
            logger.log("No Appointment records to sync")
            return
        }
        do {
            let data = try JSONEncoder().encode(appts)
            var request = URLRequest(url: URL(string: "https://api.furfolioapp.com/appointments/sync")!)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await session.data(for: request)
            logger.log("Appointments sync response: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
        } catch {
            logger.error("Failed to sync appointments: \(error.localizedDescription)")
        }
    }

    /// Syncs Charge records to the backend.
    private func syncCharges(context: ModelContext) async {
        logger.log("Syncing Charge records")
        let charges: [Charge] = (try? context.fetch(FetchDescriptor<Charge>())) ?? []
        guard !charges.isEmpty else {
            logger.log("No Charge records to sync")
            return
        }
        do {
            let data = try JSONEncoder().encode(charges)
            var request = URLRequest(url: URL(string: "https://api.furfolioapp.com/charges/sync")!)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await session.data(for: request)
            logger.log("Charges sync response: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
        } catch {
            logger.error("Failed to sync charges: \(error.localizedDescription)")
        }
    }
}
