//
//  AppShortcutHandle.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import UIKit
import Foundation
import os

/// Quick action identifiers for Home Screen shortcuts.
enum AppShortcutType: String {
    case addOwner = "com.furfolio.addOwner"
    case addAppointment = "com.furfolio.addAppointment"
    case addCharge = "com.furfolio.addCharge"
}

/// Notification names posted when a quick action is triggered.
extension Notification.Name {
    static let shortcutAddOwner = Notification.Name("shortcutAddOwner")
    static let shortcutAddAppointment = Notification.Name("shortcutAddAppointment")
    static let shortcutAddCharge = Notification.Name("shortcutAddCharge")
}

/// Manages registration and handling of Home Screen Quick Actions.
final class AppShortcutHandler {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppShortcutHandler")

    /// Holds the observer token for foreground notifications.
    private static var foregroundObserver: NSObjectProtocol?

  /// Registers the supported Home Screen Quick Actions with the system.
  static func registerShortcuts(hasOwners: Bool, hasAppointments: Bool) {
        logger.log("Registering quick actions; hasOwners=\(hasOwners), hasAppointments=\(hasAppointments)")
        let addOwner = UIApplicationShortcutItem(
            type: AppShortcutType.addOwner.rawValue,
            localizedTitle: NSLocalizedString("Add Owner", comment: "Home screen shortcut to add a new owner"),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "person.badge.plus"),
            userInfo: nil
        )
        let addAppointment = UIApplicationShortcutItem(
            type: AppShortcutType.addAppointment.rawValue,
            localizedTitle: NSLocalizedString("Add Appointment", comment: "Home screen shortcut to add a new appointment"),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.plus"),
            userInfo: nil
        )
        let addCharge = UIApplicationShortcutItem(
            type: AppShortcutType.addCharge.rawValue,
            localizedTitle: NSLocalizedString("Add Charge", comment: "Home screen shortcut to add a new charge"),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "dollarsign.circle"),
            userInfo: nil
        )
        var items: [UIApplicationShortcutItem] = []
        items.append(addOwner)
        if hasOwners { items.append(addAppointment) }
        if hasAppointments { items.append(addCharge) }
        logger.log("Will set shortcutItems: \(items.map { $0.type })")
        UIApplication.shared.shortcutItems = items
    }

  /// Handles a selected quick action by posting the corresponding notification.
  /// - Parameter shortcutItem: The shortcut item triggered by the system.
  /// - Returns: `true` if the shortcut was recognized and handled.
  @discardableResult
  static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        logger.log("Handling shortcut: \(shortcutItem.type)")
        guard let shortcutType = AppShortcutType(rawValue: shortcutItem.type) else {
            return false
        }
        switch shortcutType {
        case .addOwner:
            logger.log("Posting notification for shortcut: \(shortcutType.rawValue)")
            NotificationCenter.default.post(name: .shortcutAddOwner, object: nil)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .addAppointment:
            logger.log("Posting notification for shortcut: \(shortcutType.rawValue)")
            NotificationCenter.default.post(name: .shortcutAddAppointment, object: nil)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .addCharge:
            logger.log("Posting notification for shortcut: \(shortcutType.rawValue)")
            NotificationCenter.default.post(name: .shortcutAddCharge, object: nil)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        return true
    }
  /// Removes all registered quick actions.
  static func clearShortcuts() {
        logger.log("Clearing all quick actions")
    UIApplication.shared.shortcutItems = []
    stopListening()
  }

    /// Stops listening for foreground notifications.
    static func stopListening() {
        logger.log("Stopping quick action listening")
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

  /// Starts listening for app foreground notifications to refresh shortcuts dynamically.
  static func startListening() {
        logger.log("Starting quick action listening")
    foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            logger.log("Will refresh shortcuts on foreground")
        // TODO: Replace these placeholders with your actual logic to determine if owners and appointments exist.
        let hasOwners = YourDataService.hasOwners
        let hasAppointments = YourDataService.hasAppointments
        registerShortcuts(hasOwners: hasOwners, hasAppointments: hasAppointments)
    }
  }
}

// Note: Call `AppShortcutHandler.startListening()` from your app's entry point, e.g., in `FurfolioApp.swift` init method.
