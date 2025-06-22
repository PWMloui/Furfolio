//
//  TaskReminderView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskReminderView: View {
    // Replace with your real ViewModel or @Query for SwiftData
    @State private var tasks: [TaskReminder] = [
        TaskReminder(title: "Confirm Max’s appointment", dueDate: Date().addingTimeInterval(3600 * 2), isReminderEnabled: true),
        TaskReminder(title: "Order new shampoo", dueDate: Date().addingTimeInterval(3600 * 24), isReminderEnabled: false),
        TaskReminder(title: "Send invoice to Sarah", dueDate: Date().addingTimeInterval(3600 * 5), isReminderEnabled: true)
    ]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Upcoming Tasks")) {
                    ForEach($tasks) { $task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                Text(task.dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle(isOn: $task.isReminderEnabled) {
                                Image(systemName: task.isReminderEnabled ? "bell.fill" : "bell.slash")
                                    .foregroundColor(task.isReminderEnabled ? .accentColor : .secondary)
                            }
                            .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Task Reminders")
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

// MARK: - Preview

#Preview {
    TaskReminderView()
}
