//
//  TaskAssignmentView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task Assignment View
//

import SwiftUI

struct TaskAssignmentView: View {
    @Environment(\.dismiss) private var dismiss

    // Simulated staff/user list – replace with your model or @Query as needed
    let staffList: [User] = [
        User(id: UUID(), name: "Owner (You)"),
        User(id: UUID(), name: "Jenna S."),
        User(id: UUID(), name: "Marcus T.")
    ]

    // Inject existing tasks for duplicate detection
    var existingTasks: [AssignedTask] = []

    @State private var selectedUser: User?
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: Priority = .medium
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateBadge = false
    @State private var showAuditLog = false
    @State private var showSuccess = false
    @State private var appearedOnce = false

    // Handle save (inject model context or closure as needed)
    var onAssign: ((AssignedTask) -> Void)? = nil

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedUser != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assign To")) {
                    Picker("Staff", selection: $selectedUser) {
                        ForEach(staffList, id: \.id) { user in
                            Text(user.name).tag(Optional(user))
                        }
                    }
                    .accessibilityIdentifier("TaskAssignmentView-StaffPicker")
                }

                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                        .accessibilityIdentifier("TaskAssignmentView-TitleField")
                    TextField("Notes", text: $notes)
                        .accessibilityIdentifier("TaskAssignmentView-NotesField")
                }

                Section(header: Text("Due Date")) {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        .accessibilityIdentifier("TaskAssignmentView-DueDatePicker")
                }

                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("TaskAssignmentView-PriorityPicker")
                }
            }
            .navigationTitle("Assign Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("TaskAssignmentView-CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        assignTask()
                    } label: {
                        ZStack {
                            if animateBadge {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.18))
                                    .frame(width: 38, height: 38)
                                    .scaleEffect(1.12)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.54), value: animateBadge)
                            }
                            Text("Assign")
                        }
                    }
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("TaskAssignmentView-AssignButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("TaskAssignmentView-AuditLogButton")
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Task assigned successfully.")
                    .accessibilityIdentifier("TaskAssignmentView-SuccessMessage")
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskAssignmentAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Task Assignment Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskAssignmentAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskAssignmentView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskAssignmentAudit.record(action: "Appear", detail: "")
                }
            }
        }
    }

    private func assignTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard let assignee = selectedUser, !trimmedTitle.isEmpty else {
            alertMessage = "Please enter a title and select a staff member."
            showAlert = true
            TaskAssignmentAudit.record(action: "AssignFailed", detail: "Missing title or assignee")
            return
        }
        // Check for duplicate assignment (same user/title/dueDate)
        let isDuplicate = existingTasks.contains {
            $0.title.caseInsensitiveCompare(trimmedTitle) == .orderedSame &&
            $0.assignedTo == assignee &&
            Calendar.current.isDate($0.dueDate, inSameDayAs: dueDate)
        }
        if isDuplicate {
            alertMessage = "A task with this title is already assigned to \(assignee.name) for the selected date."
            showAlert = true
            TaskAssignmentAudit.record(action: "AssignFailed", detail: "Duplicate: \(trimmedTitle) to \(assignee.name) \(dueDate)")
            return
        }

        let newTask = AssignedTask(
            title: trimmedTitle,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            assignedTo: assignee
        )
        onAssign?(newTask)
        TaskAssignmentAudit.record(action: "Assigned", detail: "'\(trimmedTitle)' to \(assignee.name) on \(dueDate.formatted(date: .abbreviated, time: .omitted))")
        animateBadge = true
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateBadge = false }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct TaskAssignmentAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskAssignmentView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskAssignmentAudit {
    static private(set) var log: [TaskAssignmentAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskAssignmentAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 12) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskAssignmentAuditAdmin {
    public static func recentEvents(limit: Int = 12) -> [String] { TaskAssignmentAudit.recentSummaries(limit: limit) }
}

// MARK: - Models for Preview/demo

struct User: Identifiable, Hashable, Equatable {
    let id: UUID
    let name: String
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

struct AssignedTask: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let notes: String
    let dueDate: Date
    let priority: Priority
    let assignedTo: User
}

#Preview {
    TaskAssignmentView(
        existingTasks: [
            AssignedTask(
                title: "Feed Bella",
                notes: "AM meal",
                dueDate: Date(),
                priority: .medium,
                assignedTo: User(id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!, name: "Jenna S.")
            )
        ]
    )
}
