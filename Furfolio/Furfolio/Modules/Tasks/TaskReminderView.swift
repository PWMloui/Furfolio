//
//  TaskReminderView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task Reminder View
//

import SwiftUI

struct TaskReminderView: View {
    @State private var tasks: [TaskReminder] = [
        TaskReminder(title: "Confirm Max’s appointment", dueDate: Date().addingTimeInterval(3600 * 2), isReminderEnabled: true),
        TaskReminder(title: "Order new shampoo", dueDate: Date().addingTimeInterval(3600 * 24), isReminderEnabled: false),
        TaskReminder(title: "Send invoice to Sarah", dueDate: Date().addingTimeInterval(3600 * 5), isReminderEnabled: true)
    ]
    @State private var showAuditLog = false
    @State private var animateBell: [UUID: Bool] = [:]
    @State private var appearedOnce = false

    var body: some View {
        NavigationView {
            VStack {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.slash",
                        description: Text("No upcoming tasks with reminders. 🎉")
                    )
                    .accessibilityIdentifier("TaskReminderView-EmptyState")
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
                        Section(header: Text("Upcoming Tasks")) {
                            ForEach($tasks) { $task in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.headline)
                                            .accessibilityIdentifier("TaskReminderView-Title-\(task.title)")
                                        Text(task.dueDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .accessibilityIdentifier("TaskReminderView-DueDate-\(task.title)")
                                    }
                                    Spacer()
                                    Toggle(isOn: $task.isReminderEnabled) {
                                        ZStack {
                                            if animateBell[task.id] == true {
                                                Circle()
                                                    .fill(Color.accentColor.opacity(0.19))
                                                    .frame(width: 30, height: 30)
                                                    .scaleEffect(1.18)
                                                    .animation(.spring(response: 0.31, dampingFraction: 0.53), value: animateBell[task.id])
                                            }
                                            Image(systemName: task.isReminderEnabled ? "bell.fill" : "bell.slash")
                                                .foregroundColor(task.isReminderEnabled ? .accentColor : .secondary)
                                        }
                                    }
                                    .labelsHidden()
                                    .accessibilityIdentifier("TaskReminderView-Toggle-\(task.title)")
                                    .onChange(of: task.isReminderEnabled) { newValue in
                                        animateBell[task.id] = true
                                        TaskReminderAudit.record(
                                            action: "ToggleReminder",
                                            detail: "'\(task.title)' \(newValue ? "ON" : "OFF")"
                                        )
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                                            animateBell[task.id] = false
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Task Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityIdentifier("TaskReminderView-AuditLogButton")
                }
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskReminderAuditAdmin.recentEvents(limit: 16), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Reminder Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskReminderAuditAdmin.recentEvents(limit: 16).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskReminderView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskReminderAudit.record(action: "Appear", detail: "View loaded")
                }
            }
        }
    }
}

// MARK: - Model

struct TaskReminder: Identifiable {
    let id = UUID()
    var title: String
    var dueDate: Date
    var isReminderEnabled: Bool
}

// MARK: - Audit/Event Logging

fileprivate struct TaskReminderAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .short
        return "[TaskReminderView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskReminderAudit {
    static private(set) var log: [TaskReminderAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskReminderAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskReminderAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskReminderAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskReminderView()
}
