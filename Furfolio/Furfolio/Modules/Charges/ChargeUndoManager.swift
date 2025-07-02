//
//  ChargeUndoManager.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Undo Manager
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

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

    /// Records an audit event with optional change and detail info.
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

    /// Describes a ChargeChange in a human-readable string.
    private static func describe(_ change: ChargeChange) -> String {
        switch change {
        case .add(let c):    return "Add [\(c.type), $\(String(format: "%.2f", c.amount))]"
        case .delete(let c): return "Delete [\(c.type), $\(String(format: "%.2f", c.amount))]"
        case .edit(let o, let n):
            return "Edit [\(o.type), $\(String(format: "%.2f", o.amount)) → \(n.type), $\(String(format: "%.2f", n.amount))]"
        }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - New Analytics Properties

    /// Total number of undo operations recorded.
    static var totalUndos: Int {
        log.filter { $0.operation == "undo" }.count
    }

    /// Total number of redo operations recorded.
    static var totalRedos: Int {
        log.filter { $0.operation == "redo" }.count
    }

    /// The changeDescription of the most recent audit event, if any.
    static var mostRecentChangeDescription: String? {
        log.last?.changeDescription
    }

    // MARK: - CSV Export Enhancement

    /// Exports all audit events as CSV with headers:
    /// timestamp,operation,changeDescription,undoDepth,redoDepth,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,changeDescription,undoDepth,redoDepth,detail"
        let rows = log.map { event in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            // Escape commas and quotes in strings.
            func escape(_ str: String?) -> String {
                guard let str = str else { return "" }
                if str.contains(",") || str.contains("\"") || str.contains("\n") {
                    let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                } else {
                    return str
                }
            }
            let changeDesc = escape(event.changeDescription)
            let detail = escape(event.detail)
            return "\(timestampStr),\(event.operation),\(changeDesc),\(event.undoDepth),\(event.redoDepth),\(detail)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Accessibility: VoiceOver Announcements

    /// Posts a VoiceOver announcement with the given message.
    static func postVoiceOverAnnouncement(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Convenience to announce undo event.
    static func announceUndo(changeDescription: String?) {
        let msg = "Undo: \(changeDescription ?? "No description")"
        postVoiceOverAnnouncement(msg)
    }

    /// Convenience to announce redo event.
    static func announceRedo(changeDescription: String?) {
        let msg = "Redo: \(changeDescription ?? "No description")"
        postVoiceOverAnnouncement(msg)
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
        // Accessibility: Announce undo event with change description.
        ChargeUndoAudit.announceUndo(changeDescription: ChargeUndoAudit.describe(lastChange))
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
        // Accessibility: Announce redo event with change description.
        ChargeUndoAudit.announceRedo(changeDescription: ChargeUndoAudit.describe(lastUndone))
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
    /// Exposes CSV export of all audit events.
    public static func exportCSV() -> String {
        ChargeUndoAudit.exportCSV()
    }
    /// Total number of undo operations recorded.
    public static var totalUndos: Int {
        ChargeUndoAudit.totalUndos
    }
    /// Total number of redo operations recorded.
    public static var totalRedos: Int {
        ChargeUndoAudit.totalRedos
    }
    /// Most recent change description, if any.
    public static var mostRecentChangeDescription: String? {
        ChargeUndoAudit.mostRecentChangeDescription
    }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeUndoAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
// MARK: - DEV Overlay: SwiftUI View Showing Audit Summary and Stats

/// SwiftUI view displaying a summary of the last 3 audit events,
/// total undo/redo counts, and most recent change description.
/// Useful for developers during debugging.
@available(iOS 13.0, *)
struct ChargeUndoAuditSummaryView: View {
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charge Undo Audit Summary")
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(ChargeUndoAudit.log.suffix(3).enumerated()), id: \.offset) { index, event in
                    Text("\(event.accessibilityLabel)")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
            }

            Divider()

            HStack {
                Text("Total Undos: \(ChargeUndoAudit.totalUndos)")
                Spacer()
                Text("Total Redos: \(ChargeUndoAudit.totalRedos)")
            }
            .font(.subheadline)

            if let recent = ChargeUndoAudit.mostRecentChangeDescription {
                Text("Most Recent Change: \(recent)")
                    .font(.footnote)
                    .italic()
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Most Recent Change: None")
                    .font(.footnote)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.9))
        .cornerRadius(10)
        .shadow(radius: 5)
        .onReceive(timer) { _ in
            // Refresh view every 2 seconds to update audit log display.
        }
        .frame(maxWidth: 350)
    }
}
#endif
