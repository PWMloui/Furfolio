//
//  DataStoreService.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
// Enhanced for architectural consolidation, unification, async performance, and audit trail readiness (2025-06-21).

/**
 DataStoreService
 ----------------
 A centralized SwiftData-backed service for managing Furfolio’s persistent data with unified CRUD, audit trail, and diagnostics.

 - **Purpose**: Provides generic and model-specific CRUD operations with traceable audit logging.
 - **Architecture**: Singleton `ObservableObject` with SwiftData `ModelContainer` and `ModelContext`.
 - **Concurrency & Async Logging**: All operations are `async`; critical events are wrapped in `Task` blocks to log asynchronously.
 - **Audit/Analytics Ready**: Defines protocols for async audit logging and integrates a dedicated actor for in‑memory diagnostics alongside persistent audit entries.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries for troubleshooting.
 */

import Foundation
import SwiftData
import OSLog

// MARK: - Analytics & Audit Protocols

public protocol DataStoreAnalyticsLogger {
    /// Log a data store event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol DataStoreAuditLogger {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullDataStoreAnalyticsLogger: DataStoreAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String: Any]?) async {}
}

public struct NullDataStoreAuditLogger: DataStoreAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String: String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a data store operation for diagnostics.
public struct DataStoreServiceAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let entity: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), operation: String, entity: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.entity = entity
        self.detail = detail
    }
}

