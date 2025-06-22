//
//  OverdueTaskBanner.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OverdueTaskBanner: View {
    let overdueTasks: [Task] // Pass in your overdue tasks from your view model
    @State private var isVisible: Bool = true

    var body: some View {
        if isVisible && !overdueTasks.isEmpty {
            VStack {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You have overdue tasks!")
                            .font(.headline)
                        if overdueTasks.count == 1 {
                            Text("“\(overdueTasks.first?.title ?? "Task")” is overdue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(overdueTasks.count) tasks are overdue. Please review them.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            isVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .accessibilityLabel("Dismiss")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(radius: 6, y: 3)
                )
                .padding([.top, .horizontal])
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview

struct OverdueTaskBanner_Previews: PreviewProvider {
    static var previews: some View {
        OverdueTaskBanner(overdueTasks: [
            Task(title: "Follow up with Max’s owner", notes: "", dueDate: Date().addingTimeInterval(-3600), priority: .high, isCompleted: false),
            Task(title: "Call supplier", notes: "", dueDate: Date().addingTimeInterval(-7200), priority: .medium, isCompleted: false)
        ])
        .preferredColorScheme(.light)

        OverdueTaskBanner(overdueTasks: [
            Task(title: "Send invoice", notes: "", dueDate: Date().addingTimeInterval(-3600), priority: .high, isCompleted: false)
        ])
        .preferredColorScheme(.dark)
    }
}

// MARK: - Task and Priority Examples (for Preview/demo)

enum Priority: String, CaseIterable, Codable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var notes: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool
}
