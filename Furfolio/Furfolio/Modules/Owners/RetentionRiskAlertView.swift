//
//  RetentionRiskAlertView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

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
        case .active:
            return .green
        case .atRisk:
            return .orange
        case .lost:
            return .red
        }
    }
}

