//
//  NotificationManager.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//

import SwiftUI
import SwiftData
import UserNotifications
import os


// MARK: - Model Container Holder

/// Holds and initializes the shared SwiftData ModelContainer, with fallback for corrupted stores.
class ModelContainerHolder: ObservableObject {
    let modelContainer: ModelContainer
    
    init() {
        // Register secure unarchive transformer to avoid deprecation warnings
        ValueTransformer.setValueTransformer(
            NSSecureUnarchiveFromDataTransformer(),
            forName: NSValueTransformerName("NSSecureUnarchiveFromData")
        )

        do {
            let schema = try Schema([DogOwner.self, Charge.self, Appointment.self, DailyRevenue.self])
            self.modelContainer = try ModelContainer(for: schema)
        } catch {
            print("⚠️ ModelContainer initialization failed. This might be caused by corrupted data or schema changes.")
            print("Error: \(error)")

            // Fallback for development: in-memory configuration to avoid crash
            do {
                let schema = try Schema([DogOwner.self, Charge.self, Appointment.self, DailyRevenue.self])
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                self.modelContainer = try ModelContainer(for: schema, configurations: [config])
                print("✅ Loaded fallback in-memory model container")
            } catch {
                fatalError("❌ Failed fallback initialization: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ActiveSheet Enum

/// Identifies which modal sheet is currently presented in the app.
enum ActiveSheet: Identifiable {
    case addOwner
    case metricsDashboard
    
    var id: Int { hashValue }
}

// MARK: - FurfolioApp

/// The main application entry point, wiring up the model container and root ContentView.
@main
/// Configures global state: model container, notifications, and keyboard shortcuts.
struct FurfolioApp: App {
    // Use a StateObject to hold the model container holder.
    @StateObject private var containerHolder = ModelContainerHolder()
    
    // New state to drive modal presentation.
    @State private var activeSheet: ActiveSheet? = nil

    /// Initializes the app, setting up notifications and services.
    init() {
      // Configure push and local notifications
      NotificationManager.shared.configure()
    }

    var body: some Scene {
      WindowGroup {
        ContentView()
          .modelContainer(containerHolder.modelContainer)
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
              AddDogOwnerView { ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, birthdate in
                print("New owner information received: \(ownerName), \(dogName), etc.")
              }
            case .metricsDashboard:
              NavigationStack {
                MetricsDashboardView(
                  dailyRevenues: try! containerHolder.modelContainer.mainContext.fetch(FetchDescriptor<DailyRevenue>()),
                  appointments: try! containerHolder.modelContainer.mainContext.fetch(FetchDescriptor<Appointment>()),
                  charges: try! containerHolder.modelContainer.mainContext.fetch(FetchDescriptor<Charge>())
                )
                .navigationTitle("Dashboard Insights")
                .toolbar {
                  ToolbarItem(placement: .status) {
                    VStack(alignment: .trailing) {
                      Text("🏆 Loyalty Active")
                        .font(.caption2)
                      Text("🧠 Behavior Tracking On")
                        .font(.caption2)
                    }
                  }
                }
              }
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
    
}

// MARK: - Notification Names Extension

/// Extend `Notification.Name` with app-specific events.
extension Notification.Name {
    static let addDogOwnerShortcut = Notification.Name("addDogOwnerShortcut")
    static let viewMetricsShortcut = Notification.Name("viewMetricsShortcut")
    static let showAddOwnerSheet = Notification.Name("showAddOwnerSheet")
    static let showMetricsDashboard = Notification.Name("showMetricsDashboard")
}


/// Centralized service for UNUserNotificationCenter configuration and shortcut notifications.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationManager()
  
  private override init() {
    super.init()
  }
  
  /// Configures the notification center delegate and requests permissions.
  func configure() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    requestPermissions()
  }
  
  /// Requests alert, badge, and sound permissions.
  private func requestPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let err = error {
          print("Error:", err.localizedDescription)
        } else {
          print("Notification permission \(granted ? "granted" : "denied")")
        }
      }
    }
  }
  
  // MARK: UNUserNotificationCenterDelegate
  
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
