//
//  CloudKitSyncEngine.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  CloudKitSyncEngine.swift
//
//  Architecture:
//  -------------
//  CloudKitSyncEngine is a singleton ObservableObject designed to manage and monitor the synchronization
//  state of SwiftData's model container with CloudKit. It listens to NSPersistentCloudKitContainer
//  event notifications, translates them into user-friendly status messages, and exposes published properties
//  for UI binding. It also manages retry logic and risk scoring for sync health.
//
//  Extensibility:
//  --------------
//  The engine is designed to be extensible; developers can add custom analytics loggers conforming to
//  AnalyticsLoggerProtocol, override retry intervals, and extend audit log handling. The public API
//  allows manual sync triggering and exporting of sync state and audit logs.
//
//  Analytics, Audit, and Trust Center Hooks:
//  -----------------------------------------
//  Sync events, errors, retries, and status changes are logged via an async analytics logger protocol,
//  allowing integration with backend analytics or Trust Center services. Audit logs are retained
//  in-memory with a capped buffer to avoid memory bloat.
//
//  Diagnostics and Debugging:
//  --------------------------
//  The audit log stores the last 1000 sync-related events with timestamps, accessible via exportJSON(),
//  aiding diagnostics and troubleshooting. The engine also exposes a risk score and badge tokens for UI
//  indicators.
//
//  Localization:
//  -------------
//  All user-facing strings and audit log entries are localized using NSLocalizedString with appropriate
//  keys and comments, facilitating internationalization.
//
//  Accessibility:
//  --------------
//  The engine provides an accessibilityLabel property that summarizes sync status, last sync time,
//  risk score, and errors, designed for assistive technologies.
//
//  Compliance and Privacy:
//  -----------------------
//  No sensitive user data is stored or transmitted. Audit logs and analytics events are designed to be
//  privacy-conscious, containing only sync state and error descriptions.
//
//  Preview and Testability:
//  ------------------------
//  Includes a NullAnalyticsLogger for safe usage in previews and tests, avoiding side effects.
//  The PreviewProvider demonstrates the sync status component with accessibility and diagnostics.
//
//  Usage:
//  ------
//  Access the shared instance via CloudKitSyncEngine.shared, observe published properties for UI updates,
//  and trigger manual syncs as needed.
//
//  Note:
//  -----
//  Actual CloudKit sync triggering APIs are app-specific and should be implemented where indicated.
//

import Foundation
import SwiftData
import CoreData
import Combine

// MARK: - Audit Context (set at login/session)
public struct CloudKitSyncAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "CloudKitSyncEngine"
}

@MainActor
public protocol AnalyticsLoggerProtocol {
    /// Indicates if the logger is in test/preview mode (console-only, no network).
    var testMode: Bool { get }

