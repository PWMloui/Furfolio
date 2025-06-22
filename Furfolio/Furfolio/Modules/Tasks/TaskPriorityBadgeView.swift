//
//  TaskPriorityBadgeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskPriorityBadgeView: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(badgeColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(radius: 1, y: 1)
            .accessibilityLabel("\(priority.displayName) priority")
    }

    private var badgeColor: Color {
        switch priority {
        case .low: return Color.blue
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }
}

// Example Priority enum for preview/demo
enum Priority: String, CaseIterable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskPriorityBadgeView(priority: .low)
        TaskPriorityBadgeView(priority: .medium)
        TaskPriorityBadgeView(priority: .high)
    }
    .padding()
    .background(Color(.systemBackground))
}
