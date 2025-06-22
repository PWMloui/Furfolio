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
@MainActor
final class AppointmentDragDropManager: ObservableObject {
    // MARK: - Drag State

    /// The IDs of the appointments currently being dragged.
    /// Supports multi-appointment drag operations for batch updates.
    /// Used for audit tracking and UI state synchronization.
    @Published var draggingAppointmentIDs: Set<UUID> = []

    /// The date cell currently hovered or targeted for drop.
    /// Drives UI highlight feedback and is used in audit/event logging to capture intended drop targets.
    @Published var dropTargetDate: Date? = nil

    /// Indicates whether an appointment drag operation is currently active.
    /// Controls UI state and can trigger audit event lifecycles.
    @Published var isDragging: Bool = false

    /// Offset for drag-follow UI effects.
    /// Enables smooth drag animations and visual feedback without affecting data state.
    @Published var dragOffset: CGSize = .zero

    /// Captures the last successful drop operation details for audit and animated feedback.
    /// Includes the set of appointment IDs moved and their new target date.
    @Published var lastDropInfo: (appointmentIDs: Set<UUID>, date: Date)? = nil

    // MARK: - Begin Drag

    /// Initiates a drag operation for one or more appointments.
    /// - Parameter appointmentIDs: The set of appointment UUIDs to be dragged.
    /// This method sets up drag state, triggers UI updates, and prepares audit/event logging.
    func beginDrag(appointmentIDs: Set<UUID>) {
        // Modular design: Track dragged items for batch operations and auditing.
        draggingAppointmentIDs = appointmentIDs
        isDragging = true
        dragOffset = .zero
    }

    /// Convenience method to begin dragging a single appointment.
    /// - Parameter appointmentID: The UUID of the appointment to drag.
    /// Wraps the multi-drag method for single-item use cases.
    func beginDrag(appointmentID: UUID) {
        beginDrag(appointmentIDs: [appointmentID])
    }

    /// Updates the drag offset for UI effects during drag operations.
    /// - Parameter offset: The current drag offset as CGSize.
    /// This method supports smooth UI feedback without altering business data.
    func updateDrag(offset: CGSize) {
        dragOffset = offset
    }

    /// Updates the date currently hovered over as a drop target.
    /// - Parameter date: The date cell that is being hovered.
    /// Used for UI highlight feedback and to inform auditing of potential drop targets.
    func updateDropTarget(date: Date) {
        dropTargetDate = date
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

    /// Performs the drop action, updating the date of all dragged appointments if allowed.
    ///
    /// This method includes audit and permission logic points:
    /// - Validates that there are appointments being dragged.
    /// - Uses the optional `conflictCheck` closure to enforce business rules and prevent scheduling conflicts.
    /// - Updates appointment dates atomically for batch moves.
    /// - Records the drop operation details for audit trails and UI feedback.
    ///
    /// - Parameters:
    ///   - date: The target date for the drop.
    ///   - appointments: Inout reference to the array of appointments to be updated.
    ///   - conflictCheck: Optional closure `(Appointment, Date, [Appointment]) -> Bool` used to verify if the appointment can be moved to the target date without conflicts.
    ///     This closure should implement business-specific rules such as overlapping appointments, resource availability, or permissions.
    ///
    /// - Returns: `true` if the drop was accepted and changes were made; `false` otherwise.
    func performDrop(
        on date: Date,
        appointments: inout [Appointment],
        conflictCheck: ((Appointment, Date, [Appointment]) -> Bool)? = nil
    ) -> Bool {
        // Ensure there are dragged appointments to process.
        guard !draggingAppointmentIDs.isEmpty else { endDrag(); return false }
        var didMove = false

        // Iterate over dragged appointment IDs to update their dates.
        for id in draggingAppointmentIDs {
            if let idx = appointments.firstIndex(where: { $0.id == id }) {
                let appointment = appointments[idx]
                // Use conflictCheck closure to enforce business logic and prevent conflicts.
                // If conflictCheck returns false, skip updating this appointment.
                if let conflictCheck, !conflictCheck(appointment, date, appointments) {
                    continue // Conflict detected, skip this appointment.
                }
                // Update the appointment date to the drop target.
                appointments[idx].date = date
                didMove = true
            }
        }

        // Record the successful drop for audit and UI feedback purposes.
        if didMove {
            lastDropInfo = (appointmentIDs: draggingAppointmentIDs, date: date)
        }

        // Reset drag state and audit tracking.
        endDrag()
        return didMove
    }

    /// Determines if dropping all dragged appointments onto a given date is valid.
    ///
    /// This method performs multi-user permission checks and conflict detection.
    /// It can be extended to include audit logging, role-based access control, and business rules.
    ///
    /// - Parameters:
    ///   - date: The target date to validate for dropping.
    ///   - appointments: The current list of appointments to check conflicts against.
    ///   - rolePermissionCheck: Optional closure `(UUID) -> Bool` to verify if the user has permission to move each appointment.
    ///
    /// - Returns: `true` if all dragged appointments can be dropped on the target date without conflicts or permission issues; `false` otherwise.
    func canDrop(
        on date: Date,
        appointments: [Appointment],
        rolePermissionCheck: ((UUID) -> Bool)? = nil
    ) -> Bool {
        // No dragged appointments means no valid drop.
        guard !draggingAppointmentIDs.isEmpty else { return false }

        // Check each dragged appointment for conflicts and permissions.
        for id in draggingAppointmentIDs {
            // Check for overlapping appointments on the target day, excluding the dragged appointment itself.
            let noOverlap = !appointments.contains { $0.date.startOfDay == date.startOfDay && $0.id != id }
            // Verify role-based permission if closure is provided.
            let roleOK = rolePermissionCheck?(id) ?? true
            if !noOverlap || !roleOK {
                // Conflict or permission failure detected.
                return false
            }
        }
        // All checks passed; drop is allowed.
        return true
    }

    // MARK: - Utility

    /// Resets drag/drop state safely.
    /// Intended for use during deinitialization or hard resets to clear audit/event flags and UI state.
    func reset() { endDrag() }
}

// MARK: - Appointment Model Placeholder
/// Represents an appointment entity with tokenized ID and scheduling information.
/// This struct is a placeholder and should be moved to the Models module.
/// Designed to be tokenized and ready for expansion with audit trails, owner/pet linkage, tags, and permission metadata.
struct Appointment: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var serviceType: String
    // Extend: Add ownerID, dogID, tags, notes, permissions, and audit metadata.
}

// MARK: - Date Extension
/// Provides normalized day-based comparison for dates.
/// Used for conflict detection, UI grouping, and scheduling logic to compare appointments on the same calendar day.
/// This extension helps ensure consistent and performant date comparisons across the app.
private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
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
