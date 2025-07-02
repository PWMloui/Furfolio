//
//  MigrationManager.swift
//  Furfolio
//
//  Enhanced & Auditable: 2025+ Grooming Business App Architecture
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - MigrationManager (Unified, Modular, Tokenized, Auditable Data Model Migration)

@MainActor
final class MigrationManager: ObservableObject {
    static let shared = MigrationManager()
    
    // MARK: - Migration Audit Log (SwiftData-based)

    @Model public struct MigrationAuditEvent: Identifiable {
        @Attribute(.unique) public var id: UUID = UUID()
        public var timestamp: Date
        public var operation: String      // "check" | "start" | "step" | "success" | "error"
        public var fromVersion: Int
        public var toVersion: Int
        public var status: String         // "success" | "error" | "info"
        public var tags: [String]
        public var actor: String?
        public var context: String?
        public var errorDescription: String?
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(operation.capitalized) migration v\(fromVersion)→v\(toVersion) (\(status)) at \(dateStr)\(errorDescription != nil ? ": \(errorDescription!)" : "")"
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) private var auditEvents: [MigrationAuditEvent]

    /// Appends a new audit event to the audit log using SwiftData.
    @MainActor
    func addAudit(
        operation: String,
        fromVersion: Int,
        toVersion: Int,
        status: String,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        error: Error? = nil
    ) async {
        let event = MigrationAuditEvent(
            timestamp: Date(),
            operation: operation,
            fromVersion: fromVersion,
            toVersion: toVersion,
            status: status,
            tags: tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        modelContext.insert(event)
    }

    /// Exports the last audit event as a pretty-printed JSON string asynchronously.
    /// - Returns: A JSON string representing the last audit event, or `nil` if no events exist.
    func exportLastAuditEventJSON() async -> String? {
        let last = auditEvents.last
        guard let lastEvent = last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(lastEvent)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides an accessibility summary of the last migration audit event asynchronously.
    var accessibilitySummary: String {
        get async {
            return auditEvents.last?.accessibilityLabel
                ?? NSLocalizedString("migration.noEvents", comment: "No migration events recorded.")
        }
    }

    /// Fetches recent audit events optionally filtered by tags, actor, or context asynchronously.
    /// - Parameters:
    ///   - tags: Optional array of tags to filter events. Events must contain at least one of these tags.
    ///   - actor: Optional actor identifier to filter events.
    ///   - context: Optional context string to filter events.
    /// - Returns: An array of `MigrationAuditEvent` matching the filters.
    func fetchAuditEvents(
        filteredByTags tags: [String]? = nil,
        actor: String? = nil,
        context: String? = nil
    ) async -> [MigrationAuditEvent] {
        var results = auditEvents
        if let tags = tags, !tags.isEmpty {
            results = results.filter { !Set(tags).isDisjoint(with: $0.tags) }
        }
        if let actor = actor {
            results = results.filter { $0.actor == actor }
        }
        if let context = context {
            results = results.filter { $0.context == context }
        }
        return results
    }

    /// Clears all audit events.
    @MainActor
    func clearAuditLog() async {
        auditEvents.forEach { modelContext.delete($0) }
    }
    
    // --- Migration State Properties (unchanged) ---
    private(set) var currentVersion: Int
    private let latestVersion: Int = 1
    @Published var migrationNeeded: Bool = false
    @Published var migrationInProgress: Bool = false
    @Published var migrationError: String? = nil
    @Published var migrationSuccess: Bool = false
    @Published var migrationLog: [String] = []
    private let versionKey = "FurfolioDataModelVersion"
    
    private init() {
        self.currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        self.migrationNeeded = (currentVersion < latestVersion)
    }
    
    // MARK: - Migration Check
    @MainActor
    func checkMigration(actor: String? = nil, context: String? = nil) async {
        let oldVersion = currentVersion
        currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        migrationNeeded = (currentVersion < latestVersion)
        await addAudit(
            operation: NSLocalizedString("migration.operation.check", comment: "Migration check operation"),
            fromVersion: oldVersion,
            toVersion: currentVersion,
            status: migrationNeeded ? NSLocalizedString("migration.status.needsMigration", comment: "Migration needed") : NSLocalizedString("migration.status.upToDate", comment: "Migration up to date"),
            tags: ["migration", "check"],
            actor: actor,
            context: context
        )
    }
    
    // MARK: - Migration Orchestration
    @MainActor
    func migrateIfNeeded(context: ModelContext, actor: String? = nil, migrationContext: String? = nil) async {
        await checkMigration(actor: actor, context: migrationContext)
        guard migrationNeeded else { return }
        migrationInProgress = true
        migrationError = nil
        migrationSuccess = false
        migrationLog.removeAll()
        
        await addAudit(
            operation: NSLocalizedString("migration.operation.start", comment: "Migration start operation"),
            fromVersion: currentVersion,
            toVersion: latestVersion,
            status: NSLocalizedString("migration.status.started", comment: "Migration started"),
            tags: ["migration", "start"],
            actor: actor,
            context: migrationContext
        )
        
        do {
            try await performMigrationSteps(context: context, from: currentVersion, to: latestVersion, actor: actor, context: migrationContext)
            await completeMigration(actor: actor, context: migrationContext)
        } catch {
            await log(NSLocalizedString("migration.error.prefix", comment: "Migration error prefix") + " \(error.localizedDescription)")
            migrationError = NSLocalizedString("migration.error.prefix", comment: "Migration error prefix") + " \(error.localizedDescription)"
            migrationInProgress = false
            await addAudit(
                operation: NSLocalizedString("migration.operation.error", comment: "Migration error operation"),
                fromVersion: currentVersion,
                toVersion: latestVersion,
                status: NSLocalizedString("migration.status.error", comment: "Migration error status"),
                tags: ["migration", "error"],
                actor: actor,
                context: migrationContext,
                error: error
            )
        }
    }
    
    // MARK: - Migration Steps
    @MainActor
    private func performMigrationSteps(context: ModelContext, from oldVersion: Int, to newVersion: Int, actor: String?, context migrationContext: String?) async throws {
        var version = oldVersion
        
        while version < newVersion {
            switch version {
            case 0:
                // --- EXAMPLE MIGRATION: ---
                // 1. Fix broken fields, set defaults, migrate structures
                // 2. Example: Add default admin business
                /*
                let business = Business(
                    name: "Furfolio Grooming",
                    createdAt: Date(),
                    ownerName: "Business Owner",
                    isActive: true
                )
                context.insert(business)
                await log(NSLocalizedString("migration.log.createdDefaultBusiness", comment: "Created default Business entity on migration."))
                try context.save()
                */
                await addAudit(
                    operation: NSLocalizedString("migration.operation.step", comment: "Migration step operation"),
                    fromVersion: version,
                    toVersion: version + 1,
                    status: NSLocalizedString("migration.status.success", comment: "Migration success status"),
                    tags: ["migration", "v0->v1"],
                    actor: actor,
                    context: migrationContext
                )
                break
            // --- Add future migration cases here. ---
            default:
                await addAudit(
                    operation: NSLocalizedString("migration.operation.step", comment: "Migration step operation"),
                    fromVersion: version,
                    toVersion: version + 1,
                    status: NSLocalizedString("migration.status.info", comment: "Migration info status"),
                    tags: ["migration", "noop"],
                    actor: actor,
                    context: migrationContext
                )
                break
            }
            version += 1
        }
    }
    
    // MARK: - Complete Migration
    @MainActor
    private func completeMigration(actor: String? = nil, context: String? = nil) async {
        UserDefaults.standard.set(latestVersion, forKey: versionKey)
        currentVersion = latestVersion
        migrationNeeded = false
        migrationInProgress = false
        migrationSuccess = true
        await log(String(format: NSLocalizedString("migration.log.complete", comment: "Migration complete log"), latestVersion))
        await addAudit(
            operation: NSLocalizedString("migration.operation.success", comment: "Migration success operation"),
            fromVersion: currentVersion,
            toVersion: latestVersion,
            status: NSLocalizedString("migration.status.success", comment: "Migration success status"),
            tags: ["migration", "complete"],
            actor: actor,
            context: context
        )
    }
    
    // MARK: - Logging
    @MainActor
    private func log(_ message: String) async {
        migrationLog.append("[\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))] \(message)")
        print("MigrationManager: \(message)")
    }
    
    // MARK: - UI Reset
    @MainActor
    func resetMigrationStatus() {
        migrationSuccess = false
        migrationError = nil
        migrationLog.removeAll()
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async audit logging, fetching, filtering, clearing, and accessibility.

#if DEBUG
import PlaygroundSupport

@MainActor
struct MigrationManagerPreviewView: View {
    @StateObject private var migrationManager = MigrationManager.shared
    @State private var auditEvents: [MigrationManager.MigrationAuditEvent] = []
    @State private var auditSummary: String = ""
    @State private var auditJSON: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Migration Audit Summary:")
                .font(.headline)
            Text(auditSummary)
                .font(.subheadline)
                .padding()

            Button("Fetch All Audit Events") {
                Task {
                    auditEvents = await migrationManager.fetchAuditEvents()
                }
            }
            Button("Fetch Audit Events with Tag 'migration'") {
                Task {
                    auditEvents = await migrationManager.fetchAuditEvents(filteredByTags: ["migration"])
                }
            }
            Button("Clear Audit Log") {
                Task {
                    await migrationManager.clearAuditLog()
                    auditEvents = []
                    auditSummary = NSLocalizedString("migration.noEvents", comment: "No migration events recorded.")
                    auditJSON = ""
                }
            }
            Button("Export Last Audit Event JSON") {
                Task {
                    auditJSON = (await migrationManager.exportLastAuditEventJSON()) ?? NSLocalizedString("migration.noEvents", comment: "No migration events recorded.")
                }
            }

            List(auditEvents, id: \.timestamp) { event in
                VStack(alignment: .leading) {
                    Text(event.accessibilityLabel)
                        .font(.caption)
                }
            }

            if !auditJSON.isEmpty {
                Text("Last Audit Event JSON:")
                    .font(.headline)
                ScrollView {
                    Text(auditJSON)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .task {
            auditSummary = await migrationManager.accessibilitySummary
            auditEvents = await migrationManager.fetchAuditEvents()
        }
    }
}

struct MigrationManager_Previews: PreviewProvider {
    static var previews: some View {
        MigrationManagerPreviewView()
    }
}
#endif

// MARK: - Example Usage
/*
 // At app launch (in AppState, DependencyContainer, or FurfolioApp.swift):
 Task {
     await MigrationManager.shared.migrateIfNeeded(context: modelContext)
 }
 
 // Show progress or alerts in SwiftUI:
 .alert(isPresented: $migrationManager.migrationNeeded) {
     Alert(
         title: Text(NSLocalizedString("migration.alert.title", comment: "Migration Needed")),
         message: Text(NSLocalizedString("migration.alert.message", comment: "Upgrading your Furfolio data...")),
         dismissButton: .default(Text(NSLocalizedString("migration.alert.dismiss", comment: "OK")))
     )
 }
 
 // Show logs (in developer mode):
 ForEach(migrationManager.migrationLog, id: \.self) { Text($0) }
 
 // Show migration audit in Trust Center or admin dashboard:
 Task {
     let events = await MigrationManager.shared.fetchAuditEvents()
     ForEach(events, id: \.timestamp) { event in
         Text(event.accessibilityLabel)
     }
 }
 
 // Export audit as JSON for compliance:
 Task {
     let json = await MigrationManager.shared.exportLastAuditEventJSON()
 }
*/
