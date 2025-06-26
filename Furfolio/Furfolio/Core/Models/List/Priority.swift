//
//  Priority.swift
//  Furfolio
//
//  Enhanced for analytics, business intelligence, accessibility, tokenization, and extensibility.
//
import Foundation
import SwiftUI

// MARK: - Priority (Advanced Tokenized, Auditable, Business-Intelligent Priority Model)

/// Represents a modular, auditable, tokenized priority entity for tasks, reminders, or appointments within the business management context.
/// This enum supports analytics, dashboards, badge/UI integration, localization, audit/event reporting, business logic for all tasks and appointments, and future extensibility.
enum Priority: String, Codable, CaseIterable, Identifiable {
    /// High priority level, indicating critical and urgent tasks.
    case high
    /// Medium priority level, indicating important but less urgent tasks.
    case medium
    /// Low priority level, indicating non-urgent or optional tasks.
    case low
    /// No priority assigned.
    case none

    // MARK: - Business/Analytics Tokens

    /// Unique identifier for the priority, used for identifiable conformance.
    var id: String { rawValue }

    /// System token for audit/event reporting.
    var auditToken: String { "priority_\(rawValue)" }

    /// User-facing display name for the priority level.
    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }

    /// Localized user-facing display name for the priority level.
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
        // Fallback to system colors if AppColors is unavailable.
        #if canImport(AppColors)
        switch self {
        case .high: return AppColors.critical
        case .medium: return AppColors.warning
        case .low: return AppColors.info
        case .none: return AppColors.secondary
        }
        #else
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
        #endif
    }

    /// Numeric sort order for the priority level.
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .none: return 3
        }
    }

    /// Indicates whether the priority is critical (for audit and analytics).
    var isCritical: Bool { self == .high }

    /// Analytics: Numeric score for priority criticality (for dashboards/filters).
    var criticalityScore: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .none: return 0
        }
    }

    /// System- or user-defined? (for future extensibility)
    var isCustom: Bool { false }

    // MARK: - Accessibility & Badges

    /// SwiftUI badge view representing the priority.
    /// Now supports selected and disabled states.
    func badge(selected: Bool = false, disabled: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(disabled ? .gray : color)
                .font(AppFonts.headline)
            Text(localizedLabel)
                .foregroundColor(disabled ? .gray : color)
                .font(AppFonts.subheadlineSemibold)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(
            (selected ? color.opacity(0.22) : color.opacity(0.15))
                .blendMode(disabled ? .destinationOut : .normal)
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localizedLabel), \(accessibilityDescription)")
        .accessibilityAddTraits(isCritical ? .isHeader : [])
        .opacity(disabled ? 0.5 : 1.0)
    }

    /// Accessibility description for VoiceOver and analytics.
    var accessibilityDescription: String {
        switch self {
        case .high: return NSLocalizedString("Critical priority. Requires immediate attention.", comment: "")
        case .medium: return NSLocalizedString("Important priority. Requires prompt attention.", comment: "")
        case .low: return NSLocalizedString("Low priority. Non-urgent.", comment: "")
        case .none: return NSLocalizedString("No priority set.", comment: "")
        }
    }

    /// Default priority value used throughout the app.
    static let `default`: Priority = .none
}

// MARK: - BI/Analytics Helpers

extension Array where Element == Priority {
    /// Returns the most critical priority in the array.
    var mostCritical: Priority { self.min(by: { $0.sortOrder < $1.sortOrder }) ?? .none }
    /// Counts by priority for dashboard widgets.
    var countsByPriority: [Priority: Int] {
        Dictionary(grouping: self, by: { $0 }).mapValues { $0.count }
    }
}

// MARK: - Previews

#if DEBUG
import SwiftUI

struct PriorityPreview: View {
    let priorities = Priority.allCases.sorted { $0.sortOrder < $1.sortOrder }
    @State private var selected: Priority? = nil

    var body: some View {
        VStack(spacing: 16) {
            ForEach(priorities) { priority in
                Button(action: { selected = priority }) {
                    priority.badge(selected: selected == priority, disabled: priority == .none)
                }
                .disabled(priority == .none)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Priority Badges (Enhanced)")
    }
}

#Preview {
    PriorityPreview()
}
#endif
