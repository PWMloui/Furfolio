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

    @Published var draggingAppointmentIDs: Set<UUID> = []
    @Published var dropTargetDate: Date? = nil
    @Published var isDragging: Bool = false
    @Published var dragOffset: CGSize = .zero
    @Published var lastDropInfo: (appointmentIDs: Set<UUID>, date: Date)? = nil


    // MARK: - Begin Drag

    func beginDrag(appointmentIDs: Set<UUID>) {
        draggingAppointmentIDs = appointmentIDs
        isDragging = true
        dragOffset = .zero
        DragDropAudit.record(
            operation: "begin",
            appointmentIDs: appointmentIDs,
            tags: ["beginDrag", appointmentIDs.count > 1 ? "multi" : "single"]
        )
    }

    func beginDrag(appointmentID: UUID) {
        beginDrag(appointmentIDs: [appointmentID])
    }

    func updateDrag(offset: CGSize) {
        dragOffset = offset
        DragDropAudit.record(
            operation: "updateDrag",
            appointmentIDs: draggingAppointmentIDs,
            offset: offset,
            tags: ["updateDrag"]
        )
    }

    func updateDropTarget(date: Date) {
        dropTargetDate = date
        DragDropAudit.record(
            operation: "updateDropTarget",
            appointmentIDs: draggingAppointmentIDs,
            date: date,
            tags: ["updateDropTarget"]
        )
    }

    func endDrag() {
        DragDropAudit.record(
            operation: "end",
            appointmentIDs: draggingAppointmentIDs,
            tags: ["endDrag"]
        )
        draggingAppointmentIDs = []
        dropTargetDate = nil
        isDragging = false
        dragOffset = .zero
    }

    // MARK: - End Drag

    /// Ends the current drag operation, resetting all related state.
    /// This method clears UI state and resets any audit/event tracking related to dragging.
    /// Should be called after a drop completes or a drag is cancelled.
    func endDrag() {
        // Clean up drag state and reset audit/event tracking flags.
        draggingAppointmentIDs = []
        dropTargetDate = nil
        isDragging = false
        dragOffset = .zero
    }

    // MARK: - Drop Logic

    func performDrop(
        on date: Date,
        appointments: inout [Appointment],
        conflictCheck: ((Appointment, Date, [Appointment]) -> Bool)? = nil
    ) -> Bool {
        guard !draggingAppointmentIDs.isEmpty else { endDrag(); return false }
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
                tags: ["drop", "success", draggingAppointmentIDs.count > 1 ? "multi" : "single"],
                detail: skippedIDs.isEmpty ? nil : "Skipped \(skippedIDs.count) due to conflict"
            )
        }
        if !skippedIDs.isEmpty {
            DragDropAudit.record(
                operation: "drop",
                appointmentIDs: Set(skippedIDs),
                date: date,
                tags: ["drop", "skipped", "conflict"],
                detail: "Appointments not moved due to conflict"
            )
        }
        endDrag()
        return didMove
    }

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
                    tags: ["canDrop", !noOverlap ? "overlap" : "roleDenied"],
                    detail: !noOverlap ? "Overlap detected" : "Role denied"
                )
                return false
            }
        }
        DragDropAudit.record(
            operation: "canDrop",
            appointmentIDs: draggingAppointmentIDs,
            date: date,
            tags: ["canDrop", draggingAppointmentIDs.count > 1 ? "multi" : "single"]
        )
        return true
    }
    
    // MARK: - Utility

    func reset() { endDrag() }
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
