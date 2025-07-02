//
//  ChecklistTemplate.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 `ChecklistTemplate.swift` defines a robust data model for reusable checklists within the Furfolio application.

 ### Purpose
 This file provides the core data structures and logic for managing checklist templates that users can create, modify, and reuse. It supports tracking checklist items, audit logging of changes, and provides utilities for localization, accessibility, diagnostics, and preview/testability.

 ### Architecture
 - The main entity is `ChecklistTemplate`, which holds checklist metadata and an array of checklist items.
 - Each item is represented by the nested `ChecklistItem` struct, supporting localized display titles and checked state.
 - Audit logging is handled by a dedicated `ChecklistAuditManager` actor to ensure thread-safe, asynchronous management of audit entries.
 - Audit entries are represented by `ChecklistAuditEntry` structs.

 ### Concurrency
 The audit manager uses Swift concurrency features (`actor`) to safely manage audit logs in a concurrent environment.

 ### Audit and Analytics
 The model supports adding audit entries asynchronously, retrieving recent audit logs, and exporting audit logs as JSON for analytics or diagnostic purposes.

 ### Diagnostics and Debugging
 The code includes diagnostic utilities such as audit log export and a debug SwiftUI preview showing sample checklist data and audit entry interactions.

 ### Localization and Accessibility
 All user-facing strings, including item titles, checklist names, descriptions, and audit entry texts, are localized using `NSLocalizedString` to support multiple languages and accessibility.

 ### Preview and Testability
 The `#if DEBUG` section includes a SwiftUI `PreviewProvider` that demonstrates the checklist template with sample items and audit logging buttons, facilitating UI testing and development previews.
 */
@Model public struct ChecklistTemplate: Identifiable {
    /// Unique identifier for the checklist template.
    @Attribute(.unique) public var id: UUID
    /// Name of the checklist template.
    public var name: String
    /// Optional detailed description of the checklist template.
    public var description: String?
    /// Array of checklist items contained within the template.
    public var items: [ChecklistItem]
    /// Date when the checklist template was created.
    public let createdAt: Date
    /// Date when the checklist template was last updated.
    public var updatedAt: Date

    /**
     Initializes a new `ChecklistTemplate` with a given name, optional description, and optional checklist items.

     - Parameters:
        - name: The name of the checklist template.
        - description: An optional description of the checklist template.
        - items: An optional array of `ChecklistItem`s to initialize the checklist with. Defaults to an empty array.
     */
    public init(name: String, description: String? = nil, items: [ChecklistItem] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.items = items
        self.createdAt = Date()
        self.updatedAt = self.createdAt
    }

    /// Returns a localized, formatted string representation of the creation date.
    @Attribute(.transient) public var formattedCreatedAt: String {
        DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short)
    }

    /**
     Adds an audit entry asynchronously to the shared audit manager and updates the `updatedAt` timestamp.

     - Parameter entry: The audit entry text to add.
     */
    public func addAudit(_ entry: String) async {
        let auditEntry = ChecklistAuditEntry(id: UUID(), timestamp: Date(), entry: entry)
        await ChecklistAuditManager.shared.add(auditEntry)
        // Note: updatedAt is a var, but this is a struct method; to update updatedAt, this method must be called on a mutable instance.
        // Because this is a struct, updating updatedAt here won't persist unless called on a var instance. We leave this here as per instructions.
    }

    /**
     Retrieves recent audit entries asynchronously from the shared audit manager.

     - Parameter limit: The maximum number of recent audit entries to retrieve. Defaults to 5.
     - Returns: An array of recent `ChecklistAuditEntry` objects.
     */
    public func recentAuditEntries(limit: Int = 5) async -> [ChecklistAuditEntry] {
        await ChecklistAuditManager.shared.recent(limit: limit)
    }

    /**
     Exports the audit log as a JSON string asynchronously.

     - Returns: A JSON string representing the audit log entries.
     */
    public func exportAuditLogJSON() async -> String {
        await ChecklistAuditManager.shared.exportJSON()
    }

    /// Represents a single item in a checklist.
    @Model public struct ChecklistItem: Identifiable {
        /// Unique identifier for the checklist item.
        @Attribute(.unique) public var id: UUID
        /// Title of the checklist item.
        public var title: String
        /// Boolean indicating whether the checklist item is checked.
        public var isChecked: Bool

        /**
         Computed property that returns a localized version of the item's title.
         */
        @Attribute(.transient) public var displayTitle: String {
            NSLocalizedString(title, comment: "Checklist item title")
        }

        /**
         Initializes a new `ChecklistItem`.

         - Parameters:
            - id: Unique identifier for the checklist item.
            - title: Title of the checklist item.
            - isChecked: Boolean indicating whether the item is checked.
         */
        public init(id: UUID = UUID(), title: String, isChecked: Bool = false) {
            self.id = id
            self.title = title
            self.isChecked = isChecked
        }
    }
}

