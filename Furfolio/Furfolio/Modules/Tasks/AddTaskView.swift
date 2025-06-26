//
//  AddTaskView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Add Task View
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: Priority = .medium
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var animateBadge: Bool = false
    @State private var showAuditLog: Bool = false

    /// Optionally pass in all current tasks for duplicate check
    var existingTitles: [String] = []
    var onSave: ((Task) -> Void)? = nil

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .accessibilityIdentifier("addTaskTitleField")
                    TextField("Notes", text: $notes)
                        .autocapitalization(.sentences)
                        .accessibilityIdentifier("addTaskNotesField")
                }

                Section(header: Text("Due Date")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .accessibilityIdentifier("addTaskDueDatePicker")
                }

                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            HStack {
                                Text(p.displayName)
                                if p == .high {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                }
                                if p == .low {
                                    Image(systemName: "arrow.down.circle").foregroundColor(.blue)
                                }
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("addTaskPriorityPicker")
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("addTaskCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTask()
                    } label: {
                        ZStack {
                            if animateBadge && priority == .high {
                                Circle()
                                    .fill(Color.red.opacity(0.17))
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(1.11)
                                    .animation(.spring(response: 0.34, dampingFraction: 0.55), value: animateBadge)
                            }
                            Text("Save")
                        }
                    }
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("addTaskSaveButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("addTaskAuditLogButton")
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Task added successfully.")
                    .accessibilityIdentifier("addTaskSuccessMessage")
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(AddTaskAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Add Task Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = AddTaskAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("addTaskCopyAuditLogButton")
                        }
                    }
                }
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedTitle.isEmpty {
            alertMessage = "Please enter a task title."
            showAlert = true
            AddTaskAudit.record(action: "AddFailed", detail: "Missing title")
            return
        }
        if existingTitles.contains(where: { $0.caseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            alertMessage = "A task with this title already exists."
            showAlert = true
            AddTaskAudit.record(action: "AddFailed", detail: "Duplicate title: \(trimmedTitle)")
            return
        }
        let newTask = Task(
            title: trimmedTitle,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            isCompleted: false
        )
        AddTaskAudit.record(action: "Add", detail: "\(trimmedTitle), Due: \(dueDate), Priority: \(priority.displayName)")
        animateBadge = true
        showSuccess = true
        onSave?(newTask)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateBadge = false }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct AddTaskAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[AddTaskView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class AddTaskAudit {
    static private(set) var log: [AddTaskAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = AddTaskAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum AddTaskAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { AddTaskAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    AddTaskView(existingTitles: ["Groom Fido", "Order Shampoo"])
}

// Priority enum example
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

// Task struct example for preview/demo
struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var notes: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool
}
