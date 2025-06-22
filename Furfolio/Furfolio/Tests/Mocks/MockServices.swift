
//
//  MockServices.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Mock DataStoreService
class MockDataStoreService: DataStoreServiceProtocol {
    func fetchOwners() -> [DogOwner] {
        return [MockData.mockOwner]
    }
    func fetchDogs() -> [Dog] {
        return [MockData.mockDog]
    }
    func fetchAppointments() -> [Appointment] {
        return [MockData.mockAppointment]
    }
    func fetchCharges() -> [Charge] {
        return [MockData.mockCharge]
    }
    // Add additional stubbed methods as needed
}

// MARK: - Mock NotificationService
class MockNotificationService: NotificationServiceProtocol {
    func scheduleNotification(for appointment: Appointment) { }
    func cancelNotification(for appointment: Appointment) { }
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    // Add additional stubs if your app uses more methods
}

// MARK: - Mock AuditLogger
class MockAuditLogger: AuditLoggerProtocol {
    func log(_ action: String, metadata: [String : Any]?) { }
    func fetchLogs() -> [AuditLog] { return [] }
}

// MARK: - Usage Example for Previews
#if DEBUG
struct ServiceProvider {
    static let preview = ServiceProvider(
        dataStore: MockDataStoreService(),
        notification: MockNotificationService(),
        auditLogger: MockAuditLogger()
    )
}
#endif

// If you need additional mocks (for analytics, export, etc.), let me know!

