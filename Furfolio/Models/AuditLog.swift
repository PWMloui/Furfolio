//
//  AuditLog.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData

/// Records a single change (create/update/delete) to any entity in the system.
@Model
final class AuditLog: Identifiable {
    @Attribute var id: UUID
    @Attribute var entityName: String      // e.g. "DogOwner", "Charge"
    @Attribute var entityId: UUID          // the specific record's ID
    @Attribute var action: String          // "create", "update", or "delete"
    @Attribute var user: String?           // optional username or identifier
    @Attribute var details: String?        // optional JSON or description of changed fields
    @Attribute var timestamp: Date

    init(
        id: UUID = UUID(),
        entityName: String,
        entityId: UUID,
        action: String,
        user: String? = nil,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.entityName = entityName
        self.entityId = entityId
        self.action = action
        self.user = user
        self.details = details
        self.timestamp = timestamp
    }
}

extension AuditLog {
    /// Creates and inserts a new AuditLog entry.
    @discardableResult
    static func create(
        entityName: String,
        entityId: UUID,
        action: String,
        user: String? = nil,
        details: String? = nil,
        in context: ModelContext
    ) -> AuditLog {
        let entry = AuditLog(
            entityName: entityName,
            entityId: entityId,
            action: action,
            user: user,
            details: details
        )
        context.insert(entry)
        return entry
    }

    /// Fetches recent audit logs, sorted by newest first.
    static func fetchRecent(
        limit: Int = 100,
        in context: ModelContext
    ) -> [AuditLog] {
        var desc = FetchDescriptor<AuditLog>(
            predicate: nil,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        desc.fetchLimit = limit
        return (try? context.fetch(desc)) ?? []
    }
}
