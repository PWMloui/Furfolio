//
//  TaskRowView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task Row View
//

import SwiftUI

struct TaskRowView: View {
    @Binding var task: Task
    var onToggleCompleted: (() -> Void)? = nil

    @State private var animateBadge = false
    @State private var showAuditLog = false
    @State private var appearedOnce = false

    var isOverdue: Bool {
        if let due = task.dueDate {
            return !task.isCompleted && due < Date()
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                task.isCompleted.toggle()
                onToggleCompleted?()
                TaskRowAudit.record(action: "ToggleCompleted", detail: "'\(task.title)' \(task.isCompleted ? "✅" : "⬜️")")
                animateBadge = task.isCompleted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { animateBadge = false }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? .green : (isOverdue ? .red : .gray))
                    .padding(.trailing, 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("TaskRowView-CompleteButton-\(task.title)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? .secondary : (isOverdue ? .red : .primary))
                        .strikethrough(task.isCompleted)
                        .accessibilityIdentifier("TaskRowView-Title-\(task.title)")

                    ZStack {
                        if animateBadge && task.priority == .high {
                            Circle()
                                .fill(Color.red.opacity(0.17))
                                .frame(width: 26, height: 26)
                                .scaleEffect(1.11)
                                .animation(.spring(response: 0.28, dampingFraction: 0.56), value: animateBadge)
                        }
                        TaskPriorityBadgeView(priority: task.priority)
                            .accessibilityIdentifier("TaskRowView-PriorityBadge-\(task.title)")
                    }
                }
                if let due = task.dueDate {
                    HStack(spacing: 5) {
                        if isOverdue {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .foregroundColor(.red)
                        }
                        Text("Due: \(due, style: .date)")
                            .font(.caption2)
                            .foregroundColor(isOverdue ? .red : .secondary)
                            .accessibilityIdentifier("TaskRowView-DueDate-\(task.title)")
                    }
                }
            }
            Spacer()
            // Quick actions or audit log for QA
            Button {
                showAuditLog = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("TaskRowView-QuickAction-\(task.title)")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            (task.isCompleted ? Color(.secondarySystemBackground).opacity(0.45) :
                isOverdue ? Color.red.opacity(0.07) :
                Color.clear
            )
        )
        .cornerRadius(12)
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(TaskRowAuditAdmin.recentEvents(limit: 12), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Task Row Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = TaskRowAuditAdmin.recentEvents(limit: 12).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("TaskRowView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                appearedOnce = true
                TaskRowAudit.record(action: "Appear", detail: task.title)
            }
        }
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

// MARK: - Audit/Event Logging

fileprivate struct TaskRowAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskRowView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskRowAudit {
    static private(set) var log: [TaskRowAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskRowAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 24 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskRowAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { TaskRowAudit.recentSummaries(limit: limit) }
}

#Preview {
    @State var sampleTask = Task(title: "Call Max's owner", isCompleted: false, dueDate: Date().addingTimeInterval(-3600), priority: .high)
    return TaskRowView(task: $sampleTask)
}
