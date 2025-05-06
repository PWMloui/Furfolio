//
//  FurfolioApp.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Model Container Holder

/// A reference type that holds the shared ModelContainer.
/// This allows us to store the model container in an observable object,
/// so that our App struct (a value type) doesn't need to provide a mutating getter.
class ModelContainerHolder: ObservableObject {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = try Schema([DogOwner.self, Charge.self, Appointment.self, DailyRevenue.self])
            self.modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
}

// MARK: - ActiveSheet Enum

/// Enum to control which modal sheet is shown.
enum ActiveSheet: Identifiable {
    case addOwner
    case metricsDashboard
    
    var id: Int { hashValue }
}

// MARK: - FurfolioApp

@main
struct FurfolioApp: App {
    // Use a StateObject to hold the model container holder.
    @StateObject private var containerHolder = ModelContainerHolder()
    
    // New state to drive modal presentation.
    @State private var activeSheet: ActiveSheet? = nil

    init() {
        configureNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(containerHolder.modelContainer) // Pass the model container from the holder
                // Listen for shortcut notifications and update the activeSheet state accordingly.
                .onReceive(NotificationCenter.default.publisher(for: .addDogOwnerShortcut)) { _ in
                    activeSheet = .addOwner
                    print("Add Dog Owner shortcut triggered, presenting AddOwnerView")
                }
                .onReceive(NotificationCenter.default.publisher(for: .viewMetricsShortcut)) { _ in
                    activeSheet = .metricsDashboard
                    print("View Metrics Dashboard shortcut triggered, presenting MetricsDashboardView")
                }
                // Present the appropriate sheet based on activeSheet.
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .addOwner:
                        // Let AddDogOwnerView handle insertion using its own @Environment(\.modelContext)
                        AddDogOwnerView { ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, birthdate in
                            // In this closure you can perform any additional actions (if needed).
                            // The actual insertion of the new DogOwner should be done inside AddDogOwnerView using its modelContext.
                            print("New owner information received: \(ownerName), \(dogName), etc.")
                        }
                    case .metricsDashboard:
                        MetricsDashboardView(
                            dailyRevenues: [],
                            appointments: [],
                            charges: []
                        )
                    }
                }
        }
        .commands {
            // Add App Commands for Quick Actions
            CommandMenu("Shortcuts") {
                Button("Add New Dog Owner") {
                    NotificationCenter.default.post(name: .addDogOwnerShortcut, object: nil)
                    print("Add Dog Owner shortcut triggered")
                }
                .keyboardShortcut("N", modifiers: [.command])
                
                Button("View Metrics Dashboard") {
                    NotificationCenter.default.post(name: .viewMetricsShortcut, object: nil)
                    print("View Metrics Dashboard shortcut triggered")
                }
                .keyboardShortcut("M", modifiers: [.command])
            }
        }
    }
    
    // MARK: - Notification Configuration
    
    /// Configures notification settings and delegates.
    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate()
        requestNotificationPermissions()
    }
    
    /// Requests notification permissions from the user and logs the result.
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission request failed: \(error.localizedDescription)")
                } else {
                    print(granted ? "Notification permission granted." : "Notification permission denied.")
                }
            }
        }
    }
    
    // MARK: - Shortcut Handlers
    
    /// Handles the "Add Dog Owner" shortcut action by posting a corresponding notification.
    private func handleAddDogOwnerShortcut() {
        // In the updated version, this handler posts a notification,
        // which is then caught by the .onReceive modifier to set activeSheet.
        NotificationCenter.default.post(name: .showAddOwnerSheet, object: nil)
        print("Posted showAddOwnerSheet notification")
    }
    
    /// Handles the "View Metrics Dashboard" shortcut action by posting a corresponding notification.
    private func handleViewMetricsShortcut() {
        NotificationCenter.default.post(name: .showMetricsDashboard, object: nil)
        print("Posted showMetricsDashboard notification")
    }
}

// MARK: - Notification Delegate

/// Custom delegate for handling notification events.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Called when a notification is about to be presented while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("Notification will be presented: \(notification.request.content.body)")
        completionHandler([.alert, .sound])
    }
    
    /// Called when the user interacts with a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("Notification received: \(response.notification.request.content.body)")
        completionHandler()
    }
}

// MARK: - Notification Names Extension

/// Extend `Notification.Name` with app-specific events.
extension Notification.Name {
    static let addDogOwnerShortcut = Notification.Name("addDogOwnerShortcut")
    static let viewMetricsShortcut = Notification.Name("viewMetricsShortcut")
    static let showAddOwnerSheet = Notification.Name("showAddOwnerSheet")
    static let showMetricsDashboard = Notification.Name("showMetricsDashboard")
}
