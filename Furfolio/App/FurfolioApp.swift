//
//  FurfolioApp.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import UIKit
import AppShortcutHandler
import FirebaseRemoteConfigService
import ReminderScheduler
import os

@main
struct FurfolioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingFlowManager()
    @Environment(\.scenePhase) private var scenePhase
    let persistenceController = PersistenceController.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FurfolioApp")

    init() {
        // Request notification permissions
        logger.log("App init: requesting notification authorization")
        NotificationManager.shared.requestAuthorization()
        logger.log("App init: starting shortcut listening")
        AppShortcutHandler.startListening()
        logger.log("App init: cancelling all scheduled reminders and rescheduling")
        ReminderScheduler.shared.cancelAllReminders()
        appState.rescheduleReminders()
        logger.log("App init: fetching Remote Config")
        FirebaseRemoteConfigService.shared.fetchAndActivate { success, error in
            if let error = error {
                self.logger.error("RemoteConfig fetch error: \(error.localizedDescription)")
            } else {
                self.logger.log("RemoteConfig fetch and activate success: \(success)")
            }
        }
        // Remove direct seeding; will seed in onAppear
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingManager.isFirstLaunch {
                    OnboardingView()
                        .environmentObject(onboardingManager)
                } else {
                    ContentView()
                        .environmentObject(appState)
                        .environment(\.modelContext, persistenceController.container.viewContext)
                }
            }
            .onAppear {
                logger.log("WindowGroup onAppear: registering shortcuts and seeding services")
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
                Task {
                    do {
                        try await ServiceSeeder.shared.seed(into: persistenceController.container.viewContext)
                    } catch {
                        logger.error("ServiceSeeder failed: \(error.localizedDescription)")
                    }
                }
            }
            .onOpenURL { url in
                logger.log("Received deep link URL: \(url.absoluteString)")
                appState.handleDeepLink(url)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            logger.log("Scene phase changed to: \(newPhase)")
            switch newPhase {
            case .active:
                logger.log("Scene active: refreshing Remote Config and reminders, re-registering shortcuts")
                // Refresh remote config and reschedule reminders when becoming active
                FirebaseRemoteConfigService.shared.fetchAndActivate()
                ReminderScheduler.shared.cancelAllReminders()
                appState.rescheduleReminders()
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
            case .background:
                logger.log("Scene background: saving persistence context")
                persistenceController.save()
            default:
                break
            }
        }
    }
}
