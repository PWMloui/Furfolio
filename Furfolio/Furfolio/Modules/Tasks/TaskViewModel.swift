//
//  TaskViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task ViewModel
//

import Foundation
import Combine

@MainActor
final class TaskViewModel: ObservableObject {
    @Published private(set) var tasks: [Task] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var showAuditLog: Bool = false

    private let service: TaskServiceProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(service: TaskServiceProtocol = TaskService.preview()) {
        self.service = service
        TaskViewModelAudit.record(action: "Init", detail: "")
        Task { await self.fetchTasks() }
    }

    // MARK: - Fetch
    func fetchTasks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = try await service.fetchTasks()
            TaskViewModelAudit.record(action: "Fetch", detail: "count=\(tasks.count)")
        } catch {
            handleError(error, context: "Fetch")
        }
    }

    // MARK: - Add
    func addTask(title: String, notes: String = "", dueDate: Date, priority: Priority) async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            handleError(TaskViewModelError.validation("Title required"), context: "Add")
            return
        }
        if tasks.contains(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            handleError(TaskViewModelError.duplicateTitle, context: "Add")
            return
        }
        let newTask = Task(
            id: UUID(),
            title: trimmed,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            isCompleted: false
        )
        do {
            try await service.addTask(newTask)
            TaskViewModelAudit.record(action: "Add", detail: trimmed)
            await fetchTasks()
        } catch {
            handleError(error, context: "Add")
        }
    }

    // MARK: - Update
    func updateTask(_ task: Task) async {
        do {
            try await service.updateTask(task)
            TaskViewModelAudit.record(action: "Update", detail: task.title)
            await fetchTasks()
        } catch {
            handleError(error, context: "Update")
        }
    }

    // MARK: - Delete
    func deleteTask(_ task: Task) async {
        do {
            try await service.deleteTask(task)
            TaskViewModelAudit.record(action: "Delete", detail: task.title)
            await fetchTasks()
        } catch {
            handleError(error, context: "Delete")
        }
    }

    // MARK: - Complete
    func completeTask(_ task: Task) async {
        do {
            try await service.completeTask(task)
            TaskViewModelAudit.record(action: "Complete", detail: task.title)
            await fetchTasks()
        } catch {
            handleError(error, context: "Complete")
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        let msg: String
        if let svcError = error as? TaskServiceError {
            msg = svcError.errorDescription ?? "Unknown error"
        } else if let vmError = error as? TaskViewModelError {
            msg = vmError.errorDescription ?? "Unknown error"
        } else {
            msg = error.localizedDescription
        }
        errorMessage = msg
        TaskViewModelAudit.record(action: context + "Error", detail: msg)
    }
}

// MARK: - ViewModel Error Types

enum TaskViewModelError: LocalizedError, Equatable {
    case validation(String)
    case duplicateTitle

    var errorDescription: String? {
        switch self {
        case .validation(let msg): return msg
        case .duplicateTitle: return "A task with this title already exists."
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct TaskViewModelAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskViewModel] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskViewModelAudit {
    static private(set) var log: [TaskViewModelAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskViewModelAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskViewModelAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { TaskViewModelAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview Support

#if DEBUG
extension TaskViewModel {
    static let preview: TaskViewModel = {
        TaskViewModel(service: TaskService.preview())
    }()
}
#endif
