//
//  Priority.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftUI

// MARK: - Priority (Modular, Tokenized, Auditable Priority Model)

/// Represents a modular, auditable, tokenized priority entity for tasks, reminders, or appointments within the business management context.
/// This enum supports analytics, dashboards, badge/UI integration, localization, audit/event reporting, and business logic for all tasks and appointments.
enum Priority: String, Codable, CaseIterable, Identifiable {
    /// High priority level, indicating critical and urgent tasks.
    case high
    /// Medium priority level, indicating important but less urgent tasks.
    case medium
    /// Low priority level, indicating non-urgent or optional tasks.
    case low
    /// No priority assigned.
    case none

    /// Unique identifier for the priority, used for identifiable conformance.
    var id: String { rawValue }

    /// User-facing display name for the priority level.
    /// Suitable for UI labels and accessibility.
    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }

    /// Localized user-facing display name for the priority level.
    /// Uses `NSLocalizedString` to support multi-language localization.
    var localizedLabel: String {
        NSLocalizedString(label, comment: "Priority label for \(rawValue) priority")
    }

    /// SF Symbol icon name representing the priority visually.
    var icon: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "arrowtriangle.up.circle.fill"
        case .low: return "arrowtriangle.down.circle.fill"
        case .none: return "circle"
        }
    }

    /// Color associated with the priority level for UI elements such as badges.
    var color: Color {
        switch self {
        case .high: return AppColors.critical
        case .medium: return AppColors.warning
        case .low: return AppColors.info
        case .none: return AppColors.secondary
        }
    }

    /// Numeric sort order for the priority level.
    /// Useful for consistent ordering in dashboards, lists, and analytics.
    /// Lower values indicate higher priority.
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .none: return 3
        }
    }

    /// Indicates whether the priority is critical.
    /// Returns `true` only for `.high`, enabling audit, alerts, and critical task highlighting.
    var isCritical: Bool {
        self == .high
    }

    /// Provides a SwiftUI badge view representing the priority.
    /// Combines icon, color, and localized label for consistent UI display.
    var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(AppFonts.headline)
            Text(localizedLabel)
                .foregroundColor(color)
                .font(AppFonts.subheadlineSemibold)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        // TODO: Move opacity logic to token or badge style engine in the future
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedLabel)
    }

    /// Default priority value used throughout the app.
    /// Set to `.none` to represent no assigned priority.
    static let `default`: Priority = .none
}

#if DEBUG
import SwiftUI

/// SwiftUI preview for visualizing all priority cases with badges.
/// Demo/business/tokenized preview intent for consistent UI testing across platforms.
struct PriorityPreview: View {
    let priorities = Priority.allCases.sorted { $0.sortOrder < $1.sortOrder }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(priorities) { priority in
                priority.badge
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Priority Badges")
    }
}

#Preview {
    PriorityPreview()
}
#endif
