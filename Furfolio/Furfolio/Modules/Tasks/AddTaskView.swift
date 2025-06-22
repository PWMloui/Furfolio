//
//  AddTaskView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: Priority = .medium
    @State private var showAlert: Bool = false

    // For SwiftData, pass in a ModelContext or ViewModel as needed
    var onSave: ((Task) -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                    TextField("Notes", text: $notes)
                        .autocapitalization(.sentences)
                }

                Section(header: Text("Due Date")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
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
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if title.trimmingCharacters(in: .whitespaces).isEmpty {
                            showAlert = true
                        } else {
                            let newTask = Task(
                                title: title,
                                notes: notes,
                                dueDate: dueDate,
                                priority: priority,
                                isCompleted: false
                            )
                            onSave?(newTask)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Please enter a task title.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddTaskView()
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
