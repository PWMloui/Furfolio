//
//  TaskChecklistView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskChecklistView: View {
    // You can inject your real view model or model context here
    @State private var tasks: [ChecklistTask] = [
        ChecklistTask(title: "Call Max’s owner"),
        ChecklistTask(title: "Order shampoo"),
        ChecklistTask(title: "Clean grooming station")
    ]
    @State private var newTaskTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool

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
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteTask)

                HStack {
                    TextField("Add new task", text: $newTaskTitle)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addTask()
                        }
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Checklist")
            .toolbar {
                EditButton()
            }
        }
    }

    // MARK: - Methods

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(ChecklistTask(title: trimmed))
        newTaskTitle = ""
        isTextFieldFocused = false
    }

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
    TaskChecklistView()
}
