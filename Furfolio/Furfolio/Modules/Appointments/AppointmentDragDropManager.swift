//
// MARK: - AppointmentDragDropManager (Tokenized, Modular, Auditable Drag & Drop Manager)
//

import Foundation
import SwiftUI

/// Manages drag-and-drop logic for appointment reordering and rescheduling.
/// This manager is designed to be modular, tokenized, and auditable, supporting multi-appointment drag/drop operations,
/// audit trails for tracking changes, permission checks for multi-user environments, route optimization hooks,
/// and rich UI feedback for Furfolio's interface.
/// It is architected to support extensibility in business logic, auditing, and user experience across iOS, iPadOS, and Mac.
// MARK: - Audit/Event Logging

fileprivate struct DragDropAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "begin", "updateDrag", "updateDropTarget", "end", "drop", "permissionDenied", etc.
    let appointmentIDs: [UUID]
    let date: Date?
    let offset: CGSize?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let ids = appointmentIDs.map { $0.uuidString.prefix(8) }.joined(separator: ",")
        let op = operation.capitalized
        let dateVal = date.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? ""
        return "[\(op)] ids: \(ids) date: \(dateVal) tags: [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class DragDropAudit {
    static private(set) var log: [DragDropAuditEvent] = []

    static func record(
        operation: String,
        appointmentIDs: Set<UUID>,
        date: Date? = nil,
        offset: CGSize? = nil,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentDragDropManager",
        detail: String? = nil
    ) {
        let event = DragDropAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentIDs: Array(appointmentIDs),
            date: date,
            offset: offset,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No drag/drop actions recorded."
    }
}

@MainActor
final class AppointmentDragDropManager: ObservableObject {
    // MARK: - Drag State

    /// The IDs of the appointments currently being dragged.
    @Published var draggingAppointmentIDs: Set<UUID> = []
    /// The current drop target date, if any.
    @Published var dropTargetDate: Date? = nil
    /// Whether a drag is currently active.
    @Published var isDragging: Bool = false
    /// The current drag offset.
    @Published var dragOffset: CGSize = .zero
    /// The last drop operation's info.
    @Published var lastDropInfo: (appointmentIDs: Set<UUID>, date: Date)? = nil

    /// Optional group ID for grouped drag operations (e.g., recurring series, multi-dog families).
    /// When set, all drag/drop actions and audits will reference this group.
    @Published var dragGroupID: UUID? = nil

    // MARK: - Begin Drag

