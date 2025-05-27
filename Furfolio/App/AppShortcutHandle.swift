
//
//  AppShortcutHandle.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import UIKit
import Foundation

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

  /// Registers the supported Home Screen Quick Actions with the system.
  static func registerShortcuts() {
        let addOwner = UIApplicationShortcutItem(
            type: AppShortcutType.addOwner.rawValue,
            localizedTitle: "Add Owner",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "person.badge.plus"),
            userInfo: nil
        )
        let addAppointment = UIApplicationShortcutItem(
            type: AppShortcutType.addAppointment.rawValue,
            localizedTitle: "Add Appointment",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.plus"),
            userInfo: nil
        )
        let addCharge = UIApplicationShortcutItem(
            type: AppShortcutType.addCharge.rawValue,
            localizedTitle: "Add Charge",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "dollarsign.circle"),
            userInfo: nil
        )
        UIApplication.shared.shortcutItems = [addOwner, addAppointment, addCharge]
    }

  /// Handles a selected quick action by posting the corresponding notification.
  /// - Parameter shortcutItem: The shortcut item triggered by the system.
  /// - Returns: `true` if the shortcut was recognized and handled.
  @discardableResult
  static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let shortcutType = AppShortcutType(rawValue: shortcutItem.type) else {
            return false
        }
        switch shortcutType {
        case .addOwner:
            NotificationCenter.default.post(name: .shortcutAddOwner, object: nil)
        case .addAppointment:
            NotificationCenter.default.post(name: .shortcutAddAppointment, object: nil)
        case .addCharge:
            NotificationCenter.default.post(name: .shortcutAddCharge, object: nil)
        }
        return true
    }
  /// Removes all registered quick actions.
  static func clearShortcuts() {
    UIApplication.shared.shortcutItems = []
  }
}

