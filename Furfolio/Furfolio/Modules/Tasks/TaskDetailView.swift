//
//  TaskDetailView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task Detail View
//

import SwiftUI

struct TaskDetailView: View {
    @State private var task: Task
    @State private var editNotes: String
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateBadge = false
    @State private var showAuditLog = false
    @State private var appearedOnce = false

    // Inject save/update/complete actions as needed
    var onSave: ((Task) -> Void)? = nil
    var onDelete: ((Task) -> Void)? = nil

    init(task: Task, onSave: ((Task) -> Void)? = nil, onDelete: ((Task) -> Void)? = nil) {
        _task = State(initialValue: task)
        _editNotes = State(initialValue: task.notes)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Info")) {
                    HStack {
                        Text("Title:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(task.title)
                            .accessibilityIdentifier("TaskDetailView-Title")
                    }

                    HStack {
                        Text("Due:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(task.dueDate, style: .date)
                            .accessibilityIdentifier("TaskDetailView-DueDate")
                    }

                    HStack {
                        Text("Priority:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(task.priority.displayName)
                            .foregroundColor(task.priority == .high ? .red : (task.priority == .low ? .blue : .primary))
                            .accessibilityIdentifier("TaskDetailView-Priority")
                    }

                    Toggle(isOn: $task.isCompleted) {
                        HStack {
                            if animateBadge && task.isCompleted {
                                Circle()
                                    .fill(Color.green.opacity(0.19))
                                    .frame(width: 36, height: 36)
                                    .scaleEffect(1.12)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.56), value: animateBadge)
                            }
                            Text("Completed")
                        }
                    }
                    .onChange(of: task.isCompleted) { isCompleted in
                        animateBadge = isCompleted
                        if isCompleted {
                            TaskDetailAudit.record(action: "MarkedComplete", detail: task.title)
                        } else {
                            TaskDetailAudit.record(action: "MarkedIncomplete", detail: task.title)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { animateBadge = false }
                    }
                    .accessibilityIdentifier("TaskDetailView-CompleteToggle")
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("TaskDetailView-NotesEditor")
                    Button("Save Notes") {
                        saveNotes()
                    }
                    .accessibilityIdentifier("TaskDetailView-SaveNotesButton")
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showAlert = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                        .accessibilityIdentifier("TaskDetailView-DeleteButton")
                    }
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("TaskDetailView-AuditLogButton")
                }
            }
            .alert("Delete Task?", isPresented: $showAlert) {
                Button("Delete", role: .destructive) {
                    onDelete?(task)
                    TaskDetailAudit.record(action: "Delete", detail: task.title)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this task?")
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskDetailAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Task Detail Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskDetailAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskDetailView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskDetailAudit.record(action: "Appear", detail: task.title)
                }
            }
        }
    }

    private func saveNotes() {
        let trimmed = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = trimmed
        onSave?(task)
        TaskDetailAudit.record(action: "NotesSaved", detail: "For \(task.title)")
    }
}

// MARK: - Model Example

struct Task: Identifiable, Codable, Equatable {
    let id: UUID = UUID()
    var title: String
    var notes: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool
}

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

// MARK: - Audit/Event Logging

fileprivate struct TaskDetailAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskDetailView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskDetailAudit {
    static private(set) var log: [TaskDetailAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskDetailAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskDetailAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskDetailAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskDetailView(
        task: Task(
            title: "Call Max’s owner",
            notes: "Remind about next appointment.",
            dueDate: Date(),
            priority: .high,
            isCompleted: false
        ),
        onSave: { _ in },
        onDelete: { _ in }
    )
}
