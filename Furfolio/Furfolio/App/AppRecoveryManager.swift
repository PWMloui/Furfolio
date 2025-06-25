//
//  AppRecoveryManager.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, async-ready, extensible, robust.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Analytics/Audit Protocol

public protocol AppRecoveryAnalyticsLogger {
    func log(event: String, detail: String?)
}
public struct NullAppRecoveryAnalyticsLogger: AppRecoveryAnalyticsLogger {
    public init() {}
    public func log(event: String, detail: String?) {}
}

// MARK: - AppRecoveryManager

final class AppRecoveryManager: ObservableObject {
    static let shared = AppRecoveryManager()
    /// Analytics logger (BI/QA/Trust Center; DI/test-injectable)
    static var analyticsLogger: AppRecoveryAnalyticsLogger = NullAppRecoveryAnalyticsLogger()

    private init() {}

    // MARK: - Backup

    func createBackup(modelContainer: ModelContainer, backupName: String? = nil) throws -> URL {
        let backupFilename = backupName ?? "FurfolioBackup-\(dateString()).sqlite"
        let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backupFilename)

        try modelContainer.saveBackup(to: backupURL)
        Self.analyticsLogger.log(event: "backup_created", detail: backupURL.lastPathComponent)
        return backupURL
    }

    /// Async-ready version (future)
    func createBackupAsync(modelContainer: ModelContainer, backupName: String? = nil) async throws -> URL {
        let url = try createBackup(modelContainer: modelContainer, backupName: backupName)
        return url
    }

    func restoreBackup(modelContainer: ModelContainer, from url: URL) throws {
        try modelContainer.restoreBackup(from: url)
        Self.analyticsLogger.log(event: "backup_restored", detail: url.lastPathComponent)
    }

    // MARK: - Export

    func exportData(models: FurfolioExportModels) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(models)
        let filename = "FurfolioExport-\(dateString()).json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try data.write(to: url)
        Self.analyticsLogger.log(event: "data_exported", detail: url.lastPathComponent)
        return url
    }

    // MARK: - Import

    func importData(from url: URL) throws -> FurfolioExportModels {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FurfolioExportModels.self, from: data)
        Self.analyticsLogger.log(event: "data_imported", detail: url.lastPathComponent)
        return decoded
    }

    // Async example (future)
    func importDataAsync(from url: URL) async throws -> FurfolioExportModels {
        return try importData(from: url)
    }

    // MARK: - Crash Recovery

    func checkForCrashAndRecover(modelContainer: ModelContainer) {
        if wasCrashDetected, let latestBackup = latestBackupURL {
            do {
                try restoreBackup(modelContainer: modelContainer, from: latestBackup)
                Self.analyticsLogger.log(event: "crash_recovery_success", detail: latestBackup.lastPathComponent)
            } catch {
                Self.analyticsLogger.log(event: "crash_recovery_failed", detail: error.localizedDescription)
            }
        }
    }

    // MARK: - Utilities

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    var latestBackupURL: URL? {
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = (try? FileManager.default.contentsOfDirectory(at: docURL, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.lastPathComponent.contains("FurfolioBackup") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    var wasCrashDetected: Bool {
        UserDefaults.standard.bool(forKey: "FurfolioCrashFlag")
    }

    // MARK: - Trust Center/Permissions Stub

    /// Hook for Trust Center permission and audit trails.
    func requirePermission(_ permission: String) -> Bool {
        // Example: check user role, audit trail, or privacy consent
        // Return true if allowed; log the check
        Self.analyticsLogger.log(event: "permission_check", detail: permission)
        return true
    }
}

// MARK: - FurfolioExportModels (unchanged, still extensible)

// ...[unchanged FurfolioExportModels code]...

// MARK: - ModelContainer Extension (unchanged, still extensible)

// ...[unchanged ModelContainer backup/restore code]...

// MARK: - Usage Example for Audit/Preview

#if DEBUG
struct AppRecoveryAuditPreview {
    struct SpyLogger: AppRecoveryAnalyticsLogger {
        func log(event: String, detail: String?) {
            print("[AppRecoveryAudit] \(event) \(detail ?? "")")
        }
    }
    static func runDemo() {
        AppRecoveryManager.analyticsLogger = SpyLogger()
        // Simulate backup/export/import/crash-recovery calls here for QA/audit testing
    }
}
#endif
