//
//  SyncManager.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import os
import CloudKit

final class SyncManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "SyncManager")
    static let shared = SyncManager()

    private let container: CKContainer
    private let privateDB: CKDatabase

    private init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.privateDB = container.privateCloudDatabase
    }

    /// Pushes local changes to CloudKit.
    func pushLocalChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        let recordsToSave: [CKRecord] = [] // populate with your converted models
        logger.log("pushLocalChanges started: preparing to save \(recordsToSave.count) records")
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                logger.log("pushLocalChanges succeeded")
                completion(.success(()))
            case .failure(let error):
                logger.error("pushLocalChanges failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    /// Pulls remote changes from CloudKit.
    func pullRemoteChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        logger.log("pullRemoteChanges started")
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
        var recordZoneIDs: [CKRecordZone.ID] = []
        operation.databaseChangeToken = nil
        operation.recordZoneWithIDChangedBlock = { zoneID in
            logger.log("Detected changed zone: \(zoneID.zoneName)")
            recordZoneIDs.append(zoneID)
        }
        operation.fetchDatabaseChangesResultBlock = { result in
            switch result {
            case .success:
                logger.log("pullRemoteChanges detected \(recordZoneIDs.count) zones; fetching zone records")
                self.fetchZoneRecords(zoneIDs: recordZoneIDs, completion: completion)
            case .failure(let error):
                logger.error("pullRemoteChanges failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    private func fetchZoneRecords(zoneIDs: [CKRecordZone.ID], completion: @escaping (Result<Void, Error>) -> Void) {
        logger.log("fetchZoneRecords started for zones: \(zoneIDs.map(\.zoneName))")
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: nil)
        operation.recordChangedBlock = { record in
            logger.log("Record changed: \(record.recordID.recordName)")
            // TODO: Map CKRecord fields back to your local models and save
        }
        operation.recordZoneFetchResultBlock = { zoneID, result in
            if case .failure(let error) = result {
                completion(.failure(error))
            }
        }
        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                logger.log("fetchZoneRecords succeeded")
                completion(.success(()))
            case .failure(let error):
                logger.error("fetchZoneRecords failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    /// Performs a full sync: push then pull.
    func syncAll(completion: @escaping (Result<Void, Error>) -> Void) {
        logger.log("syncAll started: pushing then pulling")
        pushLocalChanges { pushResult in
            switch pushResult {
            case .success:
                logger.log("syncAll pushLocalChanges succeeded; proceeding to pullRemoteChanges")
                self.pullRemoteChanges(completion: completion)
            case .failure(let error):
                logger.error("syncAll pushLocalChanges error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
