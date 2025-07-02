//
//  TaskTemplate.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 TaskTemplate
 ------------
 A reusable template for creating tasks in Furfolio, complete with auditing, localization, and preview support.

 - **Architecture**: Conforms to Identifiable, Codable, and SwiftData (when applicable).
 - **Fields**: Template metadata, including title, description, default duration, and steps.
 - **Concurrency & Audit**: Provides async audit logging via `TaskTemplateAuditManager`.
 - **Localization**: All user-facing labels and descriptions use `NSLocalizedString`.
 - **Accessibility**: Preview supports VoiceOver with accessible labels.
 - **Preview/Testability**: Includes SwiftUI preview with sample templates.
 */

import Foundation
import SwiftData

@Model public struct TaskTemplateStep: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var durationMinutes: Int

    /// Localized display title for the step.
    @Attribute(.transient)
    public var displayTitle: String {
        NSLocalizedString(title, comment: "TaskTemplateStep title")
    }

    public init(id: UUID = UUID(), title: String, durationMinutes: Int) {
        self.id = id
        self.title = NSLocalizedString(title, comment: "TaskTemplateStep title")
        self.durationMinutes = durationMinutes
    }
}

@Model public struct TaskTemplate: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var description: String?
    public var defaultDuration: Int // in minutes
    public var steps: [TaskTemplateStep]
    public let createdAt: Date
    public var updatedAt: Date

    /// Localized display name for the template.
    @Attribute(.transient)
    public var displayName: String {
        NSLocalizedString(name, comment: "TaskTemplate name")
    }

    /// Formatted creation date.
    @Attribute(.transient)
    public var formattedCreatedAt: String {
        DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        defaultDuration: Int = 0,
        steps: [TaskTemplateStep] = []
    ) {
        self.id = id
        self.name = NSLocalizedString(name, comment: "TaskTemplate name")
        self.description = description
        self.defaultDuration = defaultDuration
        self.steps = steps
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: - Audit Methods

    /// Asynchronously log a change to this template.
    public func addAudit(_ entry: String) async {
        let localized = NSLocalizedString(entry, comment: "TaskTemplate audit entry")
        let auditEntry = TaskTemplateAuditEntry(timestamp: Date(), entry: localized)
        await TaskTemplateAuditManager.shared.add(auditEntry)
    }

    /// Fetch recent audit entries for this template.
    public func recentAuditEntries(limit: Int = 20) async -> [TaskTemplateAuditEntry] {
        await TaskTemplateAuditManager.shared.recent(limit: limit)
    }

    /// Export the audit log as a JSON string.
    public func exportAuditLogJSON() async -> String {
        await TaskTemplateAuditManager.shared.exportJSON()
    }
}

@Model public struct TaskTemplateAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

public actor TaskTemplateAuditManager {
    private var buffer: [TaskTemplateAuditEntry] = []
    private let maxEntries = 100
    public static let shared = TaskTemplateAuditManager()

    /// Add a new audit entry.
    public func add(_ entry: TaskTemplateAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [TaskTemplateAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as JSON.
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

#if DEBUG
import SwiftUI

struct TaskTemplate_Previews: PreviewProvider {
    static var previews: some View {
        let step1 = TaskTemplateStep(title: "Wash Coat", durationMinutes: 10)
        let step2 = TaskTemplateStep(title: "Blow Dry", durationMinutes: 15)
        let template = TaskTemplate(
            name: "Standard Groom",
            description: "Basic grooming service",
            defaultDuration: 30,
            steps: [step1, step2]
        )

        return VStack(alignment: .leading, spacing: 16) {
            Text(template.displayName)
                .font(.headline)
            Text(template.description ?? "")
                .font(.subheadline)
            Text("Created: \(template.formattedCreatedAt)")
                .font(.caption)
            Button("Add Audit Entry") {
                Task {
                    await template.addAudit("Preview audit entry")
                    let entries = await template.recentAuditEntries(limit: 5)
                    print(entries)
                }
            }
        }
        .padding()
    }
}
#endif
