//
//  AddAppointmentView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, improved alert binding, modern async state handling, and enhanced accessibility.

import SwiftUI
import UserNotifications
import PhotosUI

struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dogOwner: DogOwner

    @State private var appointmentDate = Date()
    @State private var serviceType: Appointment.ServiceType = .basic
    @State private var appointmentNotes = ""
    @State private var conflictWarning: String? = nil
    @State private var showConflictAlert = false
    @State private var isSaving = false
    @State private var enableReminder = false
    @State private var linkChargeRecord = false  // Toggle for linking a charge record

    @State private var appointmentDuration = 60

    @State private var beforePhotoData: Data? = nil
    @State private var afterPhotoData: Data? = nil

    // For haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // For onboarding tooltip display
    @State private var showTooltip = false

    @State private var beforePhotoItem: PhotosPickerItem? = nil
    @State private var afterPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    appointmentDetailsSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    photosSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    // Optionally display conflict warning text inside the form.
                    if let conflictWarning = conflictWarning, !conflictWarning.isEmpty {
                        conflictWarningSection(conflictWarning)
                    }
                }
                .navigationTitle(NSLocalizedString("Add Appointment", comment: "Navigation title for Add Appointment view"))
                .toolbar { toolbarContent() }
                // Dynamic alert when a conflict is detected.
                .alert(isPresented: $showConflictAlert) {
                    Alert(
                        title: Text(NSLocalizedString("Conflict Detected", comment: "Alert title for conflict detection")),
                        message: Text(conflictWarning ?? ""),
                        dismissButton: .default(Text(NSLocalizedString("OK", comment: "Alert confirmation button")), action: {
                            // Reset conflict warning after dismissal.
                            conflictWarning = nil
                        })
                    )
                }
                
                // Progress overlay while saving.
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
                // Show an onboarding tooltip for a few seconds when the view appears.
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    withAnimation { showTooltip = true }
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // Show for 3 seconds
                    withAnimation { showTooltip = false }
                }
            }
        }
        .accessibilityElement(children: .contain)
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
            .accessibilityLabel(NSLocalizedString("Select appointment date", comment: "Accessibility label for date picker"))
            
            Picker(
                NSLocalizedString("Service Type", comment: "Picker for selecting service type"),
                selection: $serviceType
            ) {
                ForEach(Appointment.ServiceType.allCases, id: \.self) { type in
                    Text(type.localized)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .accessibilityLabel(NSLocalizedString("Select service type", comment: "Accessibility label for service type picker"))
            
            Stepper(
                value: $appointmentDuration,
                in: 15...240,
                step: 15
            ) {
                Text("Duration: \(appointmentDuration) minutes")
            }
            .accessibilityLabel("Appointment duration")
            
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    NSLocalizedString("Notes (Optional)", comment: "Placeholder for appointment notes"),
                    text: $appointmentNotes
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.sentences)
                .onChange(of: appointmentNotes) { _ in limitNotesLength() }
                .accessibilityLabel(NSLocalizedString("Enter additional notes", comment: "Accessibility label for notes field"))
                
                if showTooltip && appointmentNotes.isEmpty {
                    Text(NSLocalizedString("Enter any extra details (max 250 characters)", comment: "Tooltip for additional notes"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            
            Toggle(
                NSLocalizedString("Enable Reminder", comment: "Toggle for enabling reminders"),
                isOn: $enableReminder
            )
            .onChange(of: enableReminder) { isOn in
                if isOn { requestNotificationPermission() }
            }
            .accessibilityLabel(NSLocalizedString("Toggle to enable appointment reminder", comment: "Accessibility label for reminder toggle"))
            
            // Optional toggle to link a charge record.
            Toggle(
                NSLocalizedString("Link Charge Record", comment: "Toggle for linking a charge record"),
                isOn: $linkChargeRecord
            )
            .accessibilityLabel(NSLocalizedString("Toggle to link a charge record", comment: "Accessibility label for charge record linking toggle"))
        }
    }
    
    @ViewBuilder
    private func photosSection() -> some View {
        Section(header: Text(NSLocalizedString("Photos", comment: "Section header for photos"))) {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("Before Photo", comment: "Label for before photo picker"))
                    .font(.headline)
                HStack {
                    if let data = beforePhotoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel(NSLocalizedString("Before photo preview", comment: "Accessibility label for before photo preview"))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                            .accessibilityLabel(NSLocalizedString("No before photo selected", comment: "Accessibility label for no before photo"))
                    }
                    PhotosPicker(
                        selection: $beforePhotoItem,
                        matching: .images,
                        photoLibrary: .shared()) {
                            Text(NSLocalizedString("Select Before Photo", comment: "Button label for selecting before photo"))
                    }
                    .onChange(of: beforePhotoItem) { newItem in
                        Task {
                            if let item = newItem {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    beforePhotoData = data
                                }
                            }
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("Select before photo", comment: "Accessibility label for before photo picker"))
                }
            }
            
            VStack(alignment: .leading) {
                Text(NSLocalizedString("After Photo", comment: "Label for after photo picker"))
                    .font(.headline)
                HStack {
                    if let data = afterPhotoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel(NSLocalizedString("After photo preview", comment: "Accessibility label for after photo preview"))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                            .accessibilityLabel(NSLocalizedString("No after photo selected", comment: "Accessibility label for no after photo"))
                    }
                    PhotosPicker(
                        selection: $afterPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()) {
                            Text(NSLocalizedString("Select After Photo", comment: "Button label for selecting after photo"))
                    }
                    .onChange(of: afterPhotoItem) { newItem in
                        Task {
                            if let item = newItem {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    afterPhotoData = data
                                }
                            }
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("Select after photo", comment: "Accessibility label for after photo picker"))
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
                .accessibilityLabel(NSLocalizedString("Conflict warning", comment: "Accessibility label for conflict warning"))
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                withAnimation { dismiss() }
            }
            .accessibilityLabel(NSLocalizedString("Cancel appointment creation", comment: "Accessibility label for cancel button"))
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(NSLocalizedString("Save", comment: "Save button")) {
                handleSave()
            }
            .disabled(!validateFields() || isSaving)
            .accessibilityLabel(NSLocalizedString("Save appointment", comment: "Accessibility label for save button"))
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
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                withAnimation {
                    isSaving = false
                    dismiss()
                }
            }
        } else {
            showConflictAlert = true
        }
    }
    
    /// Saves the appointment to the model context.
    private func saveAppointment() {
        let newAppointment = Appointment(
            date: appointmentDate,
            dogOwner: dogOwner,
            serviceType: serviceType,
            notes: appointmentNotes,
            beforePhoto: beforePhotoData,
            afterPhoto: afterPhotoData
        )
        newAppointment.durationMinutes = appointmentDuration
        
        // If linking a charge record is enabled, add logic here.
        if linkChargeRecord {
            // Placeholder: Implement charge record linking logic here.
            print("Link Charge Record is enabled. Implement charge record linking logic here.")
        }
        
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
        return appointmentDate > Date()
    }
    
    /// Checks for conflicting appointments within a 1-hour buffer.
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
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
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
