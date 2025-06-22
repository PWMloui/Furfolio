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

// Update your view to use the computed properties:

struct OwnerRetentionTagView: View {
    let status: OwnerRetentionStatus

    var body: some View {
        HStack(spacing: 6) {
            switch status {
            case .active, .lost:
                Label(status.label, systemImage: status.icon)
                    .font(.caption.bold())
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(status.color.opacity(0.14))
                    .clipShape(Capsule())
            case .atRisk(let days):
                Label {
                    Text(status.label)
                        .font(.caption.bold()) +
                    Text(" (\(days) days)")
                        .font(.caption2)
                } icon: {
                    Image(systemName: status.icon)
                }
                .foregroundStyle(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(status.color.opacity(0.13))
                .clipShape(Capsule())
            }
        }
    }
}
