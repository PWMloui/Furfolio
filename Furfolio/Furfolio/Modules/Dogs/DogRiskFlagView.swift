//
//  DogRiskFlagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

enum RiskLevel {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }

    var label: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
}

struct DogRiskFlagView: View {
    var riskLevel: RiskLevel
    var reason: String
    var iconName: String? = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(spacing: 8) {
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(riskLevel.color)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(riskLevel.label)
                    .font(.headline)
                    .foregroundColor(riskLevel.color)
                    .accessibilityLabel("Risk level: \(riskLevel.label)")
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Reason: \(reason)")
            }
        }
        .padding(8)
        .background(riskLevel.color.opacity(0.2))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct DogRiskFlagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            DogRiskFlagView(riskLevel: .low, reason: "No known issues")
            DogRiskFlagView(riskLevel: .medium, reason: "Sensitive skin")
            DogRiskFlagView(riskLevel: .high, reason: "Aggressive behavior")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
