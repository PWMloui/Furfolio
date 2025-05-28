//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 15, 2025 — fixed Section init and model binding.
//

import SwiftUI
import UserNotifications
import SwiftData

@MainActor
class AppointmentReminderViewModel: ObservableObject {
    @Published var defaultOffset: Int = 24
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    let dogOwners: [DogOwner]
    
    private let feedback = UINotificationFeedbackGenerator()
    
    init(dogOwners: [DogOwner]) {
        self.dogOwners = dogOwners
    }
    
    func schedule(_ appointment: Appointment, for ownerName: String) {
        appointment.scheduleReminder()
        alertMessage = "Reminder set for \(ownerName)"
        feedback.notificationOccurred(.success)
        showAlert = true
    }
    
    func cancel(_ appointment: Appointment, for ownerName: String) {
        appointment.cancelReminder()
        alertMessage = "Reminder canceled for \(ownerName)"
        feedback.notificationOccurred(.warning)
        showAlert = true
    }
}

@MainActor
/// Displays a form for configuring default reminder offsets and per-owner appointment reminders.
struct AppointmentReminderView: View {
    @StateObject private var viewModel: AppointmentReminderViewModel
    
    init(dogOwners: [DogOwner]) {
        _viewModel = StateObject(wrappedValue: AppointmentReminderViewModel(dogOwners: dogOwners))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder Settings") {
                    Stepper(
                        "\(viewModel.defaultOffset)h before",
                        value: $viewModel.defaultOffset,
                        in: 1...72
                    ) {_ in
                        Text("Default Offset")
                    }
                }
                
                ForEach(viewModel.dogOwners) { owner in
                    let stats = ClientStats(owner: owner)
                    Section(
                        header: ownerHeader(owner, stats: stats)
                    ) {
                        if let next = nextAppointment(for: owner) {
                            ReminderRow(
                                appointment: next,
                                ownerName: owner.ownerName,
                                defaultOffset: viewModel.defaultOffset,
                                viewModel: viewModel
                            )
                        } else {
                            Text("No upcoming appointments.")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appointment Reminders")
            .alert("Notification", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
    
    /// Returns the next upcoming appointment for the specified owner, or nil if none.
    private func nextAppointment(for owner: DogOwner) -> Appointment? {
        owner.appointments
            .filter { $0.date > Date.now }
            .min(by: { $0.date < $1.date })
    }
    
    /// Constructs the header view text for an owner, including loyalty and birthday badges.
    private func ownerHeader(_ owner: DogOwner, stats: ClientStats) -> some View {
        let badges = [
            stats.hasBirthdayThisMonth ? "🎂" : nil,
            stats.isRetentionRisk      ? "⚠️" : nil,
            stats.isTopSpender         ? "🏆" : nil
        ].compactMap { $0 }.joined(separator: " ")
        
        return Text("\(owner.ownerName) — \(stats.loyaltyStatus)\(badges.isEmpty ? "" : " \(badges)")")
            .font(.subheadline)
    }
}

@MainActor
/// A row showing a single appointment reminder with offset controls and action buttons.
private struct ReminderRow: View {
    @Bindable var appointment: Appointment
    let ownerName: String
    let defaultOffset: Int
    @ObservedObject var viewModel: AppointmentReminderViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Next: \(appointment.formattedDate)")
                .font(.headline)
            
            Stepper("\(appointment.reminderOffset)h before", value: $appointment.reminderOffset, in: 1...72)
            
            HStack {
                if !appointment.isNotified {
                    Button("Set Reminder") { viewModel.schedule(appointment, for: ownerName) }
                } else {
                    Button("Cancel") { viewModel.cancel(appointment, for: ownerName) }
                    Button("Reschedule") { viewModel.schedule(appointment, for: ownerName) }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
