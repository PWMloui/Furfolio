//
//  TaskQuickEntryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Quick Entry
//

import SwiftUI

struct TaskQuickEntryView: View {
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @FocusState private var isTextFieldFocused: Bool

    @State private var animateBadge = false
    @State private var showAuditLog = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appearedOnce = false

    /// Pass existingTitles for duplicate prevention (optional)
    var existingTitles: [String] = []
    var onSave: ((ChecklistTask) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a new task...", text: $title)
                .focused($isTextFieldFocused)
                .onSubmit { addTask() }
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 100)
                .accessibilityIdentifier("TaskQuickEntryView-TitleField")

            Picker("", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .accessibilityIdentifier("TaskQuickEntryView-PriorityPicker")

            Button(action: addTask) {
                ZStack {
                    if animateBadge {
                        Circle()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .scaleEffect(1.11)
                            .animation(.spring(response: 0.32, dampingFraction: 0.54), value: animateBadge)
                    }
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("TaskQuickEntryView-AddButton")

            Button {
                showAuditLog = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption)
            }
            .padding(.leading, 6)
            .accessibilityIdentifier("TaskQuickEntryView-AuditLogButton")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 1, y: 1)
        )
        .alert(errorMessage, isPresented: $showError) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(TaskQuickEntryAuditAdmin.recentEvents(limit: 12), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Quick Entry Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = TaskQuickEntryAuditAdmin.recentEvents(limit: 12).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("TaskQuickEntryView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                appearedOnce = true
                TaskQuickEntryAudit.record(action: "Appear", detail: "")
            }
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Duplicate prevention
        if existingTitles.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            errorMessage = "A task with this title already exists."
            showError = true
            TaskQuickEntryAudit.record(action: "AddFailed", detail: "Duplicate '\(trimmed)'")
            return
        }
        let newTask = ChecklistTask(title: trimmed, priority: priority)
        onSave?(newTask)
        TaskQuickEntryAudit.record(action: "Add", detail: "\(trimmed), priority: \(priority.displayName)")
        title = ""
        isTextFieldFocused = true
        animateBadge = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { animateBadge = false }
    }
}

// MARK: - Supporting Models

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

struct ChecklistTask: Identifiable {
    let id = UUID()
    var title: String
    var priority: Priority = .medium
    var isCompleted: Bool = false
}

// MARK: - Audit/Event Logging

fileprivate struct TaskQuickEntryAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskQuickEntryView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskQuickEntryAudit {
    static private(set) var log: [TaskQuickEntryAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskQuickEntryAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskQuickEntryAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskQuickEntryAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskQuickEntryView(existingTitles: ["Order new shears", "Follow up call"]) { task in
        print("Saved task: \(task.title), priority: \(task.priority.displayName)")
    }
}
