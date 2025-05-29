//
//  AppState.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import Combine
import UIKit
import SwiftData
import YourDataService
import os

enum ActiveSheet: Identifiable {
  case addOwner, addAppointment, addCharge
  case metricsDashboard
  var id: Int { hashValue }
}

/// Global application state and quick-action handlers.
final class AppState: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppState")
  /// Shared singleton instance.
  static let shared = AppState()

  /// Controls presentation of the active sheet.
  @Published var activeSheet: ActiveSheet?
  /// Indicates whether the user is authenticated.
  @Published var isAuthenticated: Bool = false
  /// Number of visits required to earn a loyalty reward.
  @Published var loyaltyThreshold: Int {
    didSet {
      UserDefaults.standard.set(loyaltyThreshold, forKey: "loyaltyThreshold")
    }
  }

  private var cancellables = Set<AnyCancellable>()

  /// Sets up NotificationCenter publishers for home-screen quick actions.
  private func registerQuickActionSubscriptions() {
        logger.log("Registering quick action subscriptions")
    NotificationCenter.default.publisher(for: .shortcutAddOwner)
      .sink { [weak self] _ in self?.activeSheet = .addOwner }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .shortcutAddAppointment)
      .sink { [weak self] _ in self?.activeSheet = .addAppointment }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .shortcutAddCharge)
      .sink { [weak self] _ in self?.activeSheet = .addCharge }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .shortcutViewMetrics)
      .sink { [weak self] _ in self?.activeSheet = .metricsDashboard }
      .store(in: &cancellables)
  }

  /// Begins observing app lifecycle to refresh Home Screen shortcuts dynamically.
  func startListening() {
        logger.log("Starting to listen for app lifecycle notifications")
    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
      .sink { [weak self] _ in
        self?.refreshShortcuts()
      }
      .store(in: &cancellables)
  }

  /// Regenerates and registers Home Screen shortcut items based on current app data.
  private func refreshShortcuts() {
        logger.log("Refreshing home screen shortcuts")
    // Dynamic checks based on persisted data
    let hasOwners = YourDataService.shared.hasOwners
    let hasAppointments = YourDataService.shared.hasAppointments

    var items: [UIApplicationShortcutItem] = []

    // Always allow “Add Owner”
    items.append(.init(
      type: AppShortcutType.addOwner.rawValue,
      localizedTitle: NSLocalizedString("Add Owner", comment: ""),
      localizedSubtitle: nil,
      icon: .init(systemImageName: "person.badge.plus"),
      userInfo: nil
    ))

    // Placeholder: only show “Add Appointment” if there’s at least one owner
    if hasOwners {
      items.append(.init(
        type: AppShortcutType.addAppointment.rawValue,
        localizedTitle: NSLocalizedString("Add Appointment", comment: ""),
        localizedSubtitle: NSLocalizedString("Quickly schedule a new grooming", comment: ""),
        icon: .init(systemImageName: "calendar.badge.plus"),
        userInfo: nil
      ))
    }

    // Placeholder: only show “Add Charge” if there’s at least one appointment
    if hasAppointments {
      items.append(.init(
        type: AppShortcutType.addCharge.rawValue,
        localizedTitle: NSLocalizedString("Add Charge", comment: ""),
        localizedSubtitle: NSLocalizedString("Log a payment", comment: ""),
        icon: .init(systemImageName: "dollarsign.circle"),
        userInfo: nil
      ))
    }

    // Always include “View Metrics”
    items.append(.init(
      type: AppShortcutType.viewMetrics.rawValue,
      localizedTitle: NSLocalizedString("View Metrics", comment: ""),
      localizedSubtitle: NSLocalizedString("See your dashboard", comment: ""),
      icon: .init(systemImageName: "chart.bar.doc.horizontal"),
      userInfo: nil
    ))

    UIApplication.shared.shortcutItems = items

        logger.log("Registered \(items.count) shortcut items")
  }

  /// Signs the user in by setting isAuthenticated to true.
  func signIn() {
        logger.log("Signing in user")
    isAuthenticated = true
  }

  /// Signs the user out by setting isAuthenticated to false.
  func signOut() {
        logger.log("Signing out user")
    isAuthenticated = false
  }

  /// Updates the loyalty threshold.
  func updateLoyaltyThreshold(to newValue: Int) {
        logger.log("Updating loyaltyThreshold to \(newValue)")
    loyaltyThreshold = newValue
  }

  /// Initializes the shared AppState and registers quick-action listeners.
  private init() {
    // Load loyalty threshold from UserDefaults or default to 10
    self.loyaltyThreshold = UserDefaults.standard.integer(forKey: "loyaltyThreshold")
    if self.loyaltyThreshold == 0 {
      self.loyaltyThreshold = 10
    }
    registerQuickActionSubscriptions()
    startListening()
        logger.log("AppState initialized; loyaltyThreshold=\(loyaltyThreshold)")
  }
}
