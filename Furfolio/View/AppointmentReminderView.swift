//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, haptic feedback, enhanced transitions, customizable reminder offset, and rescheduling options.

import SwiftUI
import UserNotifications

// Define a shared DateFormatter to be used globally.
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
    
    // Customizable reminder offset in hours (default is 24)
    @State private var reminderOffset: Int = 24

    // Haptic feedback generator for notification events.
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            List {
                // Global Reminder Settings Section
                Section(header: Text(NSLocalizedString("Reminder Settings", comment: "Section header for reminder settings"))) {
                    HStack {
                        Text(String(format: NSLocalizedString("Remind me %d hours before appointment", comment: "Reminder offset label"), reminderOffset))
                        Spacer()
                        Stepper(value: $reminderOffset, in: 1...48) {
                            Text("\(reminderOffset)h")
                        }
                        .accessibilityLabel(NSLocalizedString("Reminder offset stepper", comment: "Accessibility label for reminder offset stepper"))
                    }
                }
                
                // For each dog owner, display a reminder row if they have a next appointment.
                ForEach(dogOwners) { owner in
                    if let nextAppointment = owner.nextAppointment {
                        let statusTags = [
                            owner.hasBirthdayThisMonth ? "🎂 Birthday" : nil,
                            owner.retentionRisk ? "⚠️ Retention Risk" : nil,
                            owner.lifetimeValueTag
                        ].compactMap { $0 }.joined(separator: " ")

                        Section(header: Text("\(owner.ownerName) \(owner.loyaltyStatus) \(statusTags)")) {
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
            .onAppear {
                // Register a notification category for interactive notifications.
                let rescheduleAction = UNNotificationAction(
                    identifier: "RESCHEDULE_ACTION",
                    title: NSLocalizedString("Reschedule", comment: "Reschedule action title"),
                    options: []
                )
                let category = UNNotificationCategory(
                    identifier: "APPOINTMENT_REMINDER",
                    actions: [rescheduleAction],
                    intentIdentifiers: [],
                    options: []
                )
                UNUserNotificationCenter.current().setNotificationCategories([category])
            }
        }
    }
    
    // MARK: - Reminder Row
    
    /// Generates a row for an appointment reminder.
    private func reminderRow(for appointment: Appointment, owner: DogOwner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            appointmentDetailsText(for: appointment)
            
            if let notes = appointment.notes, !notes.isEmpty {
                appointmentNotesText(notes)
            }
            
            reminderTimingText()
            
            // HStack with both Set and Resend Reminder buttons.
            HStack(spacing: 16) {
                Button(NSLocalizedString("Set Reminder", comment: "Button label to set reminder")) {
                    scheduleAppointmentReminder(for: appointment, owner: owner)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canScheduleReminder(for: appointment))
                .opacity(canScheduleReminder(for: appointment) ? 1.0 : 0.5)
                .accessibilityLabel(NSLocalizedString("Set reminder button", comment: "Accessibility label for set reminder button"))
                
                Button(NSLocalizedString("Resend Reminder", comment: "Button label to resend reminder")) {
                    scheduleAppointmentReminder(for: appointment, owner: owner)
                }
                .buttonStyle(.bordered)
                .disabled(!canScheduleReminder(for: appointment))
                .opacity(canScheduleReminder(for: appointment) ? 1.0 : 0.5)
                .accessibilityLabel(NSLocalizedString("Resend reminder button", comment: "Accessibility label for resend reminder button"))
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Components
    
    /// Displays appointment details.
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
    
    /// Displays appointment notes.
    @ViewBuilder
    private func appointmentNotesText(_ notes: String) -> some View {
        Text(
            String(format: NSLocalizedString("Notes: %@", comment: "Label for appointment notes"), notes)
        )
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    /// Displays the reminder timing.
    @ViewBuilder
    private func reminderTimingText() -> some View {
        Text(String(format: NSLocalizedString("Reminder: %d hours before appointment", comment: "Reminder timing message"), reminderOffset))
            .font(.caption)
            .foregroundColor(.gray)
    }
    
    /// Displays a message when no upcoming appointments exist.
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
    
    /// Schedules a notification reminder for a given appointment.
    private func scheduleAppointmentReminder(for appointment: Appointment, owner: DogOwner) {
        // Calculate trigger date by subtracting the reminder offset (in hours) from the appointment date.
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -reminderOffset, to: appointment.date),
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
        content.categoryIdentifier = "APPOINTMENT_REMINDER" // Set the notification category for interactive actions.
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
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
                    feedbackGenerator.notificationOccurred(.error)
                } else {
                    alertMessage = String(
                        format: NSLocalizedString(
                            "Reminder successfully scheduled for %@'s appointment.",
                            comment: "Success message for scheduling reminder"
                        ),
                        owner.ownerName
                    )
                    feedbackGenerator.notificationOccurred(.success)
                }
                showAlert = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines whether a reminder can be scheduled for the given appointment.
    private func canScheduleReminder(for appointment: Appointment) -> Bool {
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -reminderOffset, to: appointment.date) else {
            return false
        }
        return triggerDate > Date()
    }
}
