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
import FirebaseRemoteConfigService
import ReminderScheduler

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "NotificationManager")

    /// Default lead time (minutes) for notifications from Remote Config.
    private static var defaultLeadMinutes: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .notificationLeadTime)
    }

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


/// Represents which modal sheet to present.
enum ActiveSheet: Identifiable {
    case addOwner
    case metricsDashboard
    case addAppointment
    case addCharge

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
            NotificationManager.shared.logger.log("Add Dog Owner shortcut triggered, presenting AddOwnerView")
          }
          .onReceive(NotificationCenter.default.publisher(for: .viewMetricsShortcut)) { _ in
            activeSheet = .metricsDashboard
            NotificationManager.shared.logger.log("View Metrics Dashboard shortcut triggered, presenting MetricsDashboardView")
          }
          // Present the appropriate sheet based on activeSheet.
          .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addOwner:
              AddDogOwnerView { ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, birthdate in
                NotificationManager.shared.logger.log("New owner information received: \(ownerName), \(dogName), etc.")
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
            case .addAppointment:
              AddAppointmentView()
            case .addCharge:
              AddChargeView()
            @unknown default:
              break
            }
          }
      }
      .commands {
        // Add App Commands for Quick Actions
        CommandMenu("Shortcuts") {
          Button("Add New Dog Owner") {
            NotificationCenter.default.post(name: .addDogOwnerShortcut, object: nil)
            NotificationManager.shared.logger.log("Add Dog Owner shortcut triggered")
          }
          .keyboardShortcut("N", modifiers: [.command])
          
          Button("View Metrics Dashboard") {
            NotificationCenter.default.post(name: .viewMetricsShortcut, object: nil)
            NotificationManager.shared.logger.log("View Metrics Dashboard shortcut triggered")
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
  
  public let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "NotificationManager")
  
  private override init() {
    super.init()
  }
  
  /// Configures the notification center delegate and requests permissions.
  func configure() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    logger.log("Notification center delegate configured")
    requestPermissions()
    logger.log("NotificationManager configured with defaultLeadMinutes: \(Self.defaultLeadMinutes)")
  }
  
  /// Requests alert, badge, and sound permissions.
  private func requestPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let err = error {
          self.logger.error("Permission request failed: \(err.localizedDescription)")
        } else {
          self.logger.log("Notification permission \(granted ? "granted" : "denied")")
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
    logger.log("Notification response received: \(response.notification.request.identifier)")
    NotificationCenter.default.post(name: .didReceiveNotificationResponse, object: response)
    logger.log("Notification action: \(response.actionIdentifier) for \(response.notification.request.identifier)")
    completionHandler()
  }
  
  /// Schedules a local notification through ReminderScheduler.
  ///
  /// - Parameters:
  ///   - id: Unique identifier for the notification.
  ///   - title: Notification title.
  ///   - body: Notification body text.
  ///   - date: Optional fire date. If nil, will schedule notification with default lead time from Remote Config.
  func scheduleReminder(id: String, title: String, body: String, date: Date? = nil) {
      let fireDate = date ?? Calendar.current.date(byAdding: .minute,
          value: -Self.defaultLeadMinutes,
          to: Date())!
      logger.log("Scheduling local notification \(id) at \(fireDate) (computed lead time: \(Self.defaultLeadMinutes) min)")
      ReminderScheduler.shared.scheduleReminder(id: id, date: fireDate, title: title, body: body)
  }

  /// Cancels a scheduled local notification.
  ///
  /// Also forwards cancellation event to Firebase Analytics.
  ///
  /// - Parameter id: Unique identifier for the notification to cancel.
  func cancelReminder(id: String) {
      logger.log("Cancelling local notification \(id)")
      ReminderScheduler.shared.cancelReminder(id: id)
      logger.log("Also forwarding cancel to Firebase analytics")
      // Example analytics hook
      Analytics.logEvent("notification_cancelled", parameters: ["id": id])
  }
}

extension Notification.Name {
    static let didReceiveNotificationResponse = Notification.Name("didReceiveNotificationResponse")
}
