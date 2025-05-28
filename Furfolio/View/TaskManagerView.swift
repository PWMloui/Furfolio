//  TaskManagerView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 18, 2025 — added fetch, sections, add/edit sheet, and helper row.
//

import SwiftUI
import SwiftData

@MainActor
class TaskManagerViewModel: ObservableObject {
  private let context: ModelContext

  @Published var pendingTasks: [Task] = []
  @Published var overdueTasks: [Task] = []
  @Published var completedTasks: [Task] = []

  init(context: ModelContext) {
    self.context = context
    fetchAll()
  }

  func fetchAll() {
    pendingTasks = context.fetch(
      Query(Task.self)
        .filter(!\Task.isCompleted && (\Task.dueDate ?? .distantFuture) >= Date.now)
        .sortBy(\.dueDate, order: .forward)
        .then(\.priority, order: .forward)
    )
    overdueTasks = context.fetch(
      Query(Task.self)
        .filter(!\Task.isCompleted && (\Task.dueDate ?? .distantPast) < Date.now)
        .sortBy(\.dueDate, order: .forward)
    )
    completedTasks = context.fetch(
      Query(Task.self)
        .filter(\.isCompleted)
        .sortBy(\.updatedAt, order: .reverse)
    )
  }

  func delete(at offsets: IndexSet, in list: TaskList) {
    let tasks = tasks(for: list)
    for index in offsets {
      context.delete(tasks[index])
    }
    fetchAll()
  }

  func markCompleted(_ task: Task) {
    task.markCompleted()
    fetchAll()
  }

  private func tasks(for list: TaskList) -> [Task] {
    switch list {
    case .pending: return pendingTasks
    case .overdue: return overdueTasks
    case .completed: return completedTasks
    }
  }

  enum TaskList { case pending, overdue, completed }
}

// TODO: Move task-fetching, deletion, and sheet presentation logic into a dedicated TaskManagerViewModel for cleaner views and easier testing.

@MainActor
/// Manages and displays lists of pending, overdue, and completed tasks, with support for adding new tasks.
struct TaskManagerView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var viewModel: TaskManagerViewModel

  init() {
    let context = Environment(\.modelContext).wrappedValue
    _viewModel = StateObject(wrappedValue: TaskManagerViewModel(context: context))
  }

  @State private var showingAddSheet = false

  /// Shared formatter for displaying due dates.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
  }()
  /// Shared calendar reference for date computations.
  private static let calendar = Calendar.current

  var body: some View {
    NavigationStack {
      List {
        // Pending
        /// Section listing all pending tasks.
        if !viewModel.pendingTasks.isEmpty {
          Section("Pending Tasks") {
            ForEach(viewModel.pendingTasks) { task in
              TaskRow(task: task, viewModel: viewModel)
            }
            .onDelete { idx in
              viewModel.delete(at: idx, in: .pending)
            }
          }
        }

        // Overdue
        /// Section listing tasks that are overdue.
        if !viewModel.overdueTasks.isEmpty {
          Section("Overdue") {
            ForEach(viewModel.overdueTasks) { task in
              TaskRow(task: task, viewModel: viewModel)
            }
            .onDelete { idx in
              viewModel.delete(at: idx, in: .overdue)
            }
          }
        }

        // Completed
        /// Section listing all completed tasks.
        if !viewModel.completedTasks.isEmpty {
          Section("Completed") {
            ForEach(viewModel.completedTasks) { task in
              TaskRow(task: task, viewModel: viewModel)
            }
            .onDelete { idx in
              viewModel.delete(at: idx, in: .completed)
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
          viewModel.fetchAll()
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
  var viewModel: TaskManagerViewModel

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
          viewModel.markCompleted(task)
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
