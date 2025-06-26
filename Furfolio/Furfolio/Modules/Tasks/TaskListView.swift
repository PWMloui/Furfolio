//
//  TaskListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task List View
//

import SwiftUI

struct TaskListView: View {
    @State private var tasks: [ChecklistTask] = [
        ChecklistTask(title: "Order new grooming shears"),
        ChecklistTask(title: "Confirm Bella's appointment"),
        ChecklistTask(title: "Send follow-up to Max's owner", isCompleted: true)
    ]
    @State private var showingAddTask = false
    @State private var animateBadge = false
    @State private var showAuditLog = false
    @State private var appearedOnce = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checklist",
                        description: Text("Add your first task.")
                    )
                    .accessibilityIdentifier("TaskListView-EmptyState")
                    .overlay(
                        Button {
                            showAuditLog = true
                        } label: {
                            Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .accessibilityIdentifier("TaskListView-AuditLogButton")
                        .padding(8),
                        alignment: .bottomTrailing
                    )
                } else {
                    List {
                        ForEach($tasks) { $task in
                            HStack {
                                Button(action: {
                                    task.isCompleted.toggle()
                                    TaskListAudit.record(action: "ToggleComplete", detail: "'\(task.title)' \(task.isCompleted ? "✅" : "⬜️")")
                                }) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : .gray)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("TaskListView-CompleteButton-\(task.title)")

                                Text(task.title)
                                    .strikethrough(task.isCompleted)
                                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                                    .accessibilityIdentifier("TaskListView-Title-\(task.title)")

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .onDelete(perform: deleteTask)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTask = true }) {
                        ZStack {
                            if animateBadge {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.17))
                                    .frame(width: 36, height: 36)
                                    .scaleEffect(1.11)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.56), value: animateBadge)
                            }
                            Label("Add Task", systemImage: "plus")
                        }
                    }
                    .accessibilityIdentifier("TaskListView-AddButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("TaskListView-AuditLogButton")
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(existingTitles: tasks.map(\.title)) { newTask in
                    let trimmed = newTask.title.trimmingCharacters(in: .whitespaces)
                    guard !tasks.contains(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
                        TaskListAudit.record(action: "AddFailed", detail: "Duplicate '\(trimmed)'")
                        return
                    }
                    tasks.append(ChecklistTask(title: trimmed))
                    TaskListAudit.record(action: "Add", detail: trimmed)
                    animateBadge = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateBadge = false }
                }
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskListAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Task List Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskListAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskListView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskListAudit.record(action: "Appear", detail: "")
                }
            }
        }
    }

    // MARK: - Methods

    private func deleteTask(at offsets: IndexSet) {
        for i in offsets {
            TaskListAudit.record(action: "Delete", detail: "'\(tasks[i].title)'")
        }
        tasks.remove(atOffsets: offsets)
    }
}

// MARK: - Model

struct ChecklistTask: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Audit/Event Logging

fileprivate struct TaskListAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskListView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskListAudit {
    static private(set) var log: [TaskListAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskListAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskListAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskListAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskListView()
}
