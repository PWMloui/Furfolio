//
//  TaskListView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskListView: View {
    // Replace ChecklistTask with your app's real Task model if needed
    @State private var tasks: [ChecklistTask] = [
        ChecklistTask(title: "Order new grooming shears"),
        ChecklistTask(title: "Confirm Bella's appointment"),
        ChecklistTask(title: "Send follow-up to Max's owner", isCompleted: true)
    ]
    @State private var showingAddTask = false

    var body: some View {
        NavigationView {
            List {
                ForEach($tasks) { $task in
                    HStack {
                        Button(action: {
                            task.isCompleted.toggle()
                        }) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .gray)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .onDelete(perform: deleteTask)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTask = true }) {
                        Label("Add Task", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView { newTask in
                    // Convert AddTaskView.Task to ChecklistTask or your model as needed
                    tasks.append(ChecklistTask(title: newTask.title))
                }
            }
        }
    }

    // MARK: - Methods

    private func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
}

// MARK: - Model

struct ChecklistTask: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Preview

#Preview {
    TaskListView()
}
