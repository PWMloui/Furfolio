//
//  TaskRowView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskRowView: View {
    @Binding var task: Task
    var onToggleCompleted: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                task.isCompleted.toggle()
                onToggleCompleted?()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .padding(.trailing, 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                    TaskPriorityBadgeView(priority: task.priority)
                }
                if let due = task.dueDate {
                    Text("Due: \(due, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            Color(.secondarySystemBackground).opacity(task.isCompleted ? 0.45 : 0)
        )
        .cornerRadius(12)
    }
}

// MARK: - Preview and Example Models

struct Task: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date? = Date().addingTimeInterval(3600 * 24)
    var priority: Priority = .medium
}

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
    @State var sampleTask = Task(title: "Call Max's owner", isCompleted: false, dueDate: Date(), priority: .high)
    return TaskRowView(task: $sampleTask)
}
