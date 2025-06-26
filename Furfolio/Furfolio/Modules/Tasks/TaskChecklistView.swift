//
//  TaskChecklistView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Checklist View
//

import SwiftUI

struct TaskChecklistView: View {
    @State private var tasks: [ChecklistTask] = [
        ChecklistTask(title: "Call Max’s owner"),
        ChecklistTask(title: "Order shampoo"),
        ChecklistTask(title: "Clean grooming station")
    ]
    @State private var newTaskTitle: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateBadge = false
    @State private var showAuditLog = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var appearedOnce = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checklist",
                        description: Text("Add your first checklist task.")
                    )
                    .accessibilityIdentifier("TaskChecklistView-EmptyState")
                    .overlay(
                        Button {
                            showAuditLog = true
                        } label: {
                            Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .padding(8),
                        alignment: .bottomTrailing
                    )
                } else {
                    List {
                        ForEach($tasks) { $task in
                            HStack {
                                Button(action: {
                                    task.isCompleted.toggle()
                                    TaskChecklistAudit.record(action: "ToggleComplete", detail: "'\(task.title)' \(task.isCompleted ? "✅" : "⬜️")")
                                }) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : .gray)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("TaskChecklistView-CompleteButton-\(task.title)")

                                Text(task.title)
                                    .strikethrough(task.isCompleted)
                                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                                    .accessibilityIdentifier("TaskChecklistView-Title-\(task.title)")

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteTask)

                        // Add new task row
                        HStack {
                            TextField("Add new task", text: $newTaskTitle)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    addTask()
                                }
                                .accessibilityIdentifier("TaskChecklistView-AddField")
                            Button(action: addTask) {
                                ZStack {
                                    if animateBadge {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.18))
                                            .frame(width: 34, height: 34)
                                            .scaleEffect(1.13)
                                            .animation(.spring(response: 0.29, dampingFraction: 0.5), value: animateBadge)
                                    }
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .accessibilityIdentifier("TaskChecklistView-AddButton")
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .accessibilityIdentifier("TaskChecklistView-AddRow")
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Checklist")
            .toolbar {
                EditButton()
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("TaskChecklistView-AuditLogButton")
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskChecklistAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Checklist Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskChecklistAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskChecklistView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskChecklistAudit.record(action: "Appear", detail: "")
                }
            }
        }
    }

    // MARK: - Methods

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !tasks.contains(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            alertMessage = "Task with this title already exists."
            showAlert = true
            TaskChecklistAudit.record(action: "AddFailed", detail: "Duplicate '\(trimmed)'")
            return
        }
        tasks.append(ChecklistTask(title: trimmed))
        TaskChecklistAudit.record(action: "Add", detail: trimmed)
        newTaskTitle = ""
        animateBadge = true
        isTextFieldFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animateBadge = false }
    }

    private func deleteTask(at offsets: IndexSet) {
        for i in offsets {
            TaskChecklistAudit.record(action: "Delete", detail: "'\(tasks[i].title)'")
        }
        tasks.remove(atOffsets: offsets)
    }
}

// MARK: - Model

struct ChecklistTask: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Audit/Event Logging

fileprivate struct TaskChecklistAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskChecklistView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskChecklistAudit {
    static private(set) var log: [TaskChecklistAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskChecklistAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskChecklistAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskChecklistAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskChecklistView()
}