    /// Logs an event asynchronously with a message string and full audit context.
    /// - Parameters:
    ///   - event: The event message to log.
    ///   - role: Optional user/staff role for audit.
    ///   - staffID: Optional staff/user ID for audit.
    ///   - context: Optional business or UI context for audit.
    ///   - escalate: Set true if this is a critical/escalation event.
    func logEvent(_ event: String, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

@MainActor
public struct NullAnalyticsLogger: AnalyticsLoggerProtocol {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(_ event: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("[CloudKitSyncEngine][TEST MODE] \(event) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Manages and monitors the synchronization of the SwiftData model container with iCloud (CloudKit).
/// This service listens for CloudKit events and translates them into a user-friendly status
/// that can be displayed anywhere in the UI. It also provides retry logic, risk scoring,
/// audit logging, and accessibility support.
///
/// Usage:
/// - Observe published properties for UI binding.
/// - Trigger manual syncs via `triggerManualSync()`.
/// - Export audit logs and sync state via `exportJSON()`.
@MainActor
final class CloudKitSyncEngine: ObservableObject {
    // MARK: - Singleton
    
    /// Shared singleton instance of the CloudKitSyncEngine.
    static let shared = CloudKitSyncEngine()
    
    // MARK: - Published Properties for UI
    
    /// Indicates whether a sync operation is currently in progress.
    @Published private(set) var isSyncing: Bool = false
    
    /// The date of the last successful sync operation.
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        }
    }
    
    /// A localized, user-friendly message describing the current sync status.
    @Published private(set) var syncStatusMessage: String = NSLocalizedString("Initializing...", comment: "Initial sync status message")
    
    /// The last error message encountered during sync, if any.
    @Published private(set) var lastError: String?
    
    /// Array of badge tokens representing sync states or events for UI or analytics.
    @Published private(set) var syncBadgeTokens: [String] = []
    
    /// Indicates if the sync is considered stale (e.g., overdue).
    @Published private(set) var isSyncStale: Bool = false
    
    /// A risk score representing the health of the sync process.
    @Published private(set) var syncRiskScore: Int = 0
    
    /// Audit log of sync events and status changes with timestamps.
    @Published private(set) var auditLog: [String] = []

    /// Audit log with audit fields (role, staffID, context, escalate).
    @Published private(set) var auditLogWithAuditFields: [(date: Date, event: String, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let auditLogAuditFieldsQueue = DispatchQueue(label: "CloudKitSyncEngine.auditLogAuditFieldsQueue", attributes: .concurrent)
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    private let retryInterval: TimeInterval = 60    // Retry interval in seconds (1 minute)
    private var consecutiveErrorCount: Int = 0
    private let syncStaleThreshold: TimeInterval = 3600 * 8 // 8 hours stale threshold
    
    /// Thread-safe queue for audit log mutations.
    private let auditLogQueue = DispatchQueue(label: "CloudKitSyncEngine.auditLogQueue", attributes: .concurrent)
    
    /// Analytics logger instance.
    public var analyticsLogger: AnalyticsLoggerProtocol
    
    // MARK: - Initialization
    
    /// Initializes the sync engine.
    /// Listens for CloudKit sync events and restores last sync date from UserDefaults.
    /// - Parameter analyticsLogger: Optional analytics logger; defaults to NullAnalyticsLogger.
    private init(analyticsLogger: AnalyticsLoggerProtocol = NullAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        
        // Subscribe to CloudKit event notifications
        NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { await self?.handleEventNotification(notification) }
            }
            .store(in: &cancellables)
        
        // Audit app launch
        Task {
            await addAudit(NSLocalizedString("App launched, sync engine initialized.", comment: "Audit log entry for app launch"))
            await checkStaleSync()
        }
    }
    
    // MARK: - Event Handling
    
    /// Handles CloudKit event notifications, updating sync status, errors, badges, and audit logs.
    /// - Parameter notification: The notification containing sync event info.
    private func handleEventNotification(_ notification: Notification) async {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }

        let prevStatus = syncStatusMessage

        switch event.type {
        case .setup:
            syncStatusMessage = NSLocalizedString("Initializing Sync...", comment: "Sync setup status")
            isSyncing = true
            await addBadgeToken("setup")
            await addAudit(NSLocalizedString("Sync setup.", comment: "Audit log entry for sync setup"))

        case .import:
            if event.endDate == nil {
                syncStatusMessage = NSLocalizedString("Syncing changes from iCloud...", comment: "Sync import in progress")
                isSyncing = true
                await addAudit(NSLocalizedString("Import sync started.", comment: "Audit log entry for import sync start"))
            } else {
                syncStatusMessage = NSLocalizedString("Sync Complete", comment: "Sync import completed")
                isSyncing = false
                await addAudit(NSLocalizedString("Import sync ended.", comment: "Audit log entry for import sync end"))
            }
            await addBadgeToken("import")

        case .export:
            if event.endDate == nil {
                syncStatusMessage = NSLocalizedString("Uploading changes to iCloud...", comment: "Sync export in progress")
                isSyncing = true
                await addAudit(NSLocalizedString("Export sync started.", comment: "Audit log entry for export sync start"))
            } else {
                syncStatusMessage = NSLocalizedString("Sync Complete", comment: "Sync export completed")
                isSyncing = false
                await addAudit(NSLocalizedString("Export sync ended.", comment: "Audit log entry for export sync end"))
            }
            await addBadgeToken("export")

        @unknown default:
            syncStatusMessage = NSLocalizedString("An unknown sync event occurred.", comment: "Unknown sync event status")
            await addBadgeToken("unknown")
            await addAudit(NSLocalizedString("Unknown sync event.", comment: "Audit log entry for unknown sync event"))
        }

        if let endDate = event.endDate {
            lastSyncDate = endDate
            syncStatusMessage = NSLocalizedString("Up to date", comment: "Sync status when fully up to date")
            await addBadgeToken("success")
            consecutiveErrorCount = 0
            retryTimer?.invalidate()
        }

        if let error = event.error {
            lastError = error.localizedDescription
            syncStatusMessage = NSLocalizedString("Sync Error", comment: "Sync status when an error occurs")
            await addBadgeToken("error")
            await addAudit(String(format: NSLocalizedString("Sync error: %@", comment: "Audit log entry for sync error"), error.localizedDescription))
            consecutiveErrorCount += 1
            if consecutiveErrorCount >= 3 {
                syncStatusMessage = NSLocalizedString("Sync failed multiple times. Will retry automatically.", comment: "Sync status after multiple failures")
                await scheduleRetry()
            }
        } else {
            lastError = nil
            consecutiveErrorCount = 0
        }

        // Risk scoring for analytics/UI
        syncRiskScore = calculateRiskScore()
        await checkStaleSync()

        if prevStatus != syncStatusMessage {
            await addAudit(String(format: NSLocalizedString("Status changed to: %@", comment: "Audit log entry for status change"), syncStatusMessage))
        }
    }
    
    // MARK: - Retry Logic
    
    /// Schedules a retry of the sync operation after the configured retry interval.
    private func scheduleRetry() async {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { [weak self] _ in
            Task {
                await self?.triggerManualSync()
            }
        }
        await addAudit(String(format: NSLocalizedString("Scheduled sync retry in %d min.", comment: "Audit log entry for scheduled retry"), Int(retryInterval / 60)))
    }
    
    /// Triggers a manual sync operation.
    /// Actual sync call is app-specific; here it updates state and logs audit events.
    public func triggerManualSync() async {
        isSyncing = true
        syncStatusMessage = NSLocalizedString("Manual sync triggered.", comment: "Sync status when manual sync is triggered")
        await addBadgeToken("manual")
        await addAudit(NSLocalizedString("Manual sync triggered by user/system.", comment: "Audit log entry for manual sync trigger"))
        
        // In a real implementation, call NSPersistentCloudKitContainer/ModelContainer sync APIs here.
        try? await Task.sleep(nanoseconds: 2_000_000_000) // Simulate 2 seconds delay
        
        isSyncing = false
        syncStatusMessage = NSLocalizedString("Manual sync complete.", comment: "Sync status after manual sync completes")
        await addAudit(NSLocalizedString("Manual sync completed.", comment: "Audit log entry for manual sync completion"))
    }
    
    // MARK: - Analytics/Badges
    
    /// Adds a badge token if not already present.
    /// - Parameter token: The badge token to add.
    private func addBadgeToken(_ token: String) async {
        if !syncBadgeTokens.contains(token) {
            syncBadgeTokens.append(token)
            let event = "Badge token added: \(token)"
            let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            await analyticsLogger.logEvent(
                event,
                role: CloudKitSyncAuditContext.role,
                staffID: CloudKitSyncAuditContext.staffID,
                context: CloudKitSyncAuditContext.context,
                escalate: escalate
            )
            auditLogAuditFieldsQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.auditLogWithAuditFields.append((date: Date(), event: event, role: CloudKitSyncAuditContext.role, staffID: CloudKitSyncAuditContext.staffID, context: CloudKitSyncAuditContext.context, escalate: escalate))
                if self.auditLogWithAuditFields.count > 1000 {
                    self.auditLogWithAuditFields.removeFirst(self.auditLogWithAuditFields.count - 1000)
                }
            }
        }
    }

    /// Removes a badge token if present.
    /// - Parameter token: The badge token to remove.
    private func removeBadgeToken(_ token: String) async {
        if syncBadgeTokens.contains(token) {
            syncBadgeTokens.removeAll { $0 == token }
            let event = "Badge token removed: \(token)"
            let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            await analyticsLogger.logEvent(
                event,
                role: CloudKitSyncAuditContext.role,
                staffID: CloudKitSyncAuditContext.staffID,
                context: CloudKitSyncAuditContext.context,
                escalate: escalate
            )
            auditLogAuditFieldsQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.auditLogWithAuditFields.append((date: Date(), event: event, role: CloudKitSyncAuditContext.role, staffID: CloudKitSyncAuditContext.staffID, context: CloudKitSyncAuditContext.context, escalate: escalate))
                if self.auditLogWithAuditFields.count > 1000 {
                    self.auditLogWithAuditFields.removeFirst(self.auditLogWithAuditFields.count - 1000)
                }
            }
        }
    }
    
    /// Calculates a risk score based on error presence, staleness, and consecutive errors.
    /// - Returns: An integer risk score.
    private func calculateRiskScore() -> Int {
        var score = 0
        if lastError != nil { score += 2 }
        if isSyncStale { score += 1 }
        if consecutiveErrorCount > 0 { score += 1 }
        return score
    }
    
    /// Checks if the sync is stale based on the last sync date and threshold.
    private func checkStaleSync() async {
        if let last = lastSyncDate, Date().timeIntervalSince(last) > syncStaleThreshold {
            if !isSyncStale {
                isSyncStale = true
                await addBadgeToken("stale")
                syncStatusMessage = NSLocalizedString("Sync overdue!", comment: "Sync status when overdue/stale")
                await addAudit(NSLocalizedString("Sync is stale/overdue.", comment: "Audit log entry for stale sync"))
            }
        } else {
            if isSyncStale {
                isSyncStale = false
                await removeBadgeToken("stale")
            }
        }
    }
    
    // MARK: - Audit / Export
    
    /// Adds an entry to the audit log with a timestamp.
    /// The audit log is capped at 1000 entries and thread-safe.
    /// - Parameter entry: The audit log entry string.
    public func addAudit(_ entry: String) async {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let logEntry = "[\(timestamp)] \(entry)"
        let escalate = entry.lowercased().contains("danger") || entry.lowercased().contains("critical") || entry.lowercased().contains("delete")
        await analyticsLogger.logEvent(
            logEntry,
            role: CloudKitSyncAuditContext.role,
            staffID: CloudKitSyncAuditContext.staffID,
            context: CloudKitSyncAuditContext.context,
            escalate: escalate
        )

        auditLogQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.auditLog.append(logEntry)
            if self.auditLog.count > 1000 {
                self.auditLog.removeFirst(self.auditLog.count - 1000)
            }
        }
        auditLogAuditFieldsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.auditLogWithAuditFields.append((date: Date(), event: entry, role: CloudKitSyncAuditContext.role, staffID: CloudKitSyncAuditContext.staffID, context: CloudKitSyncAuditContext.context, escalate: escalate))
            if self.auditLogWithAuditFields.count > 1000 {
                self.auditLogWithAuditFields.removeFirst(self.auditLogWithAuditFields.count - 1000)
            }
        }
    }
    
    /// Exports the current sync state and audit log as a JSON string.
    /// - Returns: JSON string representing the export, or nil if encoding fails.
    public func exportJSON() -> String? {
        struct Export: Codable {
            let lastSyncDate: Date?
            let syncBadgeTokens: [String]
            let isSyncing: Bool
            let isSyncStale: Bool
            let riskScore: Int
            let lastError: String?
            let auditLog: [String]
        }
        
        var currentAuditLog: [String] = []
        auditLogQueue.sync {
            currentAuditLog = self.auditLog
        }
        
        let export = Export(
            lastSyncDate: lastSyncDate,
            syncBadgeTokens: syncBadgeTokens,
            isSyncing: isSyncing,
            isSyncStale: isSyncStale,
            riskScore: syncRiskScore,
            lastError: lastError,
            auditLog: currentAuditLog
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(export),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label summarizing sync status, last sync date, risk score, and error presence.
    public var accessibilityLabel: String {
        let lastSyncString = lastSyncDate.map {
            DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
        } ?? NSLocalizedString("Never", comment: "Accessibility label for no last sync date")
        
        let errorString = lastError != nil
            ? NSLocalizedString("Sync error.", comment: "Accessibility label for sync error present")
            : ""
        
        return String(format: NSLocalizedString("Cloud sync status: %@. Last sync: %@. Risk score: %d. %@", comment: "Accessibility label for cloud sync status"), syncStatusMessage, lastSyncString, syncRiskScore, errorString)
    }
}

// MARK: - PreviewProvider

#if DEBUG
import SwiftUI

/// A SwiftUI preview demonstrating the sync status component with accessibility and diagnostics.
struct CloudKitSyncEngine_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("Sync Status Component Demo", comment: "Preview title"))
                .font(.title2)
            
            SyncStatusView()
                .padding(16)
                .background(Color(UIColor.systemBackground).opacity(0.8))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(CloudKitSyncEngine.shared.accessibilityLabel)
            
            Text(NSLocalizedString("Audit Log (Last 5 entries):", comment: "Audit log preview title"))
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(CloudKitSyncEngine.shared.auditLogWithAuditFields.suffix(5).enumerated()), id: \.offset) { _, entry in
                        let (date, event, role, staffID, context, escalate) = entry
                        HStack(alignment: .top, spacing: 4) {
                            Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    Text("role: \(role ?? "-")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("staffID: \(staffID ?? "-")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("context: \(context ?? "-")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("escalate: \(escalate ? "YES" : "NO")")
                                        .font(.caption2)
                                        .foregroundColor(escalate ? .red : .secondary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(16)
        .onAppear {
            // For preview, inject test analytics logger
            CloudKitSyncEngine.shared.analyticsLogger = NullAnalyticsLogger()
        }
    }
}
#endif
