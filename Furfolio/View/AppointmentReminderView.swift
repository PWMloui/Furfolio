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

// TODO: Move reminder logic into a dedicated ViewModel and use NotificationManager for scheduling

@MainActor
/// Displays a form for configuring default reminder offsets and per-owner appointment reminders.
struct AppointmentReminderView: View {
    let dogOwners: [DogOwner]
    @State private var defaultOffset: Int = 24
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let feedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder Settings") {
                    Stepper(
                        "\(defaultOffset)h before",
                        value: $defaultOffset,
                        in: 1...72
                    ) {_ in
                        Text("Default Offset")
                    }
                }
                
                ForEach(dogOwners) { owner in
                    let stats = ClientStats(owner: owner)
                    Section(
                        header: ownerHeader(owner, stats: stats)
                    ) {
                        if let next = nextAppointment(for: owner) {
                            ReminderRow(
                                appointment: next,
                                ownerName: owner.ownerName,
                                defaultOffset: defaultOffset,
                                showAlert: $showAlert,
                                alertMessage: $alertMessage
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
            .alert("Notification", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
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
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    @State private var offset: Int
    
    private let feedback = UINotificationFeedbackGenerator()
    
    init(
        appointment: Appointment,
        ownerName: String,
        defaultOffset: Int,
        showAlert: Binding<Bool>,
        alertMessage: Binding<String>
    ) {
        _appointment = Bindable(wrappedValue: appointment)
        self.ownerName = ownerName
        _showAlert = showAlert
        _alertMessage = alertMessage
        self.defaultOffset = defaultOffset
        _offset = State(initialValue: appointment.reminderOffset)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Next: \(appointment.formattedDate)")
                .font(.headline)
            
            Stepper("\(offset)h before", value: $offset, in: 1...72)
                .onChange(of: offset) { new in
                    appointment.reminderOffset = new
                }
            
            HStack {
                if !appointment.isNotified {
                    Button("Set Reminder", action: schedule)
                } else {
                    Button("Cancel", action: cancel)
                    Button("Reschedule", action: schedule)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Schedules a local notification for the bound appointment.
    private func schedule() {
        appointment.scheduleReminder()
        alertMessage = "Reminder set for \(ownerName)"
        feedback.notificationOccurred(.success)
        showAlert = true
    }
    
    /// Cancels a previously scheduled notification for the bound appointment.
    private func cancel() {
        appointment.cancelReminder()
        alertMessage = "Reminder canceled for \(ownerName)"
        feedback.notificationOccurred(.warning)
        showAlert = true
    }
}