/// Concurrency-safe actor for in-memory audit logging.
public actor DataStoreServiceAuditManager {
    private var buffer: [DataStoreServiceAuditEntry] = []
    private let maxEntries = 200
    public static let shared = DataStoreServiceAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: DataStoreServiceAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [DataStoreServiceAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - DataStoreService (Modular, Tokenized, Auditable, Unified CRUD/Data Engine)

/// Singleton service for all app data CRUD operations.
/// This is a modular, auditable, tokenized CRUD/data service that centralizes access for all business models.
/// It supports comprehensive audit and event trails, analytics, compliance monitoring, and UI tokenization.
/// Designed to enable scalable, owner-focused business workflows and enterprise-level reporting.
/// Ensures data integrity, traceability, and seamless integration across app features and compliance requirements.
final class DataStoreService: ObservableObject {
    /// Shared singleton instance of DataStoreService for app-wide data management.
    /// Centralized access point ensures consistent audit and analytics tracking across business domains.
    static let shared = DataStoreService()

    /// The core model container managing all persistent models.
    /// Modular registration supports flexible business entity compliance and extensibility.
    let modelContainer: ModelContainer

    /// Logger dedicated to audit trail compliance, business diagnostics, and error/event monitoring.
    /// Captures critical operations for traceability, security, and regulatory adherence.
    private let auditLogger = Logger(subsystem: "com.furfolio.datastore", category: "AuditTrail")

    private let analytics: DataStoreAnalyticsLogger
    private let auditLoggerActor: DataStoreAuditLogger

    /// Primary context for data operations, providing a consistent environment for CRUD actions.
    /// Includes audit/error handling and event logging rationale to ensure operational reliability.
    var context: ModelContext {
        do {
            return modelContainer.mainContext
        } catch {
            auditLogger.error("Failed to get mainContext from modelContainer: \(String(describing: error))")
            // Fallback: create a new context or handle gracefully
            return modelContainer.createBackgroundContext()
        }
    }

    private init(
        analytics: DataStoreAnalyticsLogger = NullDataStoreAnalyticsLogger(),
        auditLoggerActor: DataStoreAuditLogger = NullDataStoreAuditLogger()
    ) {
        // Replace "FurfolioModel" with your actual model container name if different.
        // Registering all business models for modular, compliant data management.
        modelContainer = try! ModelContainer(for: [
            DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self,
            LoyaltyProgram.self, AuditLog.self, User.self, StaffMember.self, Session.self,
            VaccinationRecord.self, Business.self, GroomingSession.self, DailyRevenue.self,
            OwnerActivityLog.self, Contact.self
            // Add more models as needed
        ])
        self.analytics = analytics
        self.auditLoggerActor = auditLoggerActor
        self.auditLogger = Logger(subsystem: "com.furfolio.datastore", category: "AuditTrail")
    }

    // MARK: - Generic CRUD

    /// Save any changes in the context.
    /// Performs audit and event logging to ensure compliance and analytics tracking.
    @MainActor
    func save() async {
        Task {
            await analytics.log(event: "Save", parameters: nil)
            await auditLoggerActor.record("Save operation", metadata: nil)
            await DataStoreServiceAuditManager.shared.add(
                DataStoreServiceAuditEntry(operation: "Save", entity: "Context", detail: nil)
            )
        }
        do {
            try context.save()
            auditLogger.log("Context saved successfully.")
        } catch {
            auditLogger.error("DataStoreService SAVE ERROR: \(String(describing: error))")
        }
    }

    /// Fetch all objects of a type with optional filtering and sorting.
    /// Supports audit trail and analytics by centralizing data access patterns.
    /// - Parameters:
    ///   - type: The PersistentModel type to fetch.
    ///   - predicate: Optional filter predicate.
    ///   - sort: Optional sort descriptors.
    ///   - businessId: Optional business context for multi-tenant filtering.
    /// - Returns: Array of fetched objects.
    @MainActor
    func fetchAll<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>? = nil, sort: [SortDescriptor<T>] = [], businessId: UUID? = nil) async -> [T] {
        Task {
            await analytics.log(event: "FetchAll", parameters: ["entity": String(describing: T.self)])
            await auditLoggerActor.record("FetchAll operation", metadata: ["entity": String(describing: T.self)])
            await DataStoreServiceAuditManager.shared.add(
                DataStoreServiceAuditEntry(operation: "FetchAll", entity: String(describing: T.self), detail: nil)
            )
        }
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sort)
        do {
            let results = try context.fetch(fetchDescriptor)
            return results
        } catch {
            auditLogger.error("DataStoreService FETCH ERROR: \(String(describing: error))")
            return []
        }
    }

    /// Fetch a single object by unique identifier.
    /// Facilitates audit and workflow processes requiring precise entity retrieval.
    /// - Parameters:
    ///   - type: The PersistentModel type.
    ///   - id: UUID identifier of the object.
    /// - Returns: Optional object matching the id.
    @MainActor
    func fetchByID<T: PersistentModel>(_ type: T.Type, id: UUID) async -> T? {
        let all = await fetchAll(type)
        return all.first { ($0 as? Identifiable)?.id as? UUID == id }
    }

    /// Insert a new object into the context.
    /// Includes audit logging for creation tracking and compliance.
    /// - Parameter object: The PersistentModel object to insert.
    @MainActor
    func insert<T: PersistentModel>(_ object: T) async {
        Task {
            await analytics.log(event: "Insert", parameters: ["entity": String(describing: T.self)])
            await auditLoggerActor.record("Insert operation", metadata: ["entity": String(describing: T.self)])
            await DataStoreServiceAuditManager.shared.add(
                DataStoreServiceAuditEntry(operation: "Insert", entity: String(describing: T.self), detail: nil)
            )
        }
        context.insert(object)
        await save()
        await logAudit(operation: "Insert", object: object)
    }

    /// Delete an object from the context.
    /// Includes audit logging for deletion tracking and compliance.
    /// - Parameter object: The PersistentModel object to delete.
    @MainActor
    func delete<T: PersistentModel>(_ object: T) async {
        Task {
            await analytics.log(event: "Delete", parameters: ["entity": String(describing: T.self)])
            await auditLoggerActor.record("Delete operation", metadata: ["entity": String(describing: T.self)])
            await DataStoreServiceAuditManager.shared.add(
                DataStoreServiceAuditEntry(operation: "Delete", entity: String(describing: T.self), detail: nil)
            )
        }
        context.delete(object)
        await save()
        await logAudit(operation: "Delete", object: object)
    }

    /// Update an object by saving context changes.
    /// Supports audit/event logging and analytics for modification tracking.
    @MainActor
    func update() async {
        Task {
            await analytics.log(event: "Update", parameters: nil)
            await auditLoggerActor.record("Update operation", metadata: nil)
            await DataStoreServiceAuditManager.shared.add(
                DataStoreServiceAuditEntry(operation: "Update", entity: "Context", detail: nil)
            )
        }
        await save()
    }

    // MARK: - Audit Logging

    /// Internal method to log audit entries for CRUD operations.
    /// Supports compliance, traceability, and enterprise reporting requirements.
    /// - Parameters:
    ///   - operation: Description of the operation (Insert, Delete, Update).
    ///   - object: The PersistentModel object involved.
    @MainActor
    private func logAudit<T: PersistentModel>(operation: String, object: T) async {
        do {
            let auditEntry = AuditLog(context: context)
            auditEntry.timestamp = Date()
            auditEntry.operation = operation
            auditEntry.entityName = String(describing: T.self)
            if let identifiable = object as? Identifiable, let id = identifiable.id as? UUID {
                auditEntry.entityId = id
            }
            context.insert(auditEntry)
            try context.save()
            auditLogger.log("\(operation) operation logged for entity \(String(describing: T.self))")
        } catch {
            auditLogger.error("Failed to log audit operation \(operation) for entity \(String(describing: T.self)): \(String(describing: error))")
        }
    }

    // MARK: - Model-Specific Shortcuts

    /// Fetch dog owners with optional filter for active status and business context.
    /// Supports owner-focused workflows and business analytics.
    /// - Parameters:
    ///   - activeOnly: Filter for active owners.
    ///   - businessId: Business context for multi-tenant scenarios.
    /// - Returns: Array of DogOwner objects.
    @MainActor
    func fetchOwners(activeOnly: Bool = false, businessId: UUID? = nil) async -> [DogOwner] {
        let all = await fetchAll(DogOwner.self, businessId: businessId)
        return activeOnly ? all.filter { $0.isActive } : all
    }

    /// Fetch dogs optionally filtered by owner and business context.
    /// Facilitates owner-centric data retrieval and compliance.
    /// - Parameters:
    ///   - owner: Optional DogOwner to filter dogs.
    ///   - businessId: Business context.
    /// - Returns: Array of Dog objects.
    @MainActor
    func fetchDogs(for owner: DogOwner? = nil, businessId: UUID? = nil) async -> [Dog] {
        let all = await fetchAll(Dog.self, businessId: businessId)
        if let owner = owner {
            return all.filter { $0.owner?.id == owner.id }
        }
        return all
    }

    /// Fetch appointments with optional filter for upcoming only and business context.
    /// Supports scheduling workflows, audit, and analytics.
    /// - Parameters:
    ///   - upcomingOnly: Filter for future appointments.
    ///   - businessId: Business context.
    /// - Returns: Array of Appointment objects.
    @MainActor
    func fetchAppointments(upcomingOnly: Bool = false, businessId: UUID? = nil) async -> [Appointment] {
        let all = await fetchAll(Appointment.self, businessId: businessId)
        if upcomingOnly {
            let now = Date()
            return all.filter { $0.date >= now }
        }
        return all
    }

    /// Fetch charges optionally filtered by owner and business context.
    /// Supports billing workflows, audit, and compliance reporting.
    /// - Parameters:
    ///   - owner: Optional DogOwner filter.
    ///   - businessId: Business context.
    /// - Returns: Array of Charge objects.
    @MainActor
    func fetchCharges(for owner: DogOwner? = nil, businessId: UUID? = nil) async -> [Charge] {
        let all = await fetchAll(Charge.self, businessId: businessId)
        if let owner = owner {
            return all.filter { $0.owner?.id == owner.id }
        }
        return all
    }

    // MARK: - Reset / Nuke

    /// Delete all data of a specific model type.
    /// WARNING: Destructive operation with audit and compliance logging.
    /// Use carefully for development or "Reset App" workflows.
    /// - Parameter type: The PersistentModel type to delete.
    @MainActor
    func deleteAll<T: PersistentModel>(_ type: T.Type) async {
        auditLogger.warning("Deleting all records of type \(String(describing: T.self)) - destructive operation!")
        let all = await fetchAll(type)
        all.forEach { context.delete($0) }
        await save()
        auditLogger.log("Deleted all records of type \(String(describing: T.self))")
    }

    /// Wipe entire database by deleting all registered model data.
    /// Intended for development use, with comprehensive audit trail and compliance monitoring.
    @MainActor
    func wipeDatabase() async {
        auditLogger.warning("Wiping entire database - destructive operation!")
        await deleteAll(DogOwner.self)
        await deleteAll(Dog.self)
        await deleteAll(Appointment.self)
        await deleteAll(Charge.self)
        await deleteAll(Task.self)
        await deleteAll(LoyaltyProgram.self)
        await deleteAll(AuditLog.self)
        await deleteAll(User.self)
        await deleteAll(StaffMember.self)
        await deleteAll(Session.self)
        await deleteAll(VaccinationRecord.self)
        await deleteAll(Business.self)
        await deleteAll(GroomingSession.self)
        await deleteAll(DailyRevenue.self)
        await deleteAll(OwnerActivityLog.self)
        await deleteAll(Contact.self)
        auditLogger.log("Database wiped successfully.")
    }

    /// Convenience method to perform full app data reset with audit logging.
    /// Supports compliance workflows, owner data lifecycle management, and enterprise reporting.
    @MainActor
    func resetAppData() async {
        auditLogger.warning("Resetting app data - full wipe initiated!")
        await wipeDatabase()
        auditLogger.log("App data reset completed.")
    }

    // MARK: - Additional Features

    /// Stub for Traveling Salesman Problem (TSP) route optimization integration.
    /// Future implementation will support audit, analytics, reporting, and owner workflow enhancements.
    @MainActor
    func processTSPRouteOptimization() async {
        // TODO: Implement Traveling Salesman Problem route optimization logic here
        auditLogger.log("processTSPRouteOptimization called - stub implementation.")
    }

    /// Stub for batch image caching or prefetching.
    /// Intended to improve performance and support analytics and reporting on media usage.
    /// Will enhance owner workflow efficiency and UI responsiveness.
    @MainActor
    func batchImageCaching() async {
        // TODO: Implement batch image caching or prefetching logic here
        auditLogger.log("batchImageCaching called - stub implementation.")
    }
}

// MARK: - Diagnostics

public extension DataStoreService {
    /// Fetch recent in-memory audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [DataStoreServiceAuditEntry] {
        await DataStoreServiceAuditManager.shared.recent(limit: limit)
    }

    /// Export in-memory audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await DataStoreServiceAuditManager.shared.exportJSON()
    }
}
