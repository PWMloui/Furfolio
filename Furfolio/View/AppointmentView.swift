//
//  AddAppointmentView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 20, 2025 — fully cleaned up trailing‐closure errors and enhanced save logic.
//

import SwiftUI
import UserNotifications
import PhotosUI

// TODO: Move business logic (saving, validation, notifications) into a dedicated ViewModel and use NotificationManager for scheduling.

@MainActor
/// View for adding a new appointment: selects date/time, service type, photos, and optional reminders.
struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dogOwner: DogOwner

    // MARK: – Computed
    private var stats: ClientStats { ClientStats(owner: dogOwner) }

    // MARK: – Form State
    @State private var appointmentDate = Date()
    @State private var serviceType: Appointment.ServiceType = .basic
    @State private var appointmentDuration = Appointment.ServiceType.basic.defaultDurationMinutes
    @State private var appointmentNotes = ""
    @State private var linkChargeRecord = false
    @State private var enableReminder = false

    // MARK: – Conflict & Saving
    @State private var conflictWarning: String? = nil
    @State private var showConflictAlert = false
    @State private var isSaving = false

    // MARK: – Photos
    @State private var beforePhotoData: Data? = nil
    @State private var afterPhotoData: Data? = nil
    @State private var beforePhotoItem: PhotosPickerItem? = nil
    @State private var afterPhotoItem: PhotosPickerItem? = nil

    // MARK: – Feedback & Tooltip
    private let feedback = UINotificationFeedbackGenerator()
    @State private var showTooltip = false

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    /// Displays the appointment details section.
                    appointmentDetailsSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    photosSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    if let warning = conflictWarning {
                        Section(header: Text("")) {
                            Text(warning)
                                .foregroundColor(.red)
                                .italic()
                                .accessibilityLabel("Conflict warning")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Add Appointment")
                .toolbar { toolbarContent() }
                .alert("Conflict Detected", isPresented: $showConflictAlert) {
                    Button("OK") { conflictWarning = nil }
                } message: {
                    Text(conflictWarning ?? "")
                }

                if isSaving {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Saving…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .onAppear {
            Task {
                // Show tooltip on form fields for initial guidance
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation { showTooltip = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { showTooltip = false }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: – Sections

    /// Builds the section for selecting date, service, duration, notes, and toggles.
    @ViewBuilder
    private func appointmentDetailsSection() -> some View {
        Section(header: Text("Appointment Details")) {
            DatePicker(
                "Date & Time",
                selection: $appointmentDate,
                in: Date().addingTimeInterval(60)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: appointmentDate) { _ in conflictWarning = nil }
            .accessibilityLabel("Select appointment date and time")

            Picker("Service Type", selection: $serviceType) {
                ForEach(Appointment.ServiceType.allCases) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: serviceType) { appointmentDuration = $0.defaultDurationMinutes }
            .accessibilityLabel("Select service type")

            Stepper("Duration: \(appointmentDuration) min", value: $appointmentDuration, in: 15...240, step: 15)
                .accessibilityLabel("Appointment duration in minutes")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Notes (optional)", text: $appointmentNotes)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.sentences)
                    .onChange(of: appointmentNotes) { _ in clampNotesLength() }
                    .accessibilityLabel("Enter any extra details (max 250 chars)")

                if showTooltip && appointmentNotes.isEmpty {
                    Text("Enter extra details (max 250 characters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                if appointmentNotes.count > 250 {
                    Text("Notes must be ≤ 250 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Toggle("Link Charge Record", isOn: $linkChargeRecord)
                .accessibilityLabel("Toggle to link a charge record")

            Toggle("Enable Reminder", isOn: $enableReminder)
                .onChange(of: enableReminder) {
                    if $0 { requestNotificationPermission() }
                }
                .accessibilityLabel("Toggle to enable reminder notification")

            if !stats.loyaltyProgressTag.isEmpty {
                HStack {
                    Text("Loyalty Progress"); Spacer()
                    Text(stats.loyaltyProgressTag)
                        .foregroundColor(.green)
                        .font(.caption.bold())
                }
            }
            if let badge = stats.recentBehaviorBadges.first {
                HStack {
                    Text("Behavior"); Spacer()
                    Text(badge)
                        .foregroundColor(.orange)
                        .font(.caption.bold())
                }
            }
        }
    }

    /// Builds the section for picking before/after photos.
    @ViewBuilder
    private func photosSection() -> some View {
        Section(header: Text("Photos")) {
            photoPicker(label: "Before Photo", data: $beforePhotoData, item: $beforePhotoItem)
            photoPicker(label: "After Photo",  data: $afterPhotoData,  item: $afterPhotoItem)
        }
    }

    // MARK: – Photo Picker

    @ViewBuilder
    private func photoPicker(
        label: String,
        data: Binding<Data?>,
        item: Binding<PhotosPickerItem?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            HStack {
                if let d = data.wrappedValue, let img = UIImage(data: d) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                }

                (
                    PhotosPicker(selection: item, matching: .images) {
                        Text("Select")
                    }
                )
                .onChange(of: item.wrappedValue) { new in
                    Task {
                        if let picked = new,
                           let loaded = try? await picked.loadTransferable(type: Data.self)
                        {
                            data.wrappedValue = loaded
                        }
                    }
                }
            }
        }
    }

    // MARK: – Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save", action: handleSave)
                .disabled(!validateAppointment() || isSaving)
        }
    }

    // MARK: – Save Handling

    /// Validates and, if valid, saves the appointment and dismisses the view.
    private func handleSave() {
        guard validateAppointment() else {
            showConflictAlert = true
            return
        }
        isSaving = true
        feedback.notificationOccurred(.success)
        saveAppointment()

        // bind the Task so it's not mis‐parsed
        _ = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isSaving = false
            dismiss()
        }
    }

    /// Inserts the new Appointment into the model context and links a charge if requested.
    private func saveAppointment() {
        let appt = Appointment(
            date: appointmentDate,
            dogOwner: dogOwner,
            serviceType: serviceType,
            notes: appointmentNotes,
            beforePhoto: beforePhotoData,
            afterPhoto: afterPhotoData
        )
        appt.durationMinutes = appointmentDuration

        withAnimation {
            modelContext.insert(appt)
            if linkChargeRecord {
                let charge = Charge.create(
                    date: appointmentDate,
                    serviceType: .custom,
                    amount: 0,
                    paymentMethod: .cash,
                    owner: dogOwner,
                    notes: "Linked to appointment",
                    appointment: appt,
                    in: modelContext
                )
                print("Linked charge \(charge.id) to appointment")
            }
        }

        if enableReminder {
            scheduleReminder(for: appt)
        }
    }

    // MARK: – Validation & Conflict

    /// Checks date validity and appointment conflict; sets conflictWarning if invalid.
    private func validateAppointment() -> Bool {
        guard appointmentDate > Date.now else {
            conflictWarning = "Appointment must be in the future."
            return false
        }
        if dogOwner.appointments.contains(where: {
            abs($0.date.timeIntervalSince(appointmentDate)) < 3600
        }) {
            conflictWarning = "This appointment conflicts with another."
            return false
        }
        return true
    }

    // MARK: – Notifications

    /// Schedules a local notification reminder via NotificationManager.
    private func scheduleReminder(for appointment: Appointment) {
        var content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.body = "\(dogOwner.ownerName) at \(appointment.formattedDate)"
        content.sound = .default

        guard let triggerDate = Calendar.current.date(byAdding: .minute,
                                                      value: -30,
                                                      to: appointment.date)
        else { return }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let req = UNNotificationRequest(
            identifier: appointment.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }

    /// Requests UNUserNotificationCenter authorization for alerts and sounds.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted { enableReminder = false }
        }
    }

    // MARK: – Utilities

    /// Ensures the notes string does not exceed 250 characters.
    private func clampNotesLength() {
        if appointmentNotes.count > 250 {
            appointmentNotes = String(appointmentNotes.prefix(250))
        }
    }
}

// MARK: – Nested ServiceType enhancements

extension Appointment.ServiceType {
    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }
    var defaultDurationMinutes: Int {
        switch self {
        case .basic:  return 60
        case .full:   return 90
        case .custom: return 0
        }
    }
}
