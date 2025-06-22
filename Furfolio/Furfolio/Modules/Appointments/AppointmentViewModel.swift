//
//  AppointmentViewModel.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - AppointmentViewModel (Tokenized, Modular, Auditable ViewModel)

import Foundation
import SwiftUI
import Combine

@MainActor
/// ViewModel managing upcoming appointments in a tokenized, modular, and auditable way.
/// Supports reactive UI updates, async fetching, and error handling aligned with Furfolio design system.
class AppointmentViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The list of upcoming appointments, published to update UI reactively.
    @Published private(set) var appointments: [Appointment] = []

    /// Error message to display when fetching fails.
    @Published var errorMessage: String?

    /// Loading state indicator for UI feedback.
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    /// Set to hold Combine cancellables for any future publishers.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        Task {
            await fetchUpcomingAppointments()
        }
    }

    // MARK: - Public Methods

    /// Asynchronously fetch upcoming appointments, simulating network or database calls.
    func fetchUpcomingAppointments() async {
        isLoading = true
        errorMessage = nil
        do {
            // Simulate delay for fetching
            try await Task.sleep(nanoseconds: 800_000_000)

            // Fetch appointments (replace with real data fetching logic)
            let upcoming = sampleAppointments.filter { $0.date >= Date() }
            appointments = upcoming.sorted { $0.date < $1.date }
            isLoading = false
        } catch {
            errorMessage = "Failed to load appointments."
            isLoading = false
        }
    }

    /// Adds a new appointment and sorts the list by date.
    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        appointments.sort { $0.date < $1.date }
    }

    /// Deletes appointment matching the given UUID.
    func deleteAppointment(id: UUID) {
        appointments.removeAll { $0.id == id }
    }

    /// Updates an existing appointment, replacing the old one by matching ID.
    func updateAppointment(_ updated: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == updated.id }) else { return }
        appointments[index] = updated
        appointments.sort { $0.date < $1.date }
    }
}

// MARK: - Appointment Model

/// Represents an appointment with tokenization and auditability in mind.
/// This model is Codable for easy serialization and Identifiable for use in SwiftUI lists.
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

/// Sample appointments used for SwiftUI previews and testing purposes.
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

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

struct AppointmentViewModel_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Appointments Preview")
                // Using modular font token for title
                .font(AppFonts.title)
                .padding(.bottom)

            List {
                ForEach(sampleAppointments) { appointment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(appointment.dogName) - \(appointment.serviceType)")
                            // Using modular font token for headline
                            .font(AppFonts.headline)
                        Text("Owner: \(appointment.ownerName)")
                            // Using modular font token for subheadline
                            .font(AppFonts.subheadline)
                            // Using modular color token for secondary text
                            .foregroundColor(AppColors.secondaryText)
                        Text("Date: \(appointment.date.formatted(date: .abbreviated, time: .shortened))")
                            // Using modular font token for caption
                            .font(AppFonts.caption)
                        if let notes = appointment.notes {
                            Text("Notes: \(notes)")
                                // Using modular font token for caption2
                                .font(AppFonts.caption2)
                                // Using modular color token for tertiary text
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        if appointment.hasConflict {
                            Text("⚠️ Conflict detected")
                                // Using modular font token for caption2
                                .font(AppFonts.caption2)
                                // Using modular color token for critical alerts
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
