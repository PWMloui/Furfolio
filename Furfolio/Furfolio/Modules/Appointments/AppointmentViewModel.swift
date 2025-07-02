//
//  AppointmentViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Appointment ViewModel
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Audit/Event Logging

fileprivate struct AppointmentVM_AuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "fetch", "add", "update", "delete", "error", "conflictDetected"
    let appointmentID: UUID?
    let appointment: Appointment?
    let count: Int?
    let error: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let id = appointmentID?.uuidString.prefix(8) ?? "-"
        let extra = count.map { " (\($0) total)" } ?? ""
        let msg = error ?? detail ?? ""
        return "[\(op)] id:\(id)\(extra) [\(tags.joined(separator: ","))] at \(dateStr)\(msg.isEmpty ? "" : ": \(msg)")"
    }
}

fileprivate final class AppointmentVM_Audit {
    static private(set) var log: [AppointmentVM_AuditEvent] = []

    static func record(
        operation: String,
        appointmentID: UUID? = nil,
        appointment: Appointment? = nil,
        count: Int? = nil,
        error: String? = nil,
        tags: [String] = [],
        actor: String? = "system",
        context: String? = "AppointmentViewModel",
        detail: String? = nil
    ) {
        let event = AppointmentVM_AuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            appointment: appointment,
            count: count,
            error: error,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 200 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Export audit log as CSV string including all events with detailed fields.
    /// CSV columns: timestamp,operation,appointmentID,dogName,ownerName,serviceType,notes,hasConflict,count,error,tags,actor,context,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,appointmentID,dogName,ownerName,serviceType,notes,hasConflict,count,error,tags,actor,context,detail"
        let rows = log.map { event -> String in
            let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
            let operation = event.operation
            let appointmentID = event.appointmentID?.uuidString ?? ""
            let dogName = event.appointment?.dogName ?? ""
            let ownerName = event.appointment?.ownerName ?? ""
            let serviceType = event.appointment?.serviceType ?? ""
            let notes = event.appointment?.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let hasConflict = event.appointment?.hasConflict.description ?? ""
            let count = event.count.map(String.init) ?? ""
            let error = event.error?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tags = event.tags.joined(separator: ";")
            let actor = event.actor ?? ""
            let context = event.context ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            // CSV escape fields containing commas or quotes by wrapping in quotes
            func csvEscape(_ field: String) -> String {
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field)\""
                }
                return field
            }
            return [
                csvEscape(timestamp),
                csvEscape(operation),
                csvEscape(appointmentID),
                csvEscape(dogName),
                csvEscape(ownerName),
                csvEscape(serviceType),
                csvEscape(notes),
                csvEscape(hasConflict),
                csvEscape(count),
                csvEscape(error),
                csvEscape(tags),
                csvEscape(actor),
                csvEscape(context),
                csvEscape(detail)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No VM audit events recorded."
    }
}

// MARK: - AppointmentViewModel (Tokenized, Modular, Auditable ViewModel)

