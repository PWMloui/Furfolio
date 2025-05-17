//
//  TaskPriority.swift
//  Furfolio
//
//  Created by ChatGPT on 05/15/2025.
//  Updated on 07/11/2025 — added icon and Comparable conformance.
//

import Foundation
import SwiftUI

// TODO: Allow customization of priority colors and icons via theme or environment.

@MainActor
/// Defines urgency levels for tasks, including sorting, display metadata, and theming support.
enum TaskPriority: String, CaseIterable, Identifiable, Comparable, Codable {
  case low
  case medium
  case high

  // MARK: – Identifiable
  /// Unique identifier for this priority case (the raw value).
  var id: String { rawValue }

  // MARK: – Display

  /// Localized title used for display in the UI.
  var title: String {
    switch self {
    case .low:    return NSLocalizedString("Low", comment: "Low priority")
    case .medium: return NSLocalizedString("Medium", comment: "Medium priority")
    case .high:   return NSLocalizedString("High", comment: "High priority")
    }
  }

  /// Accessibility label combining title and icon.
  var accessibilityLabel: Text {
    Text("\(icon) \(title)")
  }

  /// Emoji icon that visually represents this priority level.
  var icon: String {
    switch self {
    case .low:    return "⬇️"
    case .medium: return "⚖️"
    case .high:   return "⬆️"
    }
  }

  /// Color associated with this priority level for UI theming.
  var color: Color {
    switch self {
    case .high:   return .red
    case .medium: return .orange
    case .low:    return .green
    }
  }

  // MARK: – Sorting (higher priority first)
  /// Internal sort weight: lower values sort earlier (high before medium before low).
  private var sortOrder: Int {
    switch self {
    case .high:   return 0
    case .medium: return 1
    case .low:    return 2
    }
  }

  /// Sorts priorities so that `.high` comes before `.medium`, which comes before `.low`.
  static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
    lhs.sortOrder < rhs.sortOrder
  }
}
