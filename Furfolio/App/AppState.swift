//
//  AppState.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import Combine

// TODO: Extract quick-action subscription logic into a dedicated AppShortcutsService to decouple from AppState.

@MainActor
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

  /// Initializes the shared AppState and registers quick-action listeners.
  private init() {
    registerQuickActionSubscriptions()
  }
}
