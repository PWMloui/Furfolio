//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, haptic feedback, and enhanced transitions.

import SwiftUI
import UserNotifications

// Define a shared DateFormatter to be used globally
private let globalAppointmentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct AppointmentReminderView: View {
    let dogOwners: [DogOwner]
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Haptic feedback generator for notification events.
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(dogOwners) { owner in
                    if let nextAppointment = owner.nextAppointment {
                        Section(header: Text(owner.ownerName)) {
                            reminderRow(for: nextAppointment, owner: owner)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    } else {
                        noUpcomingAppointmentsRow(for: owner)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut, value: dogOwners)
            .navigationTitle(NSLocalizedString("Appointment Reminders", comment: "Navigation title for Appointment Reminder view"))
            .alert(
                NSLocalizedString("Notification Status", comment: "Alert title for notification status"),
                isPresented: $showAlert
            ) {
                Button(NSLocalizedString("OK", comment: "Button label for OK"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Reminder Row
    
    /// Generates a row for the reminder
    private func reminderRow(for appointment: Appointment, owner: DogOwner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            appointmentDetailsText(for: appointment)
            
            if let notes = appointment.notes, !notes.isEmpty {
                appointmentNotesText(notes)
            }
            
            reminderTimingText()
            
            reminderButton(for: appointment, owner: owner)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func appointmentDetailsText(for appointment: Appointment) -> some View {
        Text(
            String(
                format: NSLocalizedString("Next Appointment: %@", comment: "Label for next appointment date"),
                globalAppointmentDateFormatter.string(from: appointment.date)
            )
        )
        .font(.subheadline)
    }
    
    @ViewBuilder
    private func appointmentNotesText(_ notes: String) -> some View {
        Text(
            String(format: NSLocalizedString("Notes: %@", comment: "Label for appointment notes"), notes)
        )
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func reminderTimingText() -> some View {
        Text(NSLocalizedString("Reminder: 24 hours before appointment", comment: "Reminder timing message"))
            .font(.caption)
            .foregroundColor(.gray)
    }
    
    @ViewBuilder
    private func reminderButton(for appointment: Appointment, owner: DogOwner) -> some View {
        Button(NSLocalizedString("Set Reminder", comment: "Button label to set reminder")) {
            scheduleAppointmentReminder(for: appointment, owner: owner)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canScheduleReminder(for: appointment))
        .opacity(canScheduleReminder(for: appointment) ? 1.0 : 0.5)
        .accessibilityLabel(NSLocalizedString("Set reminder button", comment: "Accessibility label for set reminder button"))
    }
    
    @ViewBuilder
    private func noUpcomingAppointmentsRow(for owner: DogOwner) -> some View {
        Text(
            String(
                format: NSLocalizedString("%@ has no upcoming appointments.", comment: "Message for no upcoming appointments"),
                owner.ownerName
            )
        )
        .font(.subheadline)
        .foregroundColor(.secondary)
        .accessibilityLabel(NSLocalizedString("No upcoming appointments", comment: "Accessibility label for no appointments"))
    }
    
    // MARK: - Reminder Scheduling
    
    /// Schedules a notification reminder for the given appointment
    private func scheduleAppointmentReminder(for appointment: Appointment, owner: DogOwner) {
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: appointment.date),
              triggerDate > Date() else {
            alertMessage = NSLocalizedString(
                "The appointment is too soon to schedule a reminder.",
                comment: "Error message for scheduling reminder too close to appointment time"
            )
            feedbackGenerator.notificationOccurred(.error)
            showAlert = true
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Upcoming Appointment", comment: "Notification title for upcoming appointment")
        content.body = String(
            format: NSLocalizedString(
                "You have an appointment with %@ for %@ on %@.",
                comment: "Notification body for upcoming appointment"
            ),
            owner.ownerName,
            owner.dogName,
            globalAppointmentDateFormatter.string(from: appointment.date)
        )
        if let notes = appointment.notes, !notes.isEmpty {
            content.body += String(format: NSLocalizedString(" Notes: %@", comment: "Additional notes for appointment"), notes)
        }
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = String(
                        format: NSLocalizedString(
                            "Failed to schedule notification: %@",
                            comment: "Error message for failed notification scheduling"
                        ),
                        error.localizedDescription
                    )
                    self.feedbackGenerator.notificationOccurred(.error)
                } else {
                    alertMessage = String(
                        format: NSLocalizedString(
                            "Reminder successfully scheduled for %@'s appointment.",
                            comment: "Success message for scheduling reminder"
                        ),
                        owner.ownerName
                    )
                    self.feedbackGenerator.notificationOccurred(.success)
                }
                showAlert = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a reminder can be scheduled for the given appointment
    private func canScheduleReminder(for appointment: Appointment) -> Bool {
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: appointment.date) else {
            return false
        }
        return triggerDate > Date()
    }
}