@MainActor
class AppointmentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var appointments: [Appointment] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        Task { await fetchUpcomingAppointments() }
    }

    // MARK: - Computed Properties for Analytics

    /// Returns all appointments that have conflicts (hasConflict == true).
    var conflictingAppointments: [Appointment] {
        appointments.filter { $0.hasConflict }
    }

    /// Total number of appointments currently loaded.
    var totalAppointments: Int {
        appointments.count
    }

    /// Number of appointments with conflicts.
    var conflictCount: Int {
        conflictingAppointments.count
    }

    /// Number of upcoming appointments (date in the future or now).
    var upcomingCount: Int {
        appointments.filter { $0.date >= Date() }.count
    }

    /// Number of completed appointments (date in the past).
    var completedCount: Int {
        appointments.filter { $0.date < Date() }.count
    }

    // MARK: - Public Methods

    /// Asynchronously fetch upcoming appointments, simulating network or database calls.
    func fetchUpcomingAppointments() async {
        isLoading = true
        errorMessage = nil
        do {
            try await Task.sleep(nanoseconds: 800_000_000)
            let upcoming = sampleAppointments.filter { $0.date >= Date() }
            appointments = upcoming.sorted { $0.date < $1.date }
            isLoading = false
            AppointmentVM_Audit.record(
                operation: "fetch",
                count: appointments.count,
                tags: ["fetch", "success"],
                detail: "Fetched \(appointments.count) appointments"
            )
        } catch {
            errorMessage = "Failed to load appointments."
            isLoading = false
            AppointmentVM_Audit.record(
                operation: "error",
                error: error.localizedDescription,
                tags: ["fetch", "fail"],
                detail: errorMessage
            )
        }
    }

    /// Adds a new appointment and sorts the list by date.
    /// Also detects conflicts with existing appointments and updates hasConflict flags accordingly.
    /// Posts accessibility announcement and records audit logs including conflict detection and counts.
    func addAppointment(_ appointment: Appointment) {
        var newAppointment = appointment
        // Check for conflicts with existing appointments (same date/time)
        var conflictDetected = false
        for index in appointments.indices {
            if appointments[index].date == newAppointment.date {
                // Mark both as conflicted
                if !appointments[index].hasConflict {
                    appointments[index].hasConflict = true
                    AppointmentVM_Audit.record(
                        operation: "conflictDetected",
                        appointmentID: appointments[index].id,
                        appointment: appointments[index],
                        count: appointments.count,
                        tags: ["conflictDetected"],
                        detail: "Conflict detected with new appointment"
                    )
                }
                conflictDetected = true
            }
        }
        if conflictDetected {
            newAppointment.hasConflict = true
            AppointmentVM_Audit.record(
                operation: "conflictDetected",
                appointmentID: newAppointment.id,
                appointment: newAppointment,
                count: appointments.count + 1,
                tags: ["conflictDetected"],
                detail: "Conflict detected on adding appointment"
            )
        }
        appointments.append(newAppointment)
        appointments.sort { $0.date < $1.date }
        // Audit with updated counts
        AppointmentVM_Audit.record(
            operation: "add",
            appointmentID: newAppointment.id,
            appointment: newAppointment,
            count: appointments.count,
            tags: ["add"]
        )
        // Accessibility announcement on add
        postAccessibilityAnnouncement(for: newAppointment, action: "Added")
    }

    /// Deletes appointment matching the given UUID.
    /// Posts accessibility announcement and records audit log with updated counts.
    func deleteAppointment(id: UUID) {
        let oldCount = appointments.count
        let removed = appointments.first(where: { $0.id == id })
        appointments.removeAll { $0.id == id }
        AppointmentVM_Audit.record(
            operation: "delete",
            appointmentID: id,
            appointment: removed,
            count: appointments.count,
            tags: ["delete"],
            detail: "Removed from \(oldCount) to \(appointments.count)"
        )
        if let removed = removed {
            // Accessibility announcement on delete
            postAccessibilityAnnouncement(for: removed, action: "Deleted")
        }
    }

    /// Updates an existing appointment, replacing the old one by matching ID.
    /// Detects conflicts with other appointments and updates hasConflict flags accordingly.
    /// Posts accessibility announcement and records audit logs including conflict detection and counts.
    func updateAppointment(_ updated: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == updated.id }) else { return }
        var updatedAppointment = updated
        // Reset conflict flag before checking
        updatedAppointment.hasConflict = false
        // Check for conflicts with other appointments (same date/time, excluding self)
        var conflictDetected = false
        for i in appointments.indices {
            if i != index && appointments[i].date == updatedAppointment.date {
                if !appointments[i].hasConflict {
                    appointments[i].hasConflict = true
                    AppointmentVM_Audit.record(
                        operation: "conflictDetected",
                        appointmentID: appointments[i].id,
                        appointment: appointments[i],
                        count: appointments.count,
                        tags: ["conflictDetected"],
                        detail: "Conflict detected with updated appointment"
                    )
                }
                conflictDetected = true
            }
        }
        if conflictDetected {
            updatedAppointment.hasConflict = true
            AppointmentVM_Audit.record(
                operation: "conflictDetected",
                appointmentID: updatedAppointment.id,
                appointment: updatedAppointment,
                count: appointments.count,
                tags: ["conflictDetected"],
                detail: "Conflict detected on updating appointment"
            )
        } else {
            // If no conflict detected, ensure other appointments that had conflict with this one are re-checked and updated
            // This is a simple approach: clear conflict flags on all and re-check after update
            for i in appointments.indices where i != index {
                appointments[i].hasConflict = false
            }
            // Re-check conflicts for all appointments (including updated)
            for i in appointments.indices {
                for j in appointments.indices where j != i {
                    if appointments[i].date == appointments[j].date {
                        appointments[i].hasConflict = true
                        appointments[j].hasConflict = true
                    }
                }
            }
        }
        appointments[index] = updatedAppointment
        appointments.sort { $0.date < $1.date }
        // Audit with updated counts
        AppointmentVM_Audit.record(
            operation: "update",
            appointmentID: updatedAppointment.id,
            appointment: updatedAppointment,
            count: appointments.count,
            tags: ["update"]
        )
        // Accessibility announcement on update
        postAccessibilityAnnouncement(for: updatedAppointment, action: "Updated")
    }

    // MARK: - Private Helper for Accessibility

    /// Posts a UIAccessibility announcement summarizing the appointment action.
    /// Example: "Added appointment for Bella on June 27 at 2 PM"
    private func postAccessibilityAnnouncement(for appointment: Appointment, action: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: appointment.date)
        let announcement = "\(action) appointment for \(appointment.dogName) on \(dateString)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - Appointment Model