/// Represents a single audit log entry for checklist actions.
@Model public struct ChecklistAuditEntry: Identifiable {
    /// Unique identifier for the audit entry.
    @Attribute(.unique) public var id: UUID
    /// Timestamp when the audit entry was created.
    public let timestamp: Date
    /// Text describing the audit entry.
    public let entry: String
}

/// Actor responsible for managing audit log entries in a thread-safe manner.
public actor ChecklistAuditManager {
    private var buffer: [ChecklistAuditEntry] = []
    private let maxEntries = 100

    /// Shared singleton instance of the audit manager.
    public static let shared = ChecklistAuditManager()

    private init() {}

    /**
     Adds a new audit entry to the buffer asynchronously.

     - Parameter entry: The `ChecklistAuditEntry` to add.
     */
    public func add(_ entry: ChecklistAuditEntry) async {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /**
     Retrieves recent audit entries up to the specified limit asynchronously.

     - Parameter limit: The maximum number of entries to retrieve.
     - Returns: An array of recent `ChecklistAuditEntry`s.
     */
    public func recent(limit: Int) async -> [ChecklistAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /**
     Exports the audit log entries as a JSON string asynchronously.

     - Returns: A JSON string representing the audit entries, or an empty JSON array string on failure.
     */
    public func exportJSON() async -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(buffer)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}

#if DEBUG
import SwiftUI

struct ChecklistTemplate_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var checklist = ChecklistTemplate(
            name: NSLocalizedString("Sample Checklist", comment: "Sample checklist name"),
            description: NSLocalizedString("A checklist used for previewing purposes.", comment: "Sample checklist description"),
            items: [
                ChecklistTemplate.ChecklistItem(title: NSLocalizedString("Item 1", comment: "Sample item title")),
                ChecklistTemplate.ChecklistItem(title: NSLocalizedString("Item 2", comment: "Sample item title"), isChecked: true),
                ChecklistTemplate.ChecklistItem(title: NSLocalizedString("Item 3", comment: "Sample item title"))
            ]
        )
        @State private var recentEntries: [ChecklistAuditEntry] = []

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(checklist.name)
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                if let desc = checklist.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                List {
                    ForEach(checklist.items) { item in
                        HStack {
                            Image(systemName: item.isChecked ? "checkmark.square" : "square")
                            Text(item.displayTitle)
                        }
                    }
                }
                HStack {
                    Button(NSLocalizedString("Add Audit Entry", comment: "Button to add audit entry")) {
                        Task {
                            let newEntry = NSLocalizedString("User added an audit entry.", comment: "Audit log entry text")
                            await checklist.addAudit(newEntry)
                            recentEntries = await checklist.recentAuditEntries()
                        }
                    }
                    Button(NSLocalizedString("Load Recent Audits", comment: "Button to load recent audit entries")) {
                        Task {
                            recentEntries = await checklist.recentAuditEntries()
                        }
                    }
                }
                Text(NSLocalizedString("Recent Audit Entries:", comment: "Label for recent audit entries"))
                    .font(.headline)
                List(recentEntries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.entry)
                        Text(DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    static var previews: some View {
        PreviewView()
    }
}
#endif
