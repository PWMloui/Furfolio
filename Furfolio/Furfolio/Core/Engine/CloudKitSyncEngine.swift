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
    
    /// True if a sync operation (import or export) is currently in progress.
    @Published var isSyncing: Bool = false
    
    /// The date of the last successful sync operation. Persisted in UserDefaults.
    @Published var lastSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        }
    }
    
    /// A human-readable status message for the UI (e.g., "Syncing...", "Up to date").
    @Published var syncStatusMessage: String = "Initializing..."
    
    /// The last error that occurred during a sync operation, if any.
    @Published var lastError: String?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern. Sets up the event listener.
    private init() {
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        
        // The key to monitoring CloudKit sync is to observe the container's event stream.
        NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleEventNotification(notification)
            }
            .store(in: &cancellables)
    }

    // MARK: - Event Handling
    
    /// Handles incoming CloudKit event notifications and updates the published state.
    private func handleEventNotification(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }

        switch event.type {
        case .setup:
            syncStatusMessage = "Initializing Sync..."
            isSyncing = true
        case .import:
            syncStatusMessage = event.endDate == nil ? "Syncing changes from iCloud..." : "Sync Complete"
            isSyncing = event.endDate == nil
        case .export:
            syncStatusMessage = event.endDate == nil ? "Uploading changes to iCloud..." : "Sync Complete"
            isSyncing = event.endDate == nil
        @unknown default:
            syncStatusMessage = "An unknown sync event occurred."
        }
        
        if let endDate = event.endDate {
            lastSyncDate = endDate
            syncStatusMessage = "Up to date"
        }
        
        if event.error != nil {
            lastError = event.error?.localizedDescription
            syncStatusMessage = "Sync Error"
        } else {
            lastError = nil
        }
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
