//
//  MigrationManager.swift
//  Furfolio
//
//  Enhanced & Auditable: 2025+ Grooming Business App Architecture
//

import Foundation
import SwiftData

// MARK: - MigrationManager (Unified, Modular, Tokenized, Auditable Data Model Migration)

@MainActor
final class MigrationManager: ObservableObject {
    static let shared = MigrationManager()
    
    // MARK: - Migration Audit Log
    
    struct MigrationAuditEvent: Codable {
        let timestamp: Date
        let operation: String      // "check" | "start" | "step" | "success" | "error"
        let fromVersion: Int
        let toVersion: Int
        let status: String         // "success" | "error" | "info"
        let tags: [String]
        let actor: String?
        let context: String?
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(operation.capitalized) migration v\(fromVersion)→v\(toVersion) (\(status)) at \(dateStr)\(errorDescription != nil ? ": \(errorDescription!)" : "")"
        }
    }
    private(set) static var auditLog: [MigrationAuditEvent] = []

    private func addAudit(
        operation: String,
        fromVersion: Int,
        toVersion: Int,
        status: String,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        error: Error? = nil
    ) {
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
        Self.auditLog.append(event)
        if Self.auditLog.count > 500 { Self.auditLog.removeFirst() }
    }
    
    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    var accessibilitySummary: String {
        Self.auditLog.last?.accessibilityLabel ?? "No migration events recorded."
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
    func checkMigration(actor: String? = nil, context: String? = nil) {
        let oldVersion = currentVersion
        currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        migrationNeeded = (currentVersion < latestVersion)
        addAudit(
            operation: "check",
            fromVersion: oldVersion,
            toVersion: currentVersion,
            status: migrationNeeded ? "needsMigration" : "upToDate",
            tags: ["migration", "check"],
            actor: actor,
            context: context
        )
    }
    
    // MARK: - Migration Orchestration
    func migrateIfNeeded(context: ModelContext, actor: String? = nil, migrationContext: String? = nil) {
        checkMigration(actor: actor, context: migrationContext)
        guard migrationNeeded else { return }
        migrationInProgress = true
        migrationError = nil
        migrationSuccess = false
        migrationLog.removeAll()
        
        addAudit(
            operation: "start",
            fromVersion: currentVersion,
            toVersion: latestVersion,
            status: "started",
            tags: ["migration", "start"],
            actor: actor,
            context: migrationContext
        )
        
        do {
            try performMigrationSteps(context: context, from: currentVersion, to: latestVersion, actor: actor, context: migrationContext)
            completeMigration(actor: actor, context: migrationContext)
        } catch {
            log("Migration error: \(error.localizedDescription)")
            migrationError = "Migration failed: \(error.localizedDescription)"
            migrationInProgress = false
            addAudit(
                operation: "error",
                fromVersion: currentVersion,
                toVersion: latestVersion,
                status: "error",
                tags: ["migration", "error"],
                actor: actor,
                context: migrationContext,
                error: error
            )
        }
    }
    
    // MARK: - Migration Steps
    private func performMigrationSteps(context: ModelContext, from oldVersion: Int, to newVersion: Int, actor: String?, context migrationContext: String?) throws {
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
                log("Created default Business entity on migration.")
                try context.save()
                */
                addAudit(
                    operation: "step",
                    fromVersion: version,
                    toVersion: version + 1,
                    status: "success",
                    tags: ["migration", "v0->v1"],
                    actor: actor,
                    context: migrationContext
                )
                break
            // --- Add future migration cases here. ---
            default:
                addAudit(
                    operation: "step",
                    fromVersion: version,
                    toVersion: version + 1,
                    status: "info",
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
    private func completeMigration(actor: String? = nil, context: String? = nil) {
        UserDefaults.standard.set(latestVersion, forKey: versionKey)
        currentVersion = latestVersion
        migrationNeeded = false
        migrationInProgress = false
        migrationSuccess = true
        log("Migration complete. Data is up to date (v\(latestVersion)).")
        addAudit(
            operation: "success",
            fromVersion: currentVersion,
            toVersion: latestVersion,
            status: "success",
            tags: ["migration", "complete"],
            actor: actor,
            context: context
        )
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
        migrationLog.append("[\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))] \(message)")
        print("MigrationManager: \(message)")
    }
    
    // MARK: - UI Reset
    func resetMigrationStatus() {
        migrationSuccess = false
        migrationError = nil
        migrationLog.removeAll()
    }
}

// MARK: - Example Usage
/*
 // At app launch (in AppState, DependencyContainer, or FurfolioApp.swift):
 MigrationManager.shared.migrateIfNeeded(context: modelContext)
 
 // Show progress or alerts in SwiftUI:
 .alert(isPresented: $migrationManager.migrationNeeded) {
     Alert(
         title: Text("Migration Needed"),
         message: Text("Upgrading your Furfolio data..."),
         dismissButton: .default(Text("OK"))
     )
 }
 
 // Show logs (in developer mode):
 ForEach(migrationManager.migrationLog, id: \.self) { Text($0) }
 
 // Show migration audit in Trust Center or admin dashboard:
 ForEach(MigrationManager.auditLog, id: \.timestamp) { event in
     Text(event.accessibilityLabel)
 }
 
 // Export audit as JSON for compliance:
 let json = MigrationManager.exportLastAuditEventJSON()
*/
