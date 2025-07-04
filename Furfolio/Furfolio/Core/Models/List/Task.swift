//
//  Task.swift
//  Furfolio
//
//  Enhanced: Audit, BI, tokenization, accessibility, analytics, export, escalation, and compliance.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Audit Entry & Manager

/// A record of a Task audit event.
@Model public struct TaskAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var entry: String
    public var user: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String, user: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
        self.user = user
    }
}

/// Manages concurrency-safe audit logging for Task events.
public actor TaskAuditManager {
    private var buffer: [TaskAuditEntry] = []
    private let maxEntries = 100
    public static let shared = TaskAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: TaskAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [TaskAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }
}

@available(iOS 18.0, *)
@Model
final class Task: Identifiable, ObservableObject {
    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var title: String
    var details: String?
    var dueDate: Date?
    var reminderTime: Date?
    var completed: Bool
    var completedAt: Date?
    var createdAt: Date
    var lastModified: Date
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    var priority: Priority
    var tags: [String]
    var isArchived: Bool

    // MARK: - Audit
    var createdBy: String?
    var lastModifiedBy: String?

    // MARK: - Tokenized Badges (Business Segmentation/Analytics)
    enum TaskBadge: String, CaseIterable, Codable {
        case urgent, overdue, recurring, compliance, automation, client, escalation
    }
    var badgeTokens: [String] = []
    @Attribute(.transient)
    var badges: [TaskBadge] { badgeTokens.compactMap { TaskBadge(rawValue: $0) } }
    public func addBadge(_ badge: TaskBadge, by user: String? = nil) async {
        if !badgeTokens.contains(badge.rawValue) {
            badgeTokens.append(badge.rawValue)
            await addAudit("Badge \(badge.rawValue) added", by: user)
        }
    }
    public func removeBadge(_ badge: TaskBadge, by user: String? = nil) async {
        badgeTokens.removeAll { $0 == badge.rawValue }
        await addAudit("Badge \(badge.rawValue) removed", by: user)
    }
    func hasBadge(_ badge: TaskBadge) -> Bool { badgeTokens.contains(badge.rawValue) }

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify) var owner: DogOwner?
    @Relationship(deleteRule: .nullify) var dog: Dog?
    @Relationship(deleteRule: .nullify) var appointment: Appointment?
    @Relationship(deleteRule: .nullify) var business: Business?
    @Relationship(deleteRule: .nullify) var assignedTo: Staff?

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        reminderTime: Date? = nil,
        completed: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        priority: Priority = .none,
        tags: [String] = [],
        isArchived: Bool = false,
        createdBy: String? = nil,
        lastModifiedBy: String? = nil,
        auditLog: [String] = [],
        badgeTokens: [String] = [],
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        business: Business? = nil,
        assignedTo: Staff? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.reminderTime = reminderTime
        self.completed = completed
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.priority = priority
        self.tags = tags
        self.isArchived = isArchived
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.auditLog = auditLog
        self.badgeTokens = badgeTokens
        self.owner = owner
        self.dog = dog
        self.appointment = appointment
        self.business = business
        self.assignedTo = assignedTo
    }

    // MARK: - Audit Methods

    /// Asynchronously logs an audit entry for Task.
    public func addAudit(_ entry: String, by user: String? = nil) async {
        let localized = NSLocalizedString(entry, comment: "Task audit log entry")
        let auditEntry = TaskAuditEntry(entry: localized, user: user)
        await TaskAuditManager.shared.add(auditEntry)
        lastModified = Date()
        if let user { lastModifiedBy = user }
    }

    /// Fetches recent audit entries asynchronously.
    public func recentAuditEntries(limit: Int = 3) async -> [TaskAuditEntry] {
        await TaskAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as JSON asynchronously.
    public func exportAuditLogJSON() async -> String {
        await TaskAuditManager.shared.exportJSON()
    }

    // MARK: - Business Intelligence / Analytics

    @Attribute(.transient)
    var isOverdue: Bool {
        guard let dueDate else { return false }
        return !completed && dueDate < Date()
    }
    @Attribute(.transient)
    var daysOpen: Int? {
        Calendar.current.dateComponents([.day], from: createdAt, to: completedAt ?? Date()).day
    }
    @Attribute(.transient)
    var daysUntilDue: Int? {
        guard let dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    @Attribute(.transient)
    var isDueSoon: Bool {
        guard let days = daysUntilDue else { return false }
        return !completed && days >= 0 && days <= 2
    }
    @Attribute(.transient)
    var escalationScore: Int {
        var score = priority.criticalityScore
        if isOverdue { score += 2 }
        if hasBadge(.escalation) { score += 1 }
        if isDueSoon { score += 1 }
        return score
    }
    /// Returns the next recurrence date for recurring tasks.
    @Attribute(.transient)
    var nextRecurrence: Date? {
        guard isRecurring, let rule = recurrenceRule, let last = completedAt ?? createdAt else { return nil }
        switch rule {
        case .daily: return Calendar.current.date(byAdding: .day, value: 1, to: last)
        case .weekly: return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: last)
        case .monthly: return Calendar.current.date(byAdding: .month, value: 1, to: last)
        case .yearly: return Calendar.current.date(byAdding: .year, value: 1, to: last)
        case .custom: return nil
        }
    }

    // MARK: - Core Task Actions

    func markCompleted(by user: String? = nil) {
        completed = true
        completedAt = Date()
        lastModified = Date()
        addAudit("Task completed", by: user)
        removeBadge(.overdue)
    }
    func markIncomplete(by user: String? = nil) {
        completed = false
        completedAt = nil
        lastModified = Date()
        addAudit("Task re-opened", by: user)
    }
    func archive(by user: String? = nil) {
        isArchived = true
        lastModified = Date()
        addAudit("Task archived", by: user)
    }
    func unarchive(by user: String? = nil) {
        isArchived = false
        lastModified = Date()
        addAudit("Task unarchived", by: user)
    }
    func escalate(by user: String? = nil) {
        addBadge(.escalation)
        lastModified = Date()
        addAudit("Task escalated", by: user)
    }

    // MARK: - Accessibility

    @Attribute(.transient)
    var accessibilityLabel: String {
        "\(title). \(priority.displayName) priority. \(completed ? "Completed." : (isOverdue ? "Overdue." : ""))"
    }

    // MARK: - Export

    func exportJSON() -> String? {
        struct Export: Codable {
            let id: UUID
            let title: String
            let details: String?
            let dueDate: Date?
            let reminderTime: Date?
            let completed: Bool
            let completedAt: Date?
            let createdAt: Date
            let lastModified: Date
            let isRecurring: Bool
            let recurrenceRule: String?
            let priority: String
            let tags: [String]
            let isArchived: Bool
            let createdBy: String?
            let lastModifiedBy: String?
            let badgeTokens: [String]
        }
        let export = Export(
            id: id, title: title, details: details, dueDate: dueDate, reminderTime: reminderTime,
            completed: completed, completedAt: completedAt, createdAt: createdAt, lastModified: lastModified,
            isRecurring: isRecurring, recurrenceRule: recurrenceRule?.rawValue, priority: priority.displayName,
            tags: tags, isArchived: isArchived, createdBy: createdBy, lastModifiedBy: lastModifiedBy, badgeTokens: badgeTokens
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - RecurrenceRule

enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }
}

// MARK: - Priority (Enhanced)

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0, low, medium, high, critical

    var id: Int { rawValue }
    var displayName: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }
    var criticalityScore: Int {
        switch self {
        case .critical: 4
        case .high: 3
        case .medium: 2
        case .low: 1
        case .none: 0
        }
    }
    var color: Color {
        switch self {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .blue
        case .none: .gray
        }
    }
    var icon: String {
        switch self {
        case .critical: "exclamationmark.triangle.fill"
        case .high: "exclamationmark.circle.fill"
        case .medium: "arrowtriangle.up.circle.fill"
        case .low: "arrowtriangle.down.circle.fill"
        case .none: "circle"
        }
    }
}

// MARK: - Sample Data Extension

@available(iOS 18.0, *)
extension Task {
    static var sample: Task {
        Task(
            title: "Order Grooming Supplies",
            details: "Ensure all low-stock items are ordered for next week.",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            reminderTime: Calendar.current.date(byAdding: .hour, value: 5, to: Date()),
            completed: false,
            isRecurring: true,
            recurrenceRule: .weekly,
            priority: .high,
            tags: ["inventory", "urgent"],
            badgeTokens: [TaskBadge.urgent.rawValue, TaskBadge.recurring.rawValue]
        )
    }
    static var overdue: Task {
        Task(
            title: "Follow up with client",
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            priority: .medium,
            tags: ["client", "followup"],
            badgeTokens: [TaskBadge.client.rawValue, TaskBadge.overdue.rawValue]
        )
    }
    static var compliance: Task {
        Task(
            title: "Upload safety certificates",
            details: "All groomers must have current safety certs on file.",
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            priority: .critical,
            tags: ["compliance", "staff"],
            badgeTokens: [TaskBadge.compliance.rawValue]
        )
    }
}