struct Appointment: Identifiable, Equatable, Codable {
    let id: UUID
    var date: Date
    var dogName: String
    var ownerName: String
    var serviceType: String
    var notes: String?
    var hasConflict: Bool = false
}

// MARK: - Sample Data for Previews & Testing

let sampleAppointments: [Appointment] = [
    Appointment(
        id: UUID(),
        date: Date().addingTimeInterval(3600),
        dogName: "Bella",
        ownerName: "Jane Doe",
        serviceType: "Full Groom",
        notes: "Use sensitive shampoo"
    ),
    Appointment(
        id: UUID(),
        date: Date().addingTimeInterval(7200),
        dogName: "Charlie",
        ownerName: "John Smith",
        serviceType: "Bath Only"
    ),
    Appointment(
        id: UUID(),
        date: Date().addingTimeInterval(10800),
        dogName: "Max",
        ownerName: "Emily Clark",
        serviceType: "Nail Trim",
        hasConflict: true
    )
]

// MARK: - Audit/Admin Accessors

public enum AppointmentVM_AuditAdmin {
    public static var lastSummary: String { AppointmentVM_Audit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentVM_Audit.exportLastJSON() }
    /// Provides CSV export of audit logs including detailed audit data.
    public static func exportCSV() -> String {
        AppointmentVM_Audit.exportCSV()
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

struct AppointmentViewModel_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Appointments Preview")
                .font(AppFonts.title)
                .padding(.bottom)

            List {
                ForEach(sampleAppointments) { appointment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(appointment.dogName) - \(appointment.serviceType)")
                            .font(AppFonts.headline)
                        Text("Owner: \(appointment.ownerName)")
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                        Text("Date: \(appointment.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppFonts.caption)
                        if let notes = appointment.notes {
                            Text("Notes: \(notes)")
                                .font(AppFonts.caption2)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        if appointment.hasConflict {
                            Text("⚠️ Conflict detected")
                                .font(AppFonts.caption2)
                                .foregroundColor(AppColors.critical)
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
}
#endif
