
//
//  SyncManager.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import CloudKit

final class SyncManager {
    static let shared = SyncManager()

    private let container: CKContainer
    private let privateDB: CKDatabase

    private init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.privateDB = container.privateCloudDatabase
    }

    /// Pushes local changes to CloudKit.
    func pushLocalChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Enumerate local changes (e.g., newly created or modified records)
        // For each record, create a CKRecord and save it
        let recordsToSave: [CKRecord] = [] // populate with your converted models
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    /// Pulls remote changes from CloudKit.
    func pullRemoteChanges(completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
        var recordZoneIDs: [CKRecordZone.ID] = []
        operation.databaseChangeToken = nil
        operation.recordZoneWithIDChangedBlock = { zoneID in
            recordZoneIDs.append(zoneID)
        }
        operation.fetchDatabaseChangesResultBlock = { result in
            switch result {
            case .success:
                self.fetchZoneRecords(zoneIDs: recordZoneIDs, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    private func fetchZoneRecords(zoneIDs: [CKRecordZone.ID], completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: nil)
        operation.recordChangedBlock = { record in
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
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        privateDB.add(operation)
    }

    /// Performs a full sync: push then pull.
    func syncAll(completion: @escaping (Result<Void, Error>) -> Void) {
        pushLocalChanges { pushResult in
            switch pushResult {
            case .success:
                self.pullRemoteChanges(completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

