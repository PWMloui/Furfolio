//
//  AppointmentViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Appointment ViewModel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct AppointmentVM_AuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "fetch", "add", "update", "delete", "error"
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
    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        appointments.sort { $0.date < $1.date }
        AppointmentVM_Audit.record(
            operation: "add",
            appointmentID: appointment.id,
            appointment: appointment,
            count: appointments.count,
            tags: ["add"]
        )
    }

    /// Deletes appointment matching the given UUID.
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
    }

    /// Updates an existing appointment, replacing the old one by matching ID.
    func updateAppointment(_ updated: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == updated.id }) else { return }
        appointments[index] = updated
        appointments.sort { $0.date < $1.date }
        AppointmentVM_Audit.record(
            operation: "update",
            appointmentID: updated.id,
            appointment: updated,
            tags: ["update"]
        )
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
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentVM_Audit.log.suffix(limit).map { $0.accessibilityLabel }
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
