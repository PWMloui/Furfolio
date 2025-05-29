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
import os

@MainActor
class AppointmentReminderViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentReminderViewModel")
    @Published var defaultOffset: Int = 24
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    let dogOwners: [DogOwner]
    
    private let feedback = UINotificationFeedbackGenerator()
    
    init(dogOwners: [DogOwner]) {
        self.dogOwners = dogOwners
    }
    
    func schedule(_ appointment: Appointment, for ownerName: String) {
        logger.log("Scheduling reminder for appointment \(appointment.id) for owner: \(ownerName)")
        appointment.scheduleReminder()
        alertMessage = "Reminder set for \(ownerName)"
        feedback.notificationOccurred(.success)
        showAlert = true
        logger.log("Reminder set alert shown: \(alertMessage)")
    }
    
    func cancel(_ appointment: Appointment, for ownerName: String) {
        logger.log("Cancelling reminder for appointment \(appointment.id) for owner: \(ownerName)")
        appointment.cancelReminder()
        alertMessage = "Reminder canceled for \(ownerName)"
        feedback.notificationOccurred(.warning)
        showAlert = true
        logger.log("Cancel alert shown: \(alertMessage)")
    }
}

@MainActor
/// Displays a form for configuring default reminder offsets and per-owner appointment reminders.
struct AppointmentReminderView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentReminderView")
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
                                .foregroundColor(AppTheme.secondaryText)
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
        .onAppear {
            logger.log("AppointmentReminderView appeared with \(viewModel.dogOwners.count) owners")
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
    private let rowLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ReminderRow")
    @Bindable var appointment: Appointment
    let ownerName: String
    let defaultOffset: Int
    @ObservedObject var viewModel: AppointmentReminderViewModel
    
    var body: some View {
        rowLogger.log("ReminderRow displayed for appointment \(appointment.id), isNotified: \(appointment.isNotified)")
        VStack(alignment: .leading) {
            Text("Next: \(appointment.formattedDate)")
                .font(AppTheme.title)
            
            Stepper("\(appointment.reminderOffset)h before", value: $appointment.reminderOffset, in: 1...72)
            
            HStack {
                if !appointment.isNotified {
                    Button("Set Reminder") {
                        rowLogger.log("Set Reminder tapped for appointment \(appointment.id)")
                        viewModel.schedule(appointment, for: ownerName)
                    }
                    .buttonStyle(FurfolioButtonStyle())
                } else {
                    Button("Cancel") {
                        rowLogger.log("Cancel tapped for appointment \(appointment.id)")
                        viewModel.cancel(appointment, for: ownerName)
                    }
                    .buttonStyle(FurfolioButtonStyle())
                    Button("Reschedule") {
                        rowLogger.log("Reschedule tapped for appointment \(appointment.id)")
                        viewModel.schedule(appointment, for: ownerName)
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
