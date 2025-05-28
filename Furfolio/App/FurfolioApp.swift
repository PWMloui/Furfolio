//
//  FurfolioApp.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import UIKit
import AppShortcutHandler

@main
struct FurfolioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingFlowManager()
    @Environment(\.scenePhase) private var scenePhase
    let persistenceController = PersistenceController.shared

    init() {
        // Request notification permissions
        NotificationManager.shared.requestAuthorization()
        // Remove direct seeding; will seed in onAppear
    }

    var body: some Scene {
        WindowGroup {
            Group {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(onboardingManager)
                    .environment(\.modelContext, persistenceController.container.viewContext)
            }
            .onAppear {
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
                ServiceSeeder.seed(into: persistenceController.container.viewContext)
            }
            .onOpenURL { url in
                appState.handleDeepLink(url)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                AppShortcutHandler.registerShortcuts(
                    hasOwners: appState.hasOwners,
                    hasAppointments: appState.hasAppointments
                )
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                persistenceController.save()
            }
        }
    }
}
