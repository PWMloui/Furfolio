//
//  TaskAssignmentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskAssignmentView: View {
    @Environment(\.dismiss) private var dismiss

    // Simulated staff/user list – replace with your model or @Query
    let staffList: [User] = [
        User(id: UUID(), name: "Owner (You)"),
        User(id: UUID(), name: "Jenna S."),
        User(id: UUID(), name: "Marcus T.")
    ]

    @State private var selectedUser: User?
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: Priority = .medium
    @State private var showAlert = false

    // Handle save (inject model context or closure as needed)
    var onAssign: ((AssignedTask) -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assign To")) {
                    Picker("Staff", selection: $selectedUser) {
                        ForEach(staffList, id: \.id) { user in
                            Text(user.name).tag(Optional(user))
                        }
                    }
                }

                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    TextField("Notes", text: $notes)
                }

                Section(header: Text("Due Date")) {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }

                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Assign Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        if title.trimmingCharacters(in: .whitespaces).isEmpty || selectedUser == nil {
                            showAlert = true
                        } else {
                            let newTask = AssignedTask(
                                title: title,
                                notes: notes,
                                dueDate: dueDate,
                                priority: priority,
                                assignedTo: selectedUser!
                            )
                            onAssign?(newTask)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedUser == nil)
                }
            }
            .alert("Please enter a title and select a staff member.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

// MARK: - Models for Preview/demo

struct User: Identifiable, Hashable {
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

struct AssignedTask: Identifiable {
    let id = UUID()
    let title: String
    let notes: String
    let dueDate: Date
    let priority: Priority
    let assignedTo: User
}

#Preview {
    TaskAssignmentView()
}
