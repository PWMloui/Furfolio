//
//  OwnerRetentionStatus.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Retention Status
//

import SwiftUI

// Add this extension and update to support custom label if needed:

extension OwnerRetentionStatus {
    var label: String {
        switch self {
        case .active:
            return NSLocalizedString("Active", comment: "Retention: active")
        case .atRisk:
            return NSLocalizedString("At Risk", comment: "Retention: at risk")
        case .lost:
            return NSLocalizedString("Lost", comment: "Retention: lost")
        }
    }

    var badge: String {
        // Short form, can be used on badges or mini cards
        switch self {
        case .active: return NSLocalizedString("✓", comment: "Retention badge: active")
        case .atRisk: return NSLocalizedString("!", comment: "Retention badge: at risk")
        case .lost: return NSLocalizedString("✗", comment: "Retention badge: lost")
        }
    }

    var icon: String {
        switch self {
        case .active:
            return "person.crop.circle.badge.checkmark"
        case .atRisk:
            return "exclamationmark.triangle.fill"
        case .lost:
            return "person.crop.circle.badge.xmark"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .atRisk: return .orange
        case .lost: return .red
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .active: return NSLocalizedString("Retention status: active", comment: "")
        case .atRisk: return NSLocalizedString("Retention status: at risk", comment: "")
        case .lost: return NSLocalizedString("Retention status: lost", comment: "")
        }
    }

    var testIdentifier: String {
        switch self {
        case .active: return "OwnerRetentionStatus-Active"
        case .atRisk: return "OwnerRetentionStatus-AtRisk"
        case .lost: return "OwnerRetentionStatus-Lost"
        }
    }

    func auditLogEvent(ownerName: String) -> String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let now = Date()
        return "[OwnerRetentionStatus] \(ownerName): \(label) at \(df.string(from: now))"
    }
}

// Example usage in SwiftUI badge/view:
struct OwnerRetentionStatusBadge: View {
    let status: OwnerRetentionStatus
    var body: some View {
        Label {
            Text(status.label)
                .accessibilityLabel(status.accessibilityLabel)
        } icon: {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.13))
        .clipShape(Capsule())
        .accessibilityIdentifier(status.testIdentifier)
    }
}
