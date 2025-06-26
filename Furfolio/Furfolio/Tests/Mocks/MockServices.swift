//
//  MockServices.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade Mock Services for Previews, Testing, and QA
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Mock DataStoreService
class MockDataStoreService: DataStoreServiceProtocol {
    func fetchOwners() -> [DogOwner] {
        MockAuditLog.shared.record("fetchOwners", metadata: ["count": 1])
        return [MockData.mockOwner]
    }
    func fetchDogs() -> [Dog] {
        MockAuditLog.shared.record("fetchDogs", metadata: ["count": 1])
        return [MockData.mockDog]
    }
    func fetchAppointments() -> [Appointment] {
        MockAuditLog.shared.record("fetchAppointments", metadata: ["count": 1])
        return [MockData.mockAppointment]
    }
    func fetchCharges() -> [Charge] {
        MockAuditLog.shared.record("fetchCharges", metadata: ["count": 1])
        return [MockData.mockCharge]
    }
    // Add additional stubbed methods as needed
}

// MARK: - Mock NotificationService
class MockNotificationService: NotificationServiceProtocol {
    func scheduleNotification(for appointment: Appointment) {
        MockAuditLog.shared.record("scheduleNotification", metadata: ["appointmentId": appointment.id.uuidString])
    }
    func cancelNotification(for appointment: Appointment) {
        MockAuditLog.shared.record("cancelNotification", metadata: ["appointmentId": appointment.id.uuidString])
    }
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        MockAuditLog.shared.record("requestAuthorization", metadata: nil)
        completion(true)
    }
    // Add additional stubs as your app adds notification features
}

// MARK: - Mock AuditLogger
class MockAuditLogger: AuditLoggerProtocol {
    func log(_ action: String, metadata: [String : Any]?) {
        MockAuditLog.shared.record(action, metadata: metadata)
    }
    func fetchLogs() -> [AuditLog] {
        return MockAuditLog.shared.allLogs()
    }
}

// MARK: - Mock AnalyticsService
class MockAnalyticsService: AnalyticsServiceProtocol {
    func logEvent(_ name: String, parameters: [String: Any]?) {
        MockAuditLog.shared.record("analytics:\(name)", metadata: parameters)
    }
}

// MARK: - Mock ExportService
class MockExportService: ExportServiceProtocol {
    func exportData<T>(_ data: [T], format: ExportFormat, completion: @escaping (Result<URL, Error>) -> Void) {
        MockAuditLog.shared.record("exportData", metadata: ["type": "\(T.self)", "format": "\(format)"])
        // Return dummy URL
        completion(.success(URL(fileURLWithPath: "/tmp/fake-export.\(format.fileExtension)")))
    }
}

// MARK: - In-Memory Audit Log (QA, test, preview)
class MockAuditLog {
    static let shared = MockAuditLog()
    private(set) var logs: [AuditLog] = []

    func record(_ action: String, metadata: [String: Any]? = nil) {
        logs.append(AuditLog(timestamp: Date(), action: action, metadata: metadata))
        if logs.count > 64 { logs.removeFirst() }
    }

    func allLogs() -> [AuditLog] {
        return logs
    }
    func recentLogSummaries(limit: Int = 10) -> [String] {
        logs.suffix(limit).map { $0.summary }
    }
}

struct AuditLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let action: String
    let metadata: [String: Any]?
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        if let metadata = metadata, !metadata.isEmpty {
            return "[Mock] \(action): \(metadata) at \(df.string(from: timestamp))"
        } else {
            return "[Mock] \(action) at \(df.string(from: timestamp))"
        }
    }
}

// MARK: - Usage Example for Previews
#if DEBUG
struct ServiceProvider {
    static let preview = ServiceProvider(
        dataStore: MockDataStoreService(),
        notification: MockNotificationService(),
        auditLogger: MockAuditLogger(),
        analytics: MockAnalyticsService(),
        export: MockExportService()
    )
}
#endif

// MARK: - Protocols for compile/test safety (stubs—replace with your app’s)
protocol DataStoreServiceProtocol {
    func fetchOwners() -> [DogOwner]
    func fetchDogs() -> [Dog]
    func fetchAppointments() -> [Appointment]
    func fetchCharges() -> [Charge]
}
protocol NotificationServiceProtocol {
    func scheduleNotification(for appointment: Appointment)
    func cancelNotification(for appointment: Appointment)
    func requestAuthorization(completion: @escaping (Bool) -> Void)
}
protocol AuditLoggerProtocol {
    func log(_ action: String, metadata: [String: Any]?)
    func fetchLogs() -> [AuditLog]
}
protocol AnalyticsServiceProtocol {
    func logEvent(_ name: String, parameters: [String: Any]?)
}
protocol ExportServiceProtocol {
    func exportData<T>(_ data: [T], format: ExportFormat, completion: @escaping (Result<URL, Error>) -> Void)
}
enum ExportFormat: String {
    case csv, pdf, json
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .pdf: return "pdf"
        case .json: return "json"
        }
    }
}

// MARK: - Mock Models (replace with app models if needed)
struct DogOwner: Identifiable { let id = UUID(); var name = "Jane Doe" }
struct Dog: Identifiable { let id = UUID(); var name = "Buddy" }
struct Appointment: Identifiable { let id = UUID(); var notes = ""; var date = Date() }
struct Charge: Identifiable { let id = UUID(); var amount = 10.0 }

// MARK: - MockData (replace with real MockData or dependency)
struct MockData {
    static let mockOwner = DogOwner()
    static let mockDog = Dog()
    static let mockAppointment = Appointment()
    static let mockCharge = Charge()
}

// If you need additional mocks (for permissions, cloud sync, etc.), just ask!
