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
                Section(header: Text("Date & Time").font(AppFonts.headline)) { // Use design token for headline font
                    DatePicker("Appointment Date", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("appointmentDatePicker")
                }

                Section(header: Text("Client").font(AppFonts.headline)) { // Use design token for headline font
                    Picker("Owner", selection: $selectedOwner) {
                        Text("Select Owner").tag(DogOwner?.none)
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .accessibilityIdentifier("ownerPicker")
                    .onChange(of: selectedOwner) { _, owner in
                        if selectedDog?.ownerID != owner?.id {
                            selectedDog = nil
                        }
                    }

                    if let owner = selectedOwner, let dogs = owner.dogs, !dogs.isEmpty {
                        Picker("Dog", selection: $selectedDog) {
                            Text("Select Dog").tag(Dog?.none)
                            ForEach(dogs) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .accessibilityIdentifier("dogPicker")
                    } else if selectedOwner != nil {
                        Text("No dogs found for this owner.")
                            .foregroundColor(AppColors.secondaryText) // Token replacement for secondary text color
                            .font(AppFonts.body) // Token replacement for body font
                    }
                }

                Section(header: Text("Service").font(AppFonts.headline)) { // Use design token for headline font
                    Picker("Service Type", selection: $selectedServiceType) {
                        ForEach(viewModel.serviceTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                    .accessibilityIdentifier("serviceTypePicker")
                }

                Section(header: Text("Duration").font(AppFonts.headline)) { // Use design token for headline font
                    HStack {
                        Text("\(estimatedDuration) min")
                            .font(AppFonts.body) // Token replacement for body font
                        Spacer()
                        Button("Change") {
                            showDurationPicker = true
                        }
                        .accessibilityIdentifier("changeDurationButton")
                        .font(AppFonts.body) // Token replacement for body font
                    }
                    .padding(.vertical, AppSpacing.small) // Use design token for vertical padding
                }

                Section(header: Text("Notes").font(AppFonts.headline)) { // Use design token for headline font
                    TextField("Add special notes or preferences...", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("notesField")
                        .font(AppFonts.body) // Token replacement for body font
                }

                if !viewModel.availableTags.isEmpty {
                    Section(header: Text("Tags").font(AppFonts.headline)) { // Use design token for headline font
                        FlowLayout(alignment: .leading, spacing: AppSpacing.small) { // Use design token for spacing
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                Button(action: { viewModel.toggleTag(tag) }) {
                                    Text(tag)
                                        .padding(.horizontal, AppSpacing.medium) // Use design token for horizontal padding
                                        .padding(.vertical, AppSpacing.small) // Use design token for vertical padding
                                        .background(viewModel.selectedTags.contains(tag) ? AppColors.accent : AppColors.backgroundSecondary) // Token replacements for background colors
                                        .foregroundColor(viewModel.selectedTags.contains(tag) ? AppColors.textOnAccent : AppColors.textPrimary) // Token replacements for foreground colors
                                        .clipShape(Capsule())
                                        .font(AppFonts.body) // Token replacement for body font
                                }
                                .accessibilityIdentifier("tagButton_\(tag)")
                            }
                        }
                        .padding(.vertical, AppSpacing.small) // Use design token for vertical padding
                    }
                }
            }
            .navigationTitle("New Appointment")
            .font(AppFonts.title) // Token replacement for title font on navigation title
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if validateAndSave() { dismiss() }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveButton")
                    .font(AppFonts.body) // Token replacement for body font
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                        .font(AppFonts.body) // Token replacement for body font
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
