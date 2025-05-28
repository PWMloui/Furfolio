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

    @StateObject private var vm: AddAppointmentViewModel
    init(dogOwner: DogOwner) {
        self.dogOwner = dogOwner
        _vm = StateObject(wrappedValue: AddAppointmentViewModel(owner: dogOwner))
    }

    // MARK: – Computed
    private var stats: ClientStats { ClientStats(owner: dogOwner) }

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

                    if let warning = vm.conflictWarning {
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
                .alert("Conflict Detected", isPresented: $vm.showConflictAlert) {
                    Button("OK") { vm.conflictWarning = nil }
                } message: {
                    Text(vm.conflictWarning ?? "")
                }

                if vm.isSaving {
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
                selection: $vm.appointmentDate,
                in: Date().addingTimeInterval(60)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: vm.appointmentDate) { _ in vm.conflictWarning = nil }
            .accessibilityLabel("Select appointment date and time")

            Picker("Service Type", selection: $vm.serviceType) {
                ForEach(Appointment.ServiceType.allCases) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Select service type")

            Stepper("Duration: \(vm.appointmentDuration) min", value: $vm.appointmentDuration, in: 15...240, step: 15)
                .accessibilityLabel("Appointment duration in minutes")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Notes (optional)", text: $vm.appointmentNotes)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.sentences)
                    .accessibilityLabel("Enter any extra details (max 250 chars)")

                if showTooltip && vm.appointmentNotes.isEmpty {
                    Text("Enter extra details (max 250 characters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                if vm.appointmentNotes.count > 250 {
                    Text("Notes must be ≤ 250 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Toggle("Link Charge Record", isOn: $vm.linkChargeRecord)
                .accessibilityLabel("Toggle to link a charge record")

            Toggle("Enable Reminder", isOn: $vm.enableReminder)
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
            photoPicker(label: "Before Photo", data: $vm.beforePhotoData, item: .constant(nil))
            photoPicker(label: "After Photo",  data: $vm.afterPhotoData,  item: .constant(nil))
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
            Button("Save") { vm.save { dismiss() } }
                .disabled(vm.isSaving)
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
