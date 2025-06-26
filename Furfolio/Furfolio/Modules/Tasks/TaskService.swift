//
//  TaskService.swift
//  Furfolio
//
//  Enterprise-Grade Task Service: Auditable, Testable, Protocol-Driven
//

import Foundation

// MARK: - Task Model (Example)
struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool
}

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

// MARK: - Errors
enum TaskServiceError: Error, LocalizedError {
    case notFound
    case duplicateTitle
    case network(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notFound: return "Task not found."
        case .duplicateTitle: return "A task with this title already exists."
        case .network(let error): return "Network error: \(error.localizedDescription)"
        case .unknown: return "Unknown error."
        }
    }
}

// MARK: - Protocol
protocol TaskServiceProtocol {
    func fetchTasks() async throws -> [Task]
    func addTask(_ task: Task) async throws
    func updateTask(_ task: Task) async throws
    func deleteTask(_ task: Task) async throws
    func completeTask(_ task: Task) async throws
    // Optionally:
    func batchUpdate(_ tasks: [Task]) async throws
}

// MARK: - Service
final class TaskService: TaskServiceProtocol {
    private var storage: [UUID: Task] = [:]
    private let queue = DispatchQueue(label: "TaskServiceQueue", attributes: .concurrent)

    init(seed: [Task] = []) {
        for task in seed {
            storage[task.id] = task
        }
    }

    func fetchTasks() async throws -> [Task] {
        await TaskServiceAudit.record(action: "FetchTasks", detail: "")
        return queue.sync { Array(storage.values) }
    }

    func addTask(_ task: Task) async throws {
        if queue.sync(execute: { storage.values.contains(where: { $0.title.caseInsensitiveCompare(task.title) == .orderedSame }) }) {
            await TaskServiceAudit.record(action: "AddFailed", detail: "Duplicate '\(task.title)'")
            throw TaskServiceError.duplicateTitle
        }
        queue.async(flags: .barrier) {
            self.storage[task.id] = task
        }
        await TaskServiceAudit.record(action: "Add", detail: task.title)
    }

    func updateTask(_ task: Task) async throws {
        guard queue.sync(execute: { storage[task.id] != nil }) else {
            await TaskServiceAudit.record(action: "UpdateFailed", detail: "'\(task.title)' not found")
            throw TaskServiceError.notFound
        }
        queue.async(flags: .barrier) {
            self.storage[task.id] = task
        }
        await TaskServiceAudit.record(action: "Update", detail: task.title)
    }

    func deleteTask(_ task: Task) async throws {
        guard queue.sync(execute: { storage[task.id] != nil }) else {
            await TaskServiceAudit.record(action: "DeleteFailed", detail: "'\(task.title)' not found")
            throw TaskServiceError.notFound
        }
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: task.id)
        }
        await TaskServiceAudit.record(action: "Delete", detail: task.title)
    }

    func completeTask(_ task: Task) async throws {
        guard queue.sync(execute: { storage[task.id] != nil }) else {
            await TaskServiceAudit.record(action: "CompleteFailed", detail: "'\(task.title)' not found")
            throw TaskServiceError.notFound
        }
        var completedTask = task
        completedTask.isCompleted = true
        queue.async(flags: .barrier) {
            self.storage[task.id] = completedTask
        }
        await TaskServiceAudit.record(action: "Complete", detail: task.title)
    }

    func batchUpdate(_ tasks: [Task]) async throws {
        queue.async(flags: .barrier) {
            for task in tasks {
                self.storage[task.id] = task
            }
        }
        await TaskServiceAudit.record(action: "BatchUpdate", detail: "Count=\(tasks.count)")
    }
}

// MARK: - Audit/Event Logging

actor TaskServiceAudit {
    static private var log: [AuditEvent] = []
    struct AuditEvent: Codable {
        let timestamp: Date
        let action: String
        let detail: String
        var summary: String {
            let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
            return "[TaskService] \(action): \(detail) at \(df.string(from: timestamp))"
        }
    }

    static func record(action: String, detail: String) async {
        let event = AuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }

    static func recentSummaries(limit: Int = 10) async -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Preview/Mock

#if DEBUG
extension TaskService {
    static func preview() -> TaskService {
        let tasks = [
            Task(id: UUID(), title: "Call Bella's owner", notes: "", dueDate: Date(), priority: .high, isCompleted: false),
            Task(id: UUID(), title: "Order shampoo", notes: "", dueDate: Date().addingTimeInterval(3600*24), priority: .medium, isCompleted: false)
        ]
        return TaskService(seed: tasks)
    }
}
#endif
