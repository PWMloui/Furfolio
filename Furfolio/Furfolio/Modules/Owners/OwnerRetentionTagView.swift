//
//  OwnerRetentionTagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Displays a retention status tag for a DogOwner based on last visit, activity, or risk.
/// Expand or connect to your analytics/badge engine as needed.
struct OwnerRetentionTagView: View {
    let lastAppointmentDate: Date?
    let totalAppointments: Int
    let newClientThresholdDays: Int = 14
    let retentionRiskThresholdDays: Int = 60

    var body: some View {
        HStack(spacing: 8) {
            if isNewClient {
                tag(text: "New Client", icon: "sparkles", color: .blue)
            }
            if isRetentionRisk {
                tag(text: "Retention Risk", icon: "exclamationmark.triangle.fill", color: .orange)
            }
            if isReturning {
                tag(text: "Returning Client", icon: "arrow.2.squarepath", color: .green)
            }
            if isActive {
                tag(text: "Active", icon: "bolt.fill", color: .accentColor)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Retention Logic

    private var isNewClient: Bool {
        guard let last = lastAppointmentDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 99
        return days <= newClientThresholdDays && totalAppointments <= 1
    }

    private var isRetentionRisk: Bool {
        guard let last = lastAppointmentDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days > retentionRiskThresholdDays
    }

    private var isReturning: Bool {
        totalAppointments > 1 && !isRetentionRisk
    }

    private var isActive: Bool {
        guard let last = lastAppointmentDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 99
        return days <= 30 && totalAppointments > 0
    }

    // MARK: - Tag Builder

    private func tag(text: String, icon: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: color.opacity(0.13), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 18) {
        OwnerRetentionTagView(lastAppointmentDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), totalAppointments: 1) // New Client + Active
        OwnerRetentionTagView(lastAppointmentDate: Calendar.current.date(byAdding: .day, value: -70, to: Date()), totalAppointments: 8) // Retention Risk
        OwnerRetentionTagView(lastAppointmentDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()), totalAppointments: 4) // Returning + Active
        OwnerRetentionTagView(lastAppointmentDate: nil, totalAppointments: 0) // New Client
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
