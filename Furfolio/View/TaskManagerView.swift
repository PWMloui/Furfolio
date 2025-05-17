
//  TaskManagerView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 18, 2025 — added fetch, sections, add/edit sheet, and helper row.
//

import SwiftUI
import SwiftData

// TODO: Move task-fetching, deletion, and sheet presentation logic into a dedicated TaskManagerViewModel for cleaner views and easier testing.

@MainActor
/// Manages and displays lists of pending, overdue, and completed tasks, with support for adding new tasks.
struct TaskManagerView: View {
    @Environment(\.modelContext) private var modelContext

    /// Shared formatter for displaying due dates.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .short
      return fmt
    }()
    /// Shared calendar reference for date computations.
    private static let calendar = Calendar.current

    // MARK: — Fetch descriptors for different task states
    /// Tasks not yet completed and due today or in the future, sorted by due date then priority.
    @Query(
      predicate: #Predicate { !$0.isCompleted && ($0.dueDate ?? .distantFuture) >= Date.now },
      sort: [ SortDescriptor(\Task.dueDate, order: .forward), SortDescriptor(\Task.priority, order: .forward) ]
    )
    private var pendingTasks: [Task]

    /// Tasks marked completed, sorted by most recently updated.
    @Query(
      predicate: #Predicate { $0.isCompleted },
      sort: [ SortDescriptor(\Task.updatedAt, order: .reverse) ]
    )
    private var completedTasks: [Task]

    /// Tasks not completed and past their due date, sorted by due date.
    @Query(
      predicate: #Predicate { !$0.isCompleted && ($0.dueDate ?? .distantPast) < Date.now },
      sort: [ SortDescriptor(\Task.dueDate, order: .forward) ]
    )
    private var overdueTasks: [Task]

    @State private var showingAddSheet = false

    var body: some View {
      NavigationStack {
        List {
          // Pending
          /// Section listing all pending tasks.
          if !pendingTasks.isEmpty {
            Section("Pending Tasks") {
              ForEach(pendingTasks) { task in
                TaskRow(task: task)
              }
              .onDelete { idx in
                for i in idx { modelContext.delete(pendingTasks[i]) }
              }
            }
          }

          // Overdue
          /// Section listing tasks that are overdue.
          if !overdueTasks.isEmpty {
            Section("Overdue") {
              ForEach(overdueTasks) { task in
                TaskRow(task: task)
              }
              .onDelete { idx in
                for i in idx { modelContext.delete(overdueTasks[i]) }
              }
            }
          }

          // Completed
          /// Section listing all completed tasks.
          if !completedTasks.isEmpty {
            Section("Completed") {
              ForEach(completedTasks) { task in
                TaskRow(task: task)
              }
              .onDelete { idx in
                for i in idx { modelContext.delete(completedTasks[i]) }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingAddSheet = true }) {
              Image(systemName: "plus")
            }
          }
        }
        /// Sheet for adding a new task.
        .sheet(isPresented: $showingAddSheet) {
          AddTaskView { newTask in
            modelContext.insert(newTask)
            showingAddSheet = false
          }
          .environment(\.modelContext, modelContext)
        }
      }
    }
}


@MainActor
/// A row displaying task title, formatted due date, relative time, and completion toggle.
private struct TaskRow: View {
  @Bindable var task: Task
  @Environment(\.modelContext) private var modelContext

  /// Shared formatters for due date display.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
  }()
  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
  }()

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        /// Task title and status.
        Text(task.title)
          .font(.headline)
        if let due = task.dueDate {
          Text(Self.dateFormatter.string(from: due))
            .font(.caption)
            .foregroundColor(task.isOverdue ? .red : .secondary)
        }
        if let due = task.dueDate {
          Text(Self.relativeFormatter.localizedString(for: due, relativeTo: Date.now))
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Button(action: {
        withAnimation {
          task.markCompleted()
        }
      }) {
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundColor(task.isCompleted ? .green : .gray)
      }
      .buttonStyle(.borderless)
    }
    .padding(.vertical, 6)
    .cardStyle()
  }
}


@MainActor
/// Modal form for creating a new Task with title, details, due date, and priority.
struct AddTaskView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var details = ""
  @State private var dueDate = Date.now
  @State private var priority: TaskPriority = .medium

  var onSave: (Task) -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Task Info") {
          TextField("Title", text: $title)
          TextField("Details", text: $details)
          DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
          Picker("Priority", selection: $priority) {
            ForEach(TaskPriority.allCases) { p in
              Text(p.title).tag(p)
            }
          }
          .pickerStyle(.segmented)
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("New Task")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          /// Saves the new Task if the title is non-empty.
          Button("Save") {
            let task = Task.create(
              title: title,
              details: details.isEmpty ? nil : details,
              dueDate: dueDate,
              priority: priority,
              in: try! Environment(\.modelContext).wrappedValue
            )
            onSave(task)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
  }
}

#if DEBUG
struct TaskManagerView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [Task.self],
            modelConfiguration: config
        )
    }()

    static var previews: some View {
        TaskManagerView()
            .environment(\.modelContext, container.mainContext)
    }
}
#endif
