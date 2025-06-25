//
//  CloudKitSyncEngine.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A dedicated service to manage and monitor SwiftData's
//  CloudKit synchronization, providing UI-bindable state for the app.
//

import Foundation
import SwiftData
import CoreData
import Combine

/// Manages and monitors the synchronization of the SwiftData model container with iCloud (CloudKit).
/// This service listens for CloudKit events and translates them into a user-friendly status
/// that can be displayed anywhere in the UI.
@MainActor
final class CloudKitSyncEngine: ObservableObject {
    // MARK: - Singleton
    static let shared = CloudKitSyncEngine()

    // MARK: - Published Properties for UI
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? {
        didSet { UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate") }
    }
    @Published var syncStatusMessage: String = "Initializing..."
    @Published var lastError: String?
    @Published var syncBadgeTokens: [String] = []   // Tokenized for UI/analytics
    @Published var isSyncStale: Bool = false
    @Published var syncRiskScore: Int = 0
    @Published var auditLog: [String] = []          // Persistent sync event/audit trail

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    private let retryInterval: TimeInterval = 60    // 1 minute
    private var consecutiveErrorCount: Int = 0
    private let syncStaleThreshold: TimeInterval = 3600 * 8 // 8 hours

    // MARK: - Initialization
    private init() {
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        // Listen to CloudKit events
        NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleEventNotification(notification)
            }
            .store(in: &cancellables)
        // Audit app launch
        addAudit("App launched, sync engine initialized.")
        checkStaleSync()
    }

    // MARK: - Event Handling
    private func handleEventNotification(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        let prevStatus = syncStatusMessage
        switch event.type {
        case .setup:
            syncStatusMessage = "Initializing Sync..."
            isSyncing = true
            addBadgeToken("setup")
            addAudit("Sync setup.")
        case .import:
            syncStatusMessage = event.endDate == nil ? "Syncing changes from iCloud..." : "Sync Complete"
            isSyncing = event.endDate == nil
            addBadgeToken("import")
            addAudit("Import sync \(event.endDate == nil ? "started" : "ended").")
        case .export:
            syncStatusMessage = event.endDate == nil ? "Uploading changes to iCloud..." : "Sync Complete"
            isSyncing = event.endDate == nil
            addBadgeToken("export")
            addAudit("Export sync \(event.endDate == nil ? "started" : "ended").")
        @unknown default:
            syncStatusMessage = "An unknown sync event occurred."
            addBadgeToken("unknown")
            addAudit("Unknown sync event.")
        }
        if let endDate = event.endDate {
            lastSyncDate = endDate
            syncStatusMessage = "Up to date"
            addBadgeToken("success")
            consecutiveErrorCount = 0
            retryTimer?.invalidate()
        }
        if let error = event.error {
            lastError = error.localizedDescription
            syncStatusMessage = "Sync Error"
            addBadgeToken("error")
            addAudit("Sync error: \(error.localizedDescription)")
            consecutiveErrorCount += 1
            if consecutiveErrorCount >= 3 {
                syncStatusMessage = "Sync failed multiple times. Will retry automatically."
                scheduleRetry()
            }
        } else {
            lastError = nil
            consecutiveErrorCount = 0
        }
        // Risk scoring for analytics/UI
        syncRiskScore = calculateRiskScore()
        checkStaleSync()
        if prevStatus != syncStatusMessage {
            addAudit("Status changed to: \(syncStatusMessage)")
        }
    }

    // MARK: - Retry Logic
    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { [weak self] _ in
            self?.triggerManualSync()
        }
        addAudit("Scheduled sync retry in \(Int(retryInterval/60)) min.")
    }
    public func triggerManualSync() {
        // Actual sync call is app-specific; here we simply log/audit
        isSyncing = true
        syncStatusMessage = "Manual sync triggered."
        addBadgeToken("manual")
        addAudit("Manual sync triggered by user/system.")
        // In a real implementation, call NSPersistentCloudKitContainer/ModelContainer sync APIs here.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isSyncing = false
            self.syncStatusMessage = "Manual sync complete."
            self.addAudit("Manual sync completed.")
        }
    }

    // MARK: - Analytics/Badges
    private func addBadgeToken(_ token: String) {
        if !syncBadgeTokens.contains(token) { syncBadgeTokens.append(token) }
    }
    private func removeBadgeToken(_ token: String) {
        syncBadgeTokens.removeAll { $0 == token }
    }
    private func calculateRiskScore() -> Int {
        var score = 0
        if lastError != nil { score += 2 }
        if isSyncStale { score += 1 }
        if consecutiveErrorCount > 0 { score += 1 }
        return score
    }
    private func checkStaleSync() {
        if let last = lastSyncDate, Date().timeIntervalSince(last) > syncStaleThreshold {
            isSyncStale = true
            addBadgeToken("stale")
            syncStatusMessage = "Sync overdue!"
            addAudit("Sync is stale/overdue.")
        } else {
            isSyncStale = false
            removeBadgeToken("stale")
        }
    }

    // MARK: - Audit/Export
    public func addAudit(_ entry: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(ts)] \(entry)")
        if auditLog.count > 1000 { auditLog.removeFirst() }
        // For persistence: write to disk/db if needed.
    }
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
        let export = Export(
            lastSyncDate: lastSyncDate,
            syncBadgeTokens: syncBadgeTokens,
            isSyncing: isSyncing,
            isSyncStale: isSyncStale,
            riskScore: syncRiskScore,
            lastError: lastError,
            auditLog: auditLog
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }
    // MARK: - Accessibility
    public var accessibilityLabel: String {
        "Cloud sync status: \(syncStatusMessage). Last sync: \(lastSyncDate.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Never"). Risk score: \(syncRiskScore). \(lastError != nil ? "Sync error." : "")"
    }
}
// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.medium) {
        Text("Sync Status Component Demo")
            .font(AppFonts.title2)
        
        SyncStatusView()
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
    }
    .padding(AppSpacing.medium)
}
