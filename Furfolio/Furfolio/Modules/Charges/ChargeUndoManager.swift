//
//  ChargeUndoManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Enum representing the types of changes that can occur on a Charge.
enum ChargeChange {
    case add(charge: Charge)
    case edit(oldCharge: Charge, newCharge: Charge)
    case delete(charge: Charge)
}

/// Manages undo and redo stacks for charge-related changes,
/// allowing for reversal and reapplication of edits.
final class ChargeUndoManager {
    // MARK: - Private Properties
    private var undoStack: [ChargeChange] = []
    private var redoStack: [ChargeChange] = []

    // MARK: - Recording Changes

    /// Records a newly added charge to the undo stack and clears redo stack.
    func recordAdd(charge: Charge) {
        undoStack.append(.add(charge: charge))
        redoStack.removeAll()
    }

    /// Records an edit operation from oldCharge to newCharge.
    func recordEdit(oldCharge: Charge, newCharge: Charge) {
        undoStack.append(.edit(oldCharge: oldCharge, newCharge: newCharge))
        redoStack.removeAll()
    }

    /// Records deletion of a charge.
    func recordDelete(charge: Charge) {
        undoStack.append(.delete(charge: charge))
        redoStack.removeAll()
    }

    // MARK: - Undo / Redo Operations

    /// Performs an undo operation by popping the last change and returning
    /// the inverse change to be applied.
    func undo() -> ChargeChange? {
        guard let lastChange = undoStack.popLast() else { return nil }

        let inverseChange: ChargeChange
        switch lastChange {
        case .add(let charge):
            // Undo add by deleting charge
            inverseChange = .delete(charge: charge)
        case .edit(let oldCharge, let newCharge):
            // Undo edit by swapping old and new charges
            inverseChange = .edit(oldCharge: newCharge, newCharge: oldCharge)
        case .delete(let charge):
            // Undo delete by re-adding charge
            inverseChange = .add(charge: charge)
        }

        redoStack.append(lastChange)
        return inverseChange
    }

    /// Performs a redo operation by reapplying the last undone change.
    func redo() -> ChargeChange? {
        guard let lastUndone = redoStack.popLast() else { return nil }
        undoStack.append(lastUndone)
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

    // Equatable conformance can be customized if needed
    static func == (lhs: Charge, rhs: Charge) -> Bool {
        lhs.id == rhs.id
    }
}
