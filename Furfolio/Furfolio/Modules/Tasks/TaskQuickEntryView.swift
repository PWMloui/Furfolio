//
//  TaskQuickEntryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct TaskQuickEntryView: View {
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @FocusState private var isTextFieldFocused: Bool

    // Callback for saving a task, replace with your own ModelContext or ViewModel
    var onSave: ((ChecklistTask) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a new task...", text: $title)
                .focused($isTextFieldFocused)
                .onSubmit {
                    addTask()
                }
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 100)

            Picker("", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)

            Button(action: addTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 1, y: 1)
        )
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newTask = ChecklistTask(title: trimmed, priority: priority)
        onSave?(newTask)
        title = ""
        isTextFieldFocused = true
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

#Preview {
    TaskQuickEntryView { task in
        print("Saved task: \(task.title), priority: \(task.priority.displayName)")
    }
}
