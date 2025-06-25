//
//  DogTagManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Extensible Dog Tag Manager
//

import Foundation

/// Manages tags assigned to dogs within the Furfolio app.
final class DogTagManager {
    /// Dictionary mapping dog IDs to sets of tags
    private var dogTags: [UUID: Set<String>] = [:]

    /// Undo stack for tag actions
    private var lastAction: TagAction?

    /// Tag Action Types
    private enum TagAction {
        case add(dogID: UUID, tag: String)
        case remove(dogID: UUID, tag: String)
    }

    // MARK: - Audit/Event Logging

    fileprivate struct TagAuditEvent: Codable {
        let timestamp: Date
        let action: String
        let tag: String
        let dogID: UUID
        var summary: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "[DogTagManager] \(action) tag '\(tag)' for dog \(dogID) at \(dateStr)"
        }
    }
    fileprivate static var auditLog: [TagAuditEvent] = []

    private func recordAudit(action: String, tag: String, dogID: UUID) {
        let event = TagAuditEvent(timestamp: Date(), action: action, tag: tag, dogID: dogID)
        Self.auditLog.append(event)
        if Self.auditLog.count > 50 { Self.auditLog.removeFirst() }
    }

    // MARK: - Core Tag Management

    /// Adds a tag to a specific dog.
    func addTag(_ tag: String, to dogID: UUID) {
        var tags = dogTags[dogID] ?? Set<String>()
        let inserted = tags.insert(tag).inserted
        dogTags[dogID] = tags
        if inserted {
            lastAction = .add(dogID: dogID, tag: tag)
            recordAudit(action: "Add", tag: tag, dogID: dogID)
        }
    }

    /// Removes a tag from a specific dog.
    func removeTag(_ tag: String, from dogID: UUID) {
        guard var tags = dogTags[dogID], tags.contains(tag) else { return }
        tags.remove(tag)
        dogTags[dogID] = tags.isEmpty ? nil : tags
        lastAction = .remove(dogID: dogID, tag: tag)
        recordAudit(action: "Remove", tag: tag, dogID: dogID)
    }

    /// Undo the last tag add/remove (for admin/QA/undo UX)
    func undoLastAction() {
        guard let action = lastAction else { return }
        switch action {
        case .add(let dogID, let tag):
            _ = dogTags[dogID]?.remove(tag)
            recordAudit(action: "UndoAdd", tag: tag, dogID: dogID)
        case .remove(let dogID, let tag):
            dogTags[dogID, default: Set()].insert(tag)
            recordAudit(action: "UndoRemove", tag: tag, dogID: dogID)
        }
        lastAction = nil
    }

    /// Fetches all tags assigned to a specific dog.
    func tags(for dogID: UUID) -> Set<String> {
        return dogTags[dogID] ?? Set<String>()
    }

    /// Lists all unique tags across all dogs.
    func allTags() -> Set<String> {
        return dogTags.values.reduce(into: Set<String>()) { result, tags in
            result.formUnion(tags)
        }
    }
}

// MARK: - Admin/Audit Accessors

public enum DogTagManagerAuditAdmin {
    public static func lastSummary() -> String {
        DogTagManager.auditLog.last?.summary ?? "No tag actions yet."
    }
    public static func lastJSON() -> String? {
        guard let last = DogTagManager.auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    public static func recentEvents(limit: Int = 8) -> [String] {
        DogTagManager.auditLog.suffix(limit).map { $0.summary }
    }
}

/*
 Usage Example:

 let manager = DogTagManager()
 let dogID = UUID()

 manager.addTag("Calm", to: dogID)
 manager.addTag("Needs Shampoo", to: dogID)

 print(manager.tags(for: dogID)) // ["Calm", "Needs Shampoo"]

 manager.removeTag("Calm", from: dogID)

 // Undo last action (removes "Needs Shampoo" if it was the last added, or restores "Calm" if it was the last removed)
 manager.undoLastAction()

 print(manager.allTags()) // ["Needs Shampoo"] (or ["Calm", "Needs Shampoo"] if undo restored)

 print(DogTagManagerAuditAdmin.lastSummary())
*/
