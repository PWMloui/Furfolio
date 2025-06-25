//
//  ChargeUndoManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Undo Manager
//

import Foundation

// MARK: - Audit/Event Logging

fileprivate struct ChargeUndoAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "recordAdd", "recordEdit", "recordDelete", "undo", "redo", "clear"
    let changeDescription: String?
    let undoDepth: Int
    let redoDepth: Int
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var desc = "[\(operation)] undo: \(undoDepth), redo: \(redoDepth)"
        if let c = changeDescription { desc += " (\(c))" }
        if let d = detail, !d.isEmpty { desc += " : \(d)" }
        desc += " at \(dateStr)"
        return desc
    }
}

fileprivate final class ChargeUndoAudit {
    static private(set) var log: [ChargeUndoAuditEvent] = []

    static func record(
        operation: String,
        change: ChargeChange? = nil,
        undoDepth: Int,
        redoDepth: Int,
        detail: String? = nil
    ) {
        let desc: String? = change.map(ChargeUndoAudit.describe)
        let event = ChargeUndoAuditEvent(
            timestamp: Date(),
            operation: operation,
            changeDescription: desc,
            undoDepth: undoDepth,
            redoDepth: redoDepth,
            detail: detail
        )
        log.append(event)
        if log.count > 150 { log.removeFirst() }
    }

    private static func describe(_ change: ChargeChange) -> String {
        switch change {
        case .add(let c):    return "Add [\(c.type), $\(String(format: "%.2f", c.amount))]"
        case .delete(let c): return "Delete [\(c.type), $\(String(format: "%.2f", c.amount))]"
        case .edit(let o, let n):
            return "Edit [\(o.type), $\(String(format: "%.2f", o.amount)) → \(n.type), $\(String(format: "%.2f", n.amount))]"
        }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No undo/redo events recorded."
    }
}

// MARK: - ChargeChange

/// Enum representing the types of changes that can occur on a Charge.
enum ChargeChange {
    case add(charge: Charge)
    case edit(oldCharge: Charge, newCharge: Charge)
    case delete(charge: Charge)
}

// MARK: - ChargeUndoManager (Tokenized, Modular, Auditable)

/// Manages undo and redo stacks for charge-related changes,
/// allowing for reversal and reapplication of edits, with full audit/event logging.
final class ChargeUndoManager {
    // MARK: - Private Properties
    private var undoStack: [ChargeChange] = []
    private var redoStack: [ChargeChange] = []

    // MARK: - Recording Changes

    /// Records a newly added charge to the undo stack and clears redo stack.
    func recordAdd(charge: Charge) {
        undoStack.append(.add(charge: charge))
        redoStack.removeAll()
        ChargeUndoAudit.record(
            operation: "recordAdd",
            change: .add(charge: charge),
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Added charge"
        )
    }

    /// Records an edit operation from oldCharge to newCharge.
    func recordEdit(oldCharge: Charge, newCharge: Charge) {
        undoStack.append(.edit(oldCharge: oldCharge, newCharge: newCharge))
        redoStack.removeAll()
        ChargeUndoAudit.record(
            operation: "recordEdit",
            change: .edit(oldCharge: oldCharge, newCharge: newCharge),
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Edited charge"
        )
    }

    /// Records deletion of a charge.
    func recordDelete(charge: Charge) {
        undoStack.append(.delete(charge: charge))
        redoStack.removeAll()
        ChargeUndoAudit.record(
            operation: "recordDelete",
            change: .delete(charge: charge),
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Deleted charge"
        )
    }

    // MARK: - Undo / Redo Operations

    /// Performs an undo operation by popping the last change and returning
    /// the inverse change to be applied.
    func undo() -> ChargeChange? {
        guard let lastChange = undoStack.popLast() else {
            ChargeUndoAudit.record(
                operation: "undo",
                undoDepth: undoStack.count,
                redoDepth: redoStack.count,
                detail: "Nothing to undo"
            )
            return nil
        }

        let inverseChange: ChargeChange
        switch lastChange {
        case .add(let charge):
            inverseChange = .delete(charge: charge)
        case .edit(let oldCharge, let newCharge):
            inverseChange = .edit(oldCharge: newCharge, newCharge: oldCharge)
        case .delete(let charge):
            inverseChange = .add(charge: charge)
        }

        redoStack.append(lastChange)
        ChargeUndoAudit.record(
            operation: "undo",
            change: lastChange,
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Undo performed"
        )
        return inverseChange
    }

    /// Performs a redo operation by reapplying the last undone change.
    func redo() -> ChargeChange? {
        guard let lastUndone = redoStack.popLast() else {
            ChargeUndoAudit.record(
                operation: "redo",
                undoDepth: undoStack.count,
                redoDepth: redoStack.count,
                detail: "Nothing to redo"
            )
            return nil
        }
        undoStack.append(lastUndone)
        ChargeUndoAudit.record(
            operation: "redo",
            change: lastUndone,
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Redo performed"
        )
        return lastUndone
    }

    // MARK: - State Checks

    /// Whether an undo operation can be performed.
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether a redo operation can be performed.
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Clears all undo and redo history.
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        ChargeUndoAudit.record(
            operation: "clear",
            undoDepth: undoStack.count,
            redoDepth: redoStack.count,
            detail: "Cleared all undo/redo history"
        )
    }
}

// MARK: - Charge Model Placeholder

/// A simplified Charge model for demonstration.
/// Replace with your app's full Charge model as needed.
struct Charge: Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String
    var amount: Double
    var notes: String?

    static func == (lhs: Charge, rhs: Charge) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeUndoAuditAdmin {
    public static var lastSummary: String { ChargeUndoAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeUndoAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeUndoAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
