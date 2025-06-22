//
//  MigrationManager.swift
//  Furfolio
//
//  Enhanced & Unified: 2025+ Grooming Business App Architecture
//

import Foundation
import SwiftData

// MARK: - MigrationManager (Unified, Modular, Tokenized, Auditable Data Model Migration)

/// Handles all Furfolio data model migrations.
/// MigrationManager is modular, auditable, and supports tokenized, versioned model migrations; all migration actions and errors should be logged and available for audit/compliance.
/// Future: support tokenized migration badges in UI, event hooks, owner/staff privacy controls.
@MainActor
final class MigrationManager: ObservableObject {
    /// Shared singleton instance for global migration management and audit logging.
    static let shared = MigrationManager()
    
    /// Tracks the current data model version from persistent storage; used for audit and migration logic.
    private(set) var currentVersion: Int
    
    /// The latest supported data model version; bump this as your data models change.
    private let latestVersion: Int = 1
    
    /// Indicates if a migration is currently needed; used to trigger UI alerts and migration workflows.
    @Published var migrationNeeded: Bool = false
    
    /// Indicates if a migration is currently in progress; useful for UI progress indicators and blocking actions.
    @Published var migrationInProgress: Bool = false
    
    /// Holds any error message encountered during migration; surfaced to UI and audit logs.
    @Published var migrationError: String? = nil
    
    /// Indicates successful completion of migration; can trigger UI updates and audit events.
    @Published var migrationSuccess: Bool = false
    
    /// Accumulates all migration-related log messages for audit, event reporting, and developer diagnostics.
    @Published var migrationLog: [String] = []
    
    /// UserDefaults key for storing the current data model version.
    private let versionKey = "FurfolioDataModelVersion"
    
    private init() {
        self.currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        self.migrationNeeded = (currentVersion < latestVersion)
    }
    
    // MARK: - Migration Check
    /// Checks and updates migrationNeeded flag based on stored version; logs status for audit.
    func checkMigration() {
        currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        migrationNeeded = (currentVersion < latestVersion)
    }
    
    // MARK: - Migration Orchestration
    /// Attempts migration if needed. Run at app startup or after updates.
    func migrateIfNeeded(context: ModelContext) {
        checkMigration()
        guard migrationNeeded else { return }
        migrationInProgress = true
        migrationError = nil
        migrationSuccess = false
        migrationLog.removeAll()
        
        do {
            try performMigrationSteps(context: context, from: currentVersion, to: latestVersion)
            completeMigration()
        } catch {
            log("Migration error: \(error.localizedDescription)")
            migrationError = "Migration failed: \(error.localizedDescription)"
            migrationInProgress = false
        }
    }
    
    // MARK: - Migration Steps
    /// Customize for each upgrade version.
    /// TODO: Ensure all migrations are logged and audit-compliant; add hooks for badge/status/event reporting.
    private func performMigrationSteps(context: ModelContext, from oldVersion: Int, to newVersion: Int) throws {
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
                break
            // --- Add future migration cases here. ---
            default:
                break
            }
            version += 1
        }
    }
    
    // MARK: - Complete Migration
    /// Finalizes migration by updating version, flags, and logging.
    /// This must log completion for audit and trigger event/badge/report hooks for UI/owner.
    private func completeMigration() {
        UserDefaults.standard.set(latestVersion, forKey: versionKey)
        currentVersion = latestVersion
        migrationNeeded = false
        migrationInProgress = false
        migrationSuccess = true
        log("Migration complete. Data is up to date (v\(latestVersion)).")
    }
    
    // MARK: - Logging
    /// Logs migration messages.
    /// All logs should be available for audit/event reporting and developer diagnostics.
    private func log(_ message: String) {
        migrationLog.append("[\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))] \(message)")
        print("MigrationManager: \(message)")
    }
    
    // MARK: - UI Reset
    /// Resets migration status flags and clears logs; useful for UI refresh or retry.
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
 
 // Note: Migration status and audit logs should be shown in the Trust Center and business compliance dashboard for transparency and governance.
*/
