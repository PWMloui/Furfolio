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

@main
struct FurfolioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingFlowManager()
    @Environment(\.scenePhase) private var scenePhase
    let persistenceController = PersistenceController.shared

    init() {
        // Request notification permissions
        NotificationManager.shared.requestAuthorization()
        AppShortcutHandler.startListening()
        // Reschedule any pending reminders on app launch
        ReminderScheduler.shared.cancelAllReminders()
        appState.rescheduleReminders()
        FirebaseRemoteConfigService.shared.fetchAndActivate { success, error in
            if let error = error {
                print("🔴 RemoteConfig error: \(error)")
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
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
                Task {
                    do {
                        try await ServiceSeeder.shared.seed(into: persistenceController.container.viewContext)
                    } catch {
                        print("🔴 ServiceSeeder failed: \(error)")
                    }
                }
            }
            .onOpenURL { url in
                appState.handleDeepLink(url)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Refresh remote config and reschedule reminders when becoming active
                FirebaseRemoteConfigService.shared.fetchAndActivate()
                ReminderScheduler.shared.cancelAllReminders()
                appState.rescheduleReminders()
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
            case .background:
                persistenceController.save()
            default:
                break
            }
        }
    }
}