    /// Begin dragging a set of appointments as a single (possibly grouped) operation.
    /// - Parameter appointmentIDs: The IDs of the appointments to drag.
    func beginDrag(appointmentIDs: Set<UUID>) {
        draggingAppointmentIDs = appointmentIDs
        isDragging = true
        dragOffset = .zero
        dragGroupID = nil // Not a group drag unless specified.
        DragDropAudit.record(
            operation: "begin",
            appointmentIDs: appointmentIDs,
            tags: ["beginDrag", appointmentIDs.count > 1 ? "multi" : "single"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager"
        )
    }

    /// Begin dragging a single appointment.
    func beginDrag(appointmentID: UUID) {
        beginDrag(appointmentIDs: [appointmentID])
    }

    /// Begin dragging a group of related appointments (for batch/group drag).
    /// - Parameters:
    ///   - groupID: The ID of the drag group.
    ///   - appointmentIDs: The set of appointment IDs included in this group drag.
    func beginGroupDrag(groupID: UUID, appointmentIDs: Set<UUID>) {
        // Set both the group ID and the appointment IDs as the current drag state.
        draggingAppointmentIDs = appointmentIDs
        dragGroupID = groupID
        isDragging = true
        dragOffset = .zero
        DragDropAudit.record(
            operation: "beginGroupDrag",
            appointmentIDs: appointmentIDs,
            tags: ["beginGroupDrag", "group", appointmentIDs.count > 1 ? "multi" : "single"],
            context: "groupID:\(groupID.uuidString)"
        )
    }

    /// Update the drag offset during a drag operation.
    func updateDrag(offset: CGSize) {
        dragOffset = offset
        DragDropAudit.record(
            operation: "updateDrag",
            appointmentIDs: draggingAppointmentIDs,
            offset: offset,
            tags: ["updateDrag"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager"
        )
    }

    /// Update the current drop target date during a drag.
    func updateDropTarget(date: Date) {
        dropTargetDate = date
        DragDropAudit.record(
            operation: "updateDropTarget",
            appointmentIDs: draggingAppointmentIDs,
            date: date,
            tags: ["updateDropTarget"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager"
        )
    }

    /// Ends the current drag operation, resetting all related state and logging the event.
    func endDrag() {
        DragDropAudit.record(
            operation: "end",
            appointmentIDs: draggingAppointmentIDs,
            tags: ["endDrag"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager"
        )
        draggingAppointmentIDs = []
        dropTargetDate = nil
        isDragging = false
        dragOffset = .zero
        dragGroupID = nil
    }

    /// Instantly aborts the current drag operation, clears drag state, and logs the reason for audit.
    /// - Parameter reason: Human-readable reason for aborting/cancelling the drag.
    func abortDrag(reason: String) {
        DragDropAudit.record(
            operation: "abortDrag",
            appointmentIDs: draggingAppointmentIDs,
            tags: ["abortDrag"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager",
            detail: reason
        )
        draggingAppointmentIDs = []
        dropTargetDate = nil
        isDragging = false
        dragOffset = .zero
        dragGroupID = nil
    }

    // MARK: - Drop Logic

    /// Attempts to perform a drop operation for the current drag state.
    /// If dragging a group, all group members are updated together; if any conflict, the entire drop is skipped.
    /// - Parameters:
    ///   - date: The target date for the drop.
    ///   - appointments: The array of appointments to update.
    ///   - conflictCheck: Optional closure to check for conflicts.
    /// - Returns: True if the drop was successful, false otherwise.
    func performDrop(
        on date: Date,
        appointments: inout [Appointment],
        conflictCheck: ((Appointment, Date, [Appointment]) -> Bool)? = nil
    ) -> Bool {
        guard !draggingAppointmentIDs.isEmpty else { endDrag(); return false }
        // If dragging a group, ensure all group members are updated together, or none if any conflict.
        if let groupID = dragGroupID {
            // Group drop: check all for conflicts first
            var conflictIDs: [UUID] = []
            for id in draggingAppointmentIDs {
                if let idx = appointments.firstIndex(where: { $0.id == id }) {
                    let appointment = appointments[idx]
                    if let conflictCheck, !conflictCheck(appointment, date, appointments) {
                        conflictIDs.append(id)
                    }
                } else {
                    conflictIDs.append(id) // Not found = treat as conflict
                }
            }
            if !conflictIDs.isEmpty {
                // Log group conflict and skip the entire drop for integrity
                DragDropAudit.record(
                    operation: "dropGroupConflict",
                    appointmentIDs: Set(conflictIDs),
                    date: date,
                    tags: ["drop", "skipped", "conflict", "group"],
                    context: "groupID:\(groupID.uuidString)",
                    detail: "Group drop aborted due to conflict for \(conflictIDs.count) appointments"
                )
                endDrag()
                return false
            }
            // All clear: update all group member dates
            var didMove = false
            for id in draggingAppointmentIDs {
                if let idx = appointments.firstIndex(where: { $0.id == id }) {
                    appointments[idx].date = date
                    didMove = true
                }
            }
            if didMove {
                lastDropInfo = (appointmentIDs: draggingAppointmentIDs, date: date)
                DragDropAudit.record(
                    operation: "drop",
                    appointmentIDs: draggingAppointmentIDs,
                    date: date,
                    tags: ["drop", "success", "group", draggingAppointmentIDs.count > 1 ? "multi" : "single"],
                    context: "groupID:\(groupID.uuidString)"
                )
            }
            endDrag()
            return didMove
        }
        // Not a group drag: proceed as before, but include group context if present
        var didMove = false
        var skippedIDs: [UUID] = []

        for id in draggingAppointmentIDs {
            if let idx = appointments.firstIndex(where: { $0.id == id }) {
                let appointment = appointments[idx]
                if let conflictCheck, !conflictCheck(appointment, date, appointments) {
                    skippedIDs.append(id)
                    continue
                }
                appointments[idx].date = date
                didMove = true
            }
        }

        if didMove {
            lastDropInfo = (appointmentIDs: draggingAppointmentIDs, date: date)
            DragDropAudit.record(
                operation: "drop",
                appointmentIDs: draggingAppointmentIDs.subtracting(skippedIDs),
                date: date,
                tags: ["drop", "success", draggingAppointmentIDs.count > 1 ? "multi" : "single"] + (dragGroupID != nil ? ["group"] : []),
                context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager",
                detail: skippedIDs.isEmpty ? nil : "Skipped \(skippedIDs.count) due to conflict"
            )
        }
        if !skippedIDs.isEmpty {
            DragDropAudit.record(
                operation: "drop",
                appointmentIDs: Set(skippedIDs),
                date: date,
                tags: ["drop", "skipped", "conflict"] + (dragGroupID != nil ? ["group"] : []),
                context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager",
                detail: "Appointments not moved due to conflict"
            )
        }
        endDrag()
        return didMove
    }

    /// Checks if the current drag operation can be dropped on the given date.
    /// Audit logging includes group context if present.
    func canDrop(
        on date: Date,
        appointments: [Appointment],
        rolePermissionCheck: ((UUID) -> Bool)? = nil
    ) -> Bool {
        guard !draggingAppointmentIDs.isEmpty else { return false }

        for id in draggingAppointmentIDs {
            let noOverlap = !appointments.contains { $0.date.startOfDay == date.startOfDay && $0.id != id }
            let roleOK = rolePermissionCheck?(id) ?? true
            if !noOverlap || !roleOK {
                DragDropAudit.record(
                    operation: "permissionDenied",
                    appointmentIDs: [id],
                    date: date,
                    tags: ["canDrop", !noOverlap ? "overlap" : "roleDenied"] + (dragGroupID != nil ? ["group"] : []),
                    context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager",
                    detail: !noOverlap ? "Overlap detected" : "Role denied"
                )
                return false
            }
        }
        DragDropAudit.record(
            operation: "canDrop",
            appointmentIDs: draggingAppointmentIDs,
            date: date,
            tags: ["canDrop", draggingAppointmentIDs.count > 1 ? "multi" : "single"] + (dragGroupID != nil ? ["group"] : []),
            context: dragGroupID != nil ? "groupID:\(dragGroupID!.uuidString)" : "AppointmentDragDropManager"
        )
        return true
    }
    
    // MARK: - Utility

    /// Reset drag state (alias for endDrag).
    func reset() { endDrag() }

    // MARK: - Audit Summary

    /// Returns a summary string describing the current drag, group, and audit state.
    public var dragAuditSummary: String {
        let dragState = isDragging ? "Dragging" : "Idle"
        let apptCount = draggingAppointmentIDs.count
        let groupText = dragGroupID.map { "GroupID: \($0.uuidString)" } ?? "No group"
        let apptIDs = draggingAppointmentIDs.isEmpty ? "None" : draggingAppointmentIDs.map { $0.uuidString.prefix(8) }.joined(separator: ",")
        let lastAudit = DragDropAudit.accessibilitySummary
        return """
        Drag State: \(dragState)
        Appointments: \(apptCount) [\(apptIDs)]
        \(groupText)
        Last Audit: \(lastAudit)
        """
    }
}

// MARK: - Appointment Model Placeholder
struct Appointment: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var serviceType: String
    // Extend as needed
}

// MARK: - Date Extension
private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

// MARK: - Audit/Admin Accessors

public enum DragDropAuditAdmin {
    public static var lastSummary: String { DragDropAudit.accessibilitySummary }
    public static var lastJSON: String? { DragDropAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DragDropAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
// MARK: - Usage Example (for SwiftUI List/Calendar Cell)
/*
 // For a draggable appointment cell:
 // Initiates drag with audit and permission hooks.
 .onDrag {
     dragDropManager.beginDrag(appointmentID: appointment.id)
     // Provide NSItemProvider for drag-and-drop system interoperability.
     return NSItemProvider(object: NSString(string: appointment.id.uuidString))
 }

 // For a drop target date cell:
 .onDrop(of: [UTType.text], isTargeted: ..., perform: { providers, location in
     // Attempt to perform drop with audit and permission checks internally.
     dragDropManager.performDrop(on: date, appointments: &appointments)
 })
 .onHover { hovering in
     // Update UI highlight and audit hover state for drop target.
     if hovering { dragDropManager.updateDropTarget(date: date) }
 }
*/

// MARK: - Architectural Notes
/*
 - Prepared for multi-appointment batch moves and future TSP route optimization.
 - Extend `canDrop` for audit logging, staff permission, and business rules.
 - Designed for injection or shared instance from DependencyContainer if needed.
 - Integrate with UI: Show drop target highlights, animated feedback on drop, etc.
 - For optimal SwiftUI performance, keep appointments array in ViewModel.
 */
