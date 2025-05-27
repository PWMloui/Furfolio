//
//  AppState.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import Combine

/// Global application state and quick-action handlers.
final class AppState: ObservableObject {
  /// Shared singleton instance.
  static let shared = AppState()

  /// Toggles presentation of the “Add Owner” sheet when a quick-action is invoked.
  /// Controls presentation of the Add Owner sheet.
  @Published var showAddOwnerSheet: Bool = false
  /// Toggles presentation of the “Add Appointment” sheet when a quick-action is invoked.
  /// Controls presentation of the Add Appointment sheet.
  @Published var showAddAppointmentSheet: Bool = false
  /// Toggles presentation of the “Add Charge” sheet when a quick-action is invoked.
  /// Controls presentation of the Add Charge sheet.
  @Published var showAddChargeSheet: Bool = false
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
    NotificationCenter.default.publisher(for: .shortcutAddOwner)
      .sink { [weak self] _ in self?.showAddOwnerSheet = true }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .shortcutAddAppointment)
      .sink { [weak self] _ in self?.showAddAppointmentSheet = true }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .shortcutAddCharge)
      .sink { [weak self] _ in self?.showAddChargeSheet = true }
      .store(in: &cancellables)
  }

  /// Signs the user in by setting isAuthenticated to true.
  func signIn() {
    isAuthenticated = true
  }

  /// Signs the user out by setting isAuthenticated to false.
  func signOut() {
    isAuthenticated = false
  }

  /// Updates the loyalty threshold.
  func updateLoyaltyThreshold(to newValue: Int) {
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
  }
}
