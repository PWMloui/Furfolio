// MARK: - AddAppointmentView (Tokenized, Modular, Auditable Appointment Entry UI)
//
//  AddAppointmentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated, enhanced, and unified for next-gen Furfolio by ChatGPT
//
//  This view and its ViewModel are fully modular, tokenized, and auditable.
//  They support owner-focused workflows, accessibility, localization,
//  business analytics, and UI design system integration.
//

import SwiftUI

fileprivate struct AppointmentAuditEvent: Codable {
    let timestamp: Date
    let operation: String           // "fieldEdit", "saveAttempt", "saveSuccess", "saveFailure", etc.
    let date: Date?
    let owner: String?
    let dog: String?
    let service: String?
    let duration: Int?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let who = [owner, dog].compactMap { $0 }.joined(separator: "/")
        let what = [service].compactMap { $0 }.joined(separator: ", ")
        let dur = duration.map { "\($0)min" } ?? ""
        let tgs = tags.joined(separator: ",")
        let msg = detail ?? ""
        return "[\(op)] \(dateStr) \(who) \(what) \(dur) [\(tgs)]\(msg.isEmpty ? "" : ": \(msg)")"
    }
}

fileprivate final class AppointmentAudit {
    static private(set) var log: [AppointmentAuditEvent] = []

    static func record(
        operation: String,
        date: Date? = nil,
        owner: String? = nil,
        dog: String? = nil,
        service: String? = nil,
        duration: Int? = nil,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AddAppointmentView",
        detail: String? = nil
    ) {
        let event = AppointmentAuditEvent(
            timestamp: Date(),
            operation: operation,
            date: date,
            owner: owner,
            dog: dog,
            service: service,
            duration: duration,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No appointment entry events recorded."
    }
}
// MARK: - AddAppointmentView

struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AddAppointmentViewModel

    // State
    @State private var selectedDate: Date = Date()
    @State private var selectedOwner: DogOwner?
    @State private var selectedDog: Dog?
    @State private var selectedServiceType: String = ""
    @State private var notes: String = ""
    @State private var estimatedDuration: Int = 60 // in minutes
    @State private var showDurationPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date & Time").font(AppFonts.headline)) {
                    DatePicker("Appointment Date", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("appointmentDatePicker")
                        .onChange(of: selectedDate) { newVal in
                            AppointmentAudit.record(
                                operation: "fieldEdit",
                                date: newVal,
                                owner: selectedOwner?.ownerName,
                                dog: selectedDog?.name,
                                service: selectedServiceType,
                                duration: estimatedDuration,
                                tags: ["field", "date"],
                                detail: "Date changed"
                            )
                        }
                }

                Section(header: Text("Client").font(AppFonts.headline)) {
                    Picker("Owner", selection: $selectedOwner) {
                        Text("Select Owner").tag(DogOwner?.none)
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .accessibilityIdentifier("ownerPicker")
                    .onChange(of: selectedOwner) { newOwner in
                        if selectedDog?.ownerID != newOwner?.id {
                            selectedDog = nil
                        }
                        AppointmentAudit.record(
                            operation: "fieldEdit",
                            date: selectedDate,
                            owner: newOwner?.ownerName,
                            dog: selectedDog?.name,
                            service: selectedServiceType,
                            duration: estimatedDuration,
                            tags: ["field", "owner"],
                            detail: "Owner changed"
                        )
                    }

                    if let owner = selectedOwner, let dogs = owner.dogs, !dogs.isEmpty {
                        Picker("Dog", selection: $selectedDog) {
                            Text("Select Dog").tag(Dog?.none)
                            ForEach(dogs) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .accessibilityIdentifier("dogPicker")
                        .onChange(of: selectedDog) { newDog in
                            AppointmentAudit.record(
                                operation: "fieldEdit",
                                date: selectedDate,
                                owner: selectedOwner?.ownerName,
                                dog: newDog?.name,
                                service: selectedServiceType,
                                duration: estimatedDuration,
                                tags: ["field", "dog"],
                                detail: "Dog changed"
                            )
                        }
                    } else if selectedOwner != nil {
                        Text("No dogs found for this owner.")
                            .foregroundColor(AppColors.secondaryText)
                            .font(AppFonts.body)
                    }
                }

                Section(header: Text("Service").font(AppFonts.headline)) {
                    Picker("Service Type", selection: $selectedServiceType) {
                        ForEach(viewModel.serviceTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                    .accessibilityIdentifier("serviceTypePicker")
                    .onChange(of: selectedServiceType) { newService in
                        AppointmentAudit.record(
                            operation: "fieldEdit",
                            date: selectedDate,
                            owner: selectedOwner?.ownerName,
                            dog: selectedDog?.name,
                            service: newService,
                            duration: estimatedDuration,
                            tags: ["field", "service"],
                            detail: "Service changed"
                        )
                    }
                }

                Section(header: Text("Duration").font(AppFonts.headline)) {
                    HStack {
                        Text("\(estimatedDuration) min")
                            .font(AppFonts.body)
                        Spacer()
                        Button("Change") {
                            showDurationPicker = true
                            AppointmentAudit.record(
                                operation: "fieldEdit",
                                date: selectedDate,
                                owner: selectedOwner?.ownerName,
                                dog: selectedDog?.name,
                                service: selectedServiceType,
                                duration: estimatedDuration,
                                tags: ["field", "duration"],
                                detail: "Duration picker opened"
                            )
                        }
                        .accessibilityIdentifier("changeDurationButton")
                        .font(AppFonts.body)
                    }
                    .padding(.vertical, AppSpacing.small)
                }

                Section(header: Text("Notes").font(AppFonts.headline)) {
                    TextField("Add special notes or preferences...", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("notesField")
                        .font(AppFonts.body)
                        .onChange(of: notes) { newNotes in
                            AppointmentAudit.record(
                                operation: "fieldEdit",
                                date: selectedDate,
                                owner: selectedOwner?.ownerName,
                                dog: selectedDog?.name,
                                service: selectedServiceType,
                                duration: estimatedDuration,
                                tags: ["field", "notes"],
                                detail: "Notes edited"
                            )
                        }
                }

                if !viewModel.availableTags.isEmpty {
                    Section(header: Text("Tags").font(AppFonts.headline)) {
                        FlowLayout(alignment: .leading, spacing: AppSpacing.small) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                Button(action: {
                                    viewModel.toggleTag(tag)
                                    AppointmentAudit.record(
                                        operation: "fieldEdit",
                                        date: selectedDate,
                                        owner: selectedOwner?.ownerName,
                                        dog: selectedDog?.name,
                                        service: selectedServiceType,
                                        duration: estimatedDuration,
                                        tags: ["field", "tag", tag],
                                        detail: "Tag toggled"
                                    )
                                }) {
                                    Text(tag)
                                        .padding(.horizontal, AppSpacing.medium)
                                        .padding(.vertical, AppSpacing.small)
                                        .background(viewModel.selectedTags.contains(tag) ? AppColors.accent : AppColors.backgroundSecondary)
                                        .foregroundColor(viewModel.selectedTags.contains(tag) ? AppColors.textOnAccent : AppColors.textPrimary)
                                        .clipShape(Capsule())
                                        .font(AppFonts.body)
                                }
                                .accessibilityIdentifier("tagButton_\(tag)")
                            }
                        }
                        .padding(.vertical, AppSpacing.small)
                    }
                }
            }
            .navigationTitle("New Appointment")
            .font(AppFonts.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        AppointmentAudit.record(
                            operation: "saveAttempt",
                            date: selectedDate,
                            owner: selectedOwner?.ownerName,
                            dog: selectedDog?.name,
                            service: selectedServiceType,
                            duration: estimatedDuration,
                            tags: Array(viewModel.selectedTags),
                            detail: "Save tapped"
                        )
                        if validateAndSave() {
                            AppointmentAudit.record(
                                operation: "saveSuccess",
                                date: selectedDate,
                                owner: selectedOwner?.ownerName,
                                dog: selectedDog?.name,
                                service: selectedServiceType,
                                duration: estimatedDuration,
                                tags: Array(viewModel.selectedTags),
                                detail: "Appointment saved"
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveButton")
                    .font(AppFonts.body)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        AppointmentAudit.record(
                            operation: "cancel",
                            date: selectedDate,
                            owner: selectedOwner?.ownerName,
                            dog: selectedDog?.name,
                            service: selectedServiceType,
                            duration: estimatedDuration,
                            tags: Array(viewModel.selectedTags),
                            detail: "User cancelled"
                        )
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                    .font(AppFonts.body)
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPicker(minutes: $estimatedDuration)
            }
            .onAppear {
                selectedServiceType = viewModel.serviceTypes.first ?? ""
                AppointmentAudit.record(
                    operation: "viewAppear",
                    date: selectedDate,
                    tags: ["appear"],
                    detail: "AddAppointmentView appeared"
                )
            }
        }
    }

    // MARK: - Validation

    var canSave: Bool {
        selectedOwner != nil && selectedDog != nil && !selectedServiceType.isEmpty
    }

    func validateAndSave() -> Bool {
        guard let owner = selectedOwner, let dog = selectedDog, !selectedServiceType.isEmpty else {
            alertMessage = "Please complete all required fields."
            showAlert = true
            AppointmentAudit.record(
                operation: "saveFailure",
                date: selectedDate,
                owner: selectedOwner?.ownerName,
                dog: selectedDog?.name,
                service: selectedServiceType,
                duration: estimatedDuration,
                tags: Array(viewModel.selectedTags),
                detail: "Validation failed: Required fields missing"
            )
            return false
        }
        let success = viewModel.saveAppointment(
            date: selectedDate,
            owner: owner,
            dog: dog,
            serviceType: selectedServiceType,
            notes: notes,
            duration: estimatedDuration,
            tags: viewModel.selectedTags
        )
        if !success {
            alertMessage = viewModel.errorMessage ?? "Failed to save appointment."
            showAlert = true
            AppointmentAudit.record(
                operation: "saveFailure",
                date: selectedDate,
                owner: owner.ownerName,
                dog: dog.name,
                service: selectedServiceType,
                duration: estimatedDuration,
                tags: Array(viewModel.selectedTags),
                detail: "Save failed"
            )
        }
        return success
    }
}
// MARK: - ViewModel

final class AddAppointmentViewModel: ObservableObject {
    @Published var owners: [DogOwner]
    @Published var serviceTypes: [String]
    @Published var availableTags: [String]
    @Published var selectedTags: Set<String> = []
    @Published var errorMessage: String?

    init(
        owners: [DogOwner] = [],
        serviceTypes: [String] = ["Full Groom", "Bath Only", "Nail Trim"],
        availableTags: [String] = ["VIP", "First Visit", "Aggressive", "Sensitive Skin"]
    ) {
        self.owners = owners
        self.serviceTypes = serviceTypes
        self.availableTags = availableTags
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Save appointment to your data model/storage
    func saveAppointment(
        date: Date,
        owner: DogOwner,
        dog: Dog,
        serviceType: String,
        notes: String,
        duration: Int,
        tags: Set<String>
    ) -> Bool {
        // Insert to SwiftData/Core/Store. Stub below:
        // let newAppointment = Appointment(...)
        // context.insert(newAppointment)
        // try? context.save()
        // For now, mock success:
        return true
    }
}

// MARK: - Duration Picker

struct DurationPicker: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.medium) { // Use design token for vertical spacing
                Picker("Duration (minutes)", selection: $minutes) {
                    ForEach(Array(stride(from: 15, through: 180, by: 5)), id: \.self) { min in
                        Text("\(min) min").tag(min)
                            .font(AppFonts.body) // Token replacement for body font
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                Spacer()
            }
            .navigationTitle("Set Duration")
            .font(AppFonts.title) // Token replacement for title font
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("doneDurationButton")
                        .font(AppFonts.body) // Token replacement for body font
                }
            }
            .padding(AppSpacing.medium) // Use design token for padding
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = AppSpacing.small // Use design token for spacing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentAuditAdmin {
    public static var lastSummary: String { AppointmentAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Demo / Business / Tokenized Preview

#if DEBUG
struct AddAppointmentView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(id: UUID(), name: "Bella", birthDate: Date())
        let sampleOwner = DogOwner(id: UUID(), ownerName: "Jane Doe", dogs: [sampleDog])
        let viewModel = AddAppointmentViewModel(owners: [sampleOwner])
        AddAppointmentView(viewModel: viewModel)
            .font(AppFonts.body) // Token replacement for body font in preview
            .accentColor(AppColors.accent) // Token replacement for accent color in preview
    }
}
#endif
