//
//  AddAppointmentView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, haptic feedback, and enhanced user feedback.

import SwiftUI
import UserNotifications

struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dogOwner: DogOwner

    @State private var appointmentDate = Date()
    @State private var serviceType: Appointment.ServiceType = .basic
    @State private var appointmentNotes = ""
    @State private var conflictWarning: String? = nil
    @State private var isSaving = false
    @State private var enableReminder = false
    
    // For haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // For onboarding tooltip display
    @State private var showTooltip = false

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    appointmentDetailsSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    if let conflictWarning = conflictWarning {
                        conflictWarningSection(conflictWarning)
                    }
                }
                .navigationTitle(NSLocalizedString("Add Appointment", comment: "Navigation title for Add Appointment view"))
                .toolbar { toolbarContent() }
                .alert(
                    NSLocalizedString("Conflict Detected", comment: "Alert title for conflict detection"),
                    isPresented: .constant(conflictWarning != nil)
                ) {
                    Button(NSLocalizedString("OK", comment: "Alert confirmation button"), role: .cancel) {}
                } message: {
                    Text(conflictWarning ?? "")
                }
                
                // Progress overlay while saving
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView(NSLocalizedString("Saving...", comment: "Progress indicator while saving"))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                }
            }
            .onAppear {
                // Display a tooltip for onboarding when the view appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showTooltip = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showTooltip = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private func appointmentDetailsSection() -> some View {
        Section(header: Text(NSLocalizedString("Appointment Details", comment: "Section header for appointment details"))) {
            DatePicker(
                NSLocalizedString("Appointment Date", comment: "Picker for appointment date"),
                selection: $appointmentDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: appointmentDate) { _ in
                conflictWarning = nil
            }
            
            Picker(
                NSLocalizedString("Service Type", comment: "Picker for selecting service type"),
                selection: $serviceType
            ) {
                ForEach(Appointment.ServiceType.allCases, id: \.self) { type in
                    Text(type.localized)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    NSLocalizedString("Notes (Optional)", comment: "Placeholder for appointment notes"),
                    text: $appointmentNotes
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.sentences)
                .onChange(of: appointmentNotes) { _ in
                    limitNotesLength()
                }
                
                if showTooltip && appointmentNotes.isEmpty {
                    Text(NSLocalizedString("Enter any extra details (max 250 characters)", comment: "Tooltip for additional notes"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            
            Toggle(
                NSLocalizedString("Enable Reminder", comment: "Toggle for enabling reminders"),
                isOn: $enableReminder
            )
            .onChange(of: enableReminder) { isOn in
                if isOn {
                    requestNotificationPermission()
                }
            }
        }
    }
    
    @ViewBuilder
    private func conflictWarningSection(_ conflictWarning: String) -> some View {
        Section {
            Text(conflictWarning)
                .foregroundColor(.red)
                .italic()
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                withAnimation {
                    dismiss()
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(NSLocalizedString("Save", comment: "Save button")) {
                handleSave()
            }
            .disabled(!validateFields() || isSaving)
        }
    }
    
    // MARK: - Save Handling
    
    private func handleSave() {
        if validateAppointment() {
            isSaving = true
            feedbackGenerator.notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.3)) {
                saveAppointment()
            }
            // Simulate a short delay for saving actions (allowing animations to finish)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                dismiss()
            }
        }
    }
    
    /// Saves the appointment to the model context.
    private func saveAppointment() {
        let newAppointment = Appointment(
            date: appointmentDate,
            dogOwner: dogOwner,
            serviceType: serviceType,
            notes: appointmentNotes
        )
        
        withAnimation {
            modelContext.insert(newAppointment)
            dogOwner.appointments.append(newAppointment)
        }
        
        if enableReminder {
            scheduleReminder(for: newAppointment)
        }
        
        print("Appointment saved for \(dogOwner.ownerName) on \(newAppointment.formattedDate)")
    }
    
    // MARK: - Validation
    
    /// Validates the appointment and checks for conflicts.
    private func validateAppointment() -> Bool {
        guard validateFields() else { return false }
        
        if !checkConflicts() {
            conflictWarning = NSLocalizedString(
                "This appointment conflicts with another!",
                comment: "Conflict warning message"
            )
            return false
        }
        
        return true
    }
    
    /// Ensures required fields are valid.
    private func validateFields() -> Bool {
        appointmentDate > Date()
    }
    
    /// Checks for conflicting appointments (within a 1-hour buffer).
    private func checkConflicts() -> Bool {
        !dogOwner.appointments.contains {
            abs($0.date.timeIntervalSince(appointmentDate)) < 3600
        }
    }
    
    // MARK: - Reminder Management
    
    /// Schedules a reminder notification for the appointment.
    private func scheduleReminder(for appointment: Appointment) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Upcoming Appointment", comment: "Reminder title")
        content.body = String(
            format: NSLocalizedString("Appointment with %@ on %@", comment: "Reminder body"),
            dogOwner.ownerName,
            appointment.formattedDate
        )
        content.sound = .default
        
        guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -30, to: appointment.date) else { return }
        
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
            if let error = error {
                print("Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }
    
    /// Requests notification permission from the user.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            
            if !granted {
                enableReminder = false
                print("User denied notification permissions.")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Limits the length of appointment notes to 250 characters.
    private func limitNotesLength() {
        if appointmentNotes.count > 250 {
            appointmentNotes = String(appointmentNotes.prefix(250))
        }
    }
}
