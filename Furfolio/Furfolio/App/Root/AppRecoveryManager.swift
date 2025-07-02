//
//  AppRecoveryManager.swift
//  Furfolio
//
//  Enhanced 2025-06-30: Role/staff/context audit, compliance escalation, Trust Center/BI ready
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Analytics/Audit Protocol

public protocol AppRecoveryAnalyticsLogger {
    var testMode: Bool { get }
    func log(event: String, detail: String?, role: String?, staffID: String?, context: String?) async
    func escalate(event: String, detail: String?, role: String?, staffID: String?, context: String?) async
}
public struct NullAppRecoveryAnalyticsLogger: AppRecoveryAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, detail: String?, role: String?, staffID: String?, context: String?) async {}
    public func escalate(event: String, detail: String?, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - AppRecoveryManager

final class AppRecoveryManager: ObservableObject {
    static let shared = AppRecoveryManager()
    static var analyticsLogger: AppRecoveryAnalyticsLogger = NullAppRecoveryAnalyticsLogger()

    /// If true, disables file writes and escalations (logs to console only)
    var testMode: Bool = false

    /// Role/staff/business context for audit (set from app/session)
    static var currentRole: String? = nil
    static var currentStaffID: String? = nil
    static var currentContext: String? = "AppRecoveryManager"

    private var auditEvents: [AuditEvent] = []
    private let auditQueue = DispatchQueue(label: "com.furfolio.AppRecoveryManager.auditQueue", attributes: .concurrent)

    private init() {}

    // MARK: - Backup

    func createBackup(modelContainer: ModelContainer, backupName: String? = nil) async throws -> URL {
        let backupFilename = backupName ?? String(
            format: NSLocalizedString("FurfolioBackupFilenameFormat", comment: "Backup filename with timestamp"),
            dateString()
        ) + ".sqlite"

        let backupURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backupFilename)

        if testMode {
            await logToConsole(event: "backup_created", detail: backupURL.lastPathComponent)
            return backupURL
        } else {
            try modelContainer.saveBackup(to: backupURL)
            await log(event: "backup_created", detail: backupURL.lastPathComponent)
            return backupURL
        }
    }

    func createBackupAsync(modelContainer: ModelContainer, backupName: String? = nil) async throws -> URL {
        return try await createBackup(modelContainer: modelContainer, backupName: backupName)
    }

    func restoreBackup(modelContainer: ModelContainer, from url: URL) async throws {
        if testMode {
            await logToConsole(event: "backup_restored", detail: url.lastPathComponent)
        } else {
            try modelContainer.restoreBackup(from: url)
            await log(event: "backup_restored", detail: url.lastPathComponent)
        }
    }

    // MARK: - Export

    func exportData(models: FurfolioExportModels) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(models)
        let filename = String(
            format: NSLocalizedString("FurfolioExportFilenameFormat", comment: "Export filename with timestamp"),
            dateString()
        ) + ".json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        if testMode {
            await logToConsole(event: "data_exported", detail: url.lastPathComponent)
            return url
        } else {
            try data.write(to: url)
            await log(event: "data_exported", detail: url.lastPathComponent)
            return url
        }
    }

    // MARK: - Import

    func importData(from url: URL) async throws -> FurfolioExportModels {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FurfolioExportModels.self, from: data)

        if testMode {
            await logToConsole(event: "data_imported", detail: url.lastPathComponent)
        } else {
            await log(event: "data_imported", detail: url.lastPathComponent)
        }
        return decoded
    }

    func importDataAsync(from url: URL) async throws -> FurfolioExportModels {
        return try await importData(from: url)
    }

    // MARK: - Crash Recovery

    func checkForCrashAndRecover(modelContainer: ModelContainer) async {
        if wasCrashDetected, let latestBackup = latestBackupURL {
            do {
                if !testMode {
                    try modelContainer.restoreBackup(from: latestBackup)
                }
                await log(event: "crash_recovery_success", detail: latestBackup.lastPathComponent)
            } catch {
                await escalate(event: "crash_recovery_failed", detail: error.localizedDescription)
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

    // MARK: - Trust Center / Permissions

    func requirePermission(_ permission: String) async -> Bool {
        await log(event: "permission_check", detail: permission)
        // Add real permission logic if needed.
        return true
    }

    // MARK: - Audit Event Storage and Retrieval

    public struct AuditEvent: Codable, Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let event: String
        public let detail: String?
        public let role: String?
        public let staffID: String?
        public let context: String?
    }

    private func log(event: String, detail: String?) async {
        let auditEvent = AuditEvent(
            timestamp: Date(),
            event: event,
            detail: detail,
            role: Self.currentRole,
            staffID: Self.currentStaffID,
            context: Self.currentContext
        )
        auditQueue.async(flags: .barrier) {
            self.auditEvents.append(auditEvent)
            if self.auditEvents.count > 100 {
                self.auditEvents.removeFirst(self.auditEvents.count - 100)
            }
        }
        if testMode {
            await logToConsole(event: event, detail: detail)
        } else {
            await Self.analyticsLogger.log(
                event: event, detail: detail,
                role: Self.currentRole, staffID: Self.currentStaffID, context: Self.currentContext
            )
        }
    }

    private func escalate(event: String, detail: String?) async {
        let auditEvent = AuditEvent(
            timestamp: Date(),
            event: event,
            detail: detail,
            role: Self.currentRole,
            staffID: Self.currentStaffID,
            context: Self.currentContext
        )
        auditQueue.async(flags: .barrier) {
            self.auditEvents.append(auditEvent)
            if self.auditEvents.count > 100 {
                self.auditEvents.removeFirst(self.auditEvents.count - 100)
            }
        }
        if testMode {
            await logToConsole(event: "[ESCALATE] \(event)", detail: detail)
        } else {
            await Self.analyticsLogger.escalate(
                event: event, detail: detail,
                role: Self.currentRole, staffID: Self.currentStaffID, context: Self.currentContext
            )
        }
    }

    private func logToConsole(event: String, detail: String?) async {
        print("[AppRecoveryAudit] \(event) \(detail ?? "") [role:\(Self.currentRole ?? "-")] [staff:\(Self.currentStaffID ?? "-")] [ctx:\(Self.currentContext ?? "-")]")
    }

    public func fetchRecentAuditEvents(count: Int = 10) -> [AuditEvent] {
        var events: [AuditEvent] = []
        auditQueue.sync {
            events = Array(self.auditEvents.suffix(count).reversed())
        }
        return events
    }
}

// MARK: - Usage Example for Audit/Preview

#if DEBUG
struct AppRecoveryAuditPreview {
    struct SpyLogger: AppRecoveryAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, detail: String?, role: String?, staffID: String?, context: String?) async {
            print("[AppRecoveryAudit][TEST] \(event) \(detail ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
        }
        func escalate(event: String, detail: String?, role: String?, staffID: String?, context: String?) async {
            print("[AppRecoveryAudit][ESCALATE-TEST] \(event) \(detail ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
        }
    }
    static func runDemo() async {
        AppRecoveryManager.shared.testMode = true
        AppRecoveryManager.analyticsLogger = SpyLogger()
        // Simulate backup/export/import/crash-recovery calls here for QA/audit testing
    }
}
#endif
