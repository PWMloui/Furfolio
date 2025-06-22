//
// MARK: - EditAppointmentView (Tokenized, Modular, Auditable Appointment Edit UI)
//
//  EditAppointmentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// View to edit an existing appointment with owner, dog, service, duration, notes, and tags.
/// This view and its ViewModel are fully modular, tokenized, and auditable, supporting owner-focused workflows,
/// accessibility, localization, business analytics, and UI design system integration.
/// All UI elements leverage design tokens for colors, fonts, and spacing to ensure consistency and theming.
/// Accessibility identifiers are added to support UI testing and assistive technologies.
struct EditAppointmentView: View {
    @ObservedObject var viewModel: EditAppointmentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDurationPicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date & Time").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    DatePicker("Appointment Date", selection: $viewModel.date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("appointmentDatePicker")
                        .font(AppFonts.body) // Tokenized font for date picker
                }

                Section(header: Text("Client").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    Picker("Owner", selection: $viewModel.selectedOwner) {
                        Text("Select Owner").tag(DogOwner?.none)
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .onChange(of: viewModel.selectedOwner) { _ in
                        viewModel.resetDogIfOwnerChanged()
                    }
                    .accessibilityIdentifier("ownerPicker")
                    .font(AppFonts.body) // Tokenized font for picker

                    if let owner = viewModel.selectedOwner {
                        Picker("Dog", selection: $viewModel.selectedDog) {
                            Text("Select Dog").tag(Dog?.none)
                            ForEach(owner.dogs ?? []) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .accessibilityIdentifier("dogPicker")
                        .font(AppFonts.body) // Tokenized font for picker
                    }
                }

                Section(header: Text("Service").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    Picker("Service Type", selection: $viewModel.serviceType) {
                        ForEach(viewModel.serviceTypes, id: \.self) { type in
                            Text(type)
                                .font(AppFonts.body) // Tokenized font for picker items
                        }
                    }
                    .accessibilityIdentifier("servicePicker")
                    .font(AppFonts.body)
                }

                Section(header: Text("Duration").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    HStack {
                        Text("\(viewModel.duration) min")
                            .font(AppFonts.body) // Tokenized font for duration text
                        Spacer()
                        Button("Change") {
                            withAnimation {
                                showDurationPicker = true
                            }
                        }
                        .accessibilityIdentifier("changeDurationButton")
                        .font(AppFonts.body) // Tokenized font for button
                        .padding(.horizontal, AppSpacing.small) // Tokenized horizontal padding
                        .padding(.vertical, AppSpacing.xSmall) // Tokenized vertical padding
                        .background(AppColors.backgroundSecondary) // Tokenized background color for button
                        .foregroundColor(AppColors.accent) // Tokenized accent color for button text
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, AppSpacing.xSmall) // Tokenized vertical padding for HStack
                }

                Section(header: Text("Notes").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    TextField("Add notes...", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("notesTextField")
                        .font(AppFonts.body) // Tokenized font for text field
                        .padding(AppSpacing.xSmall) // Tokenized padding for text field
                }

                if !viewModel.availableTags.isEmpty {
                    Section(header: Text("Tags").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                        FlowLayout(alignment: .leading, spacing: AppSpacing.small) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                Button {
                                    withAnimation {
                                        viewModel.toggleTag(tag)
                                    }
                                } label: {
                                    Text(tag)
                                        .font(AppFonts.caption) // Tokenized font for tag text
                                        .padding(.horizontal, AppSpacing.medium) // Tokenized horizontal padding
                                        .padding(.vertical, AppSpacing.xSmall) // Tokenized vertical padding
                                        .background(viewModel.selectedTags.contains(tag) ? AppColors.accent : AppColors.backgroundSecondary)
                                        .foregroundColor(viewModel.selectedTags.contains(tag) ? AppColors.textOnAccent : AppColors.textPrimary)
                                        .clipShape(Capsule())
                                }
                                .accessibilityIdentifier("tagButton_\(tag)")
                            }
                        }
                        .padding(.vertical, AppSpacing.xSmall) // Tokenized vertical padding for FlowLayout
                    }
                }
            }
            .navigationTitle("Edit Appointment")
            .font(AppFonts.body) // Tokenized font for navigation title
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.validateAndSave() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("saveButton")
                    .font(AppFonts.body) // Tokenized font for button
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(viewModel.canSave ? AppColors.accent : AppColors.backgroundSecondary)
                    .foregroundColor(viewModel.canSave ? AppColors.textOnAccent : AppColors.secondaryText)
                    .clipShape(Capsule())
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                    .font(AppFonts.body) // Tokenized font for button
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(AppColors.backgroundSecondary)
                    .foregroundColor(AppColors.accent)
                    .clipShape(Capsule())
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPicker(minutes: $viewModel.duration)
            }
        }
    }
}

/// ViewModel for editing an appointment
final class EditAppointmentViewModel: ObservableObject {
    @Published var date: Date
    @Published var selectedOwner: DogOwner?
    @Published var selectedDog: Dog?
    @Published var serviceType: String
    @Published var duration: Int
    @Published var notes: String
    @Published var selectedTags: Set<String>
    @Published var owners: [DogOwner]
    @Published var serviceTypes: [String]
    @Published var availableTags: [String]
    var originalAppointment: Appointment

    init(
        appointment: Appointment,
        owners: [DogOwner],
        serviceTypes: [String] = ["Full Groom", "Bath Only", "Nail Trim"],
        availableTags: [String] = ["VIP", "First Visit", "Aggressive", "Sensitive Skin"]
    ) {
        self.originalAppointment = appointment
        self.date = appointment.date
        self.selectedOwner = appointment.owner
        self.selectedDog = appointment.dog
        self.serviceType = appointment.serviceType
        self.duration = appointment.duration
        self.notes = appointment.notes ?? ""
        self.selectedTags = Set(appointment.tags ?? [])
        self.owners = owners
        self.serviceTypes = serviceTypes
        self.availableTags = availableTags
    }

    /// Reset selected dog if the owner changes or becomes nil
    func resetDogIfOwnerChanged() {
        guard let selectedOwner = selectedOwner else {
            selectedDog = nil
            return
        }
        if selectedDog?.owner?.id != selectedOwner.id {
            selectedDog = nil
        }
    }

    var canSave: Bool {
        selectedOwner != nil && selectedDog != nil && !serviceType.isEmpty
    }

    /// Toggles a tag selection
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Validates and saves the appointment (placeholder for real persistence logic)
    func validateAndSave() -> Bool {
        guard canSave else { return false }
        // TODO: Add actual save logic to your persistence layer here.
        originalAppointment.date = date
        originalAppointment.owner = selectedOwner
        originalAppointment.dog = selectedDog
        originalAppointment.serviceType = serviceType
        originalAppointment.duration = duration
        originalAppointment.notes = notes
        originalAppointment.tags = Array(selectedTags)
        return true
    }
}

// MARK: - Placeholder Models

/// Appointment model
struct Appointment: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var owner: DogOwner?
    var dog: Dog?
    var serviceType: String
    var duration: Int
    var notes: String?
    var tags: [String]?
}

/// Dog owner model
struct DogOwner: Identifiable, Hashable, Equatable {
    var id: UUID
    var ownerName: String
    var dogs: [Dog]?
}

/// Dog model
struct Dog: Identifiable, Hashable, Equatable {
    var id: UUID
    var name: String
    var owner: DogOwner? = nil
}

// MARK: - Duration Picker (reuse from AddAppointmentView)

/// Picker view to select appointment duration in minutes
struct DurationPicker: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    private let minMinutes = 15
    private let maxMinutes = 180

    var body: some View {
        NavigationView {
            VStack {
                Picker("Duration (minutes)", selection: $minutes) {
                    ForEach(Array(stride(from: minMinutes, through: maxMinutes, by: 5)), id: \.self) { min in
                        Text("\(min) min")
                            .font(AppFonts.body) // Tokenized font for picker items
                            .foregroundColor(AppColors.textPrimary) // Tokenized color
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: AppSpacing.durationPickerHeight) // Tokenized height
                Spacer()
            }
            .navigationTitle("Set Duration")
            .font(AppFonts.body) // Tokenized font for navigation title
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppFonts.body) // Tokenized font for button
                    .accessibilityIdentifier("durationPickerDoneButton")
                }
            }
            .padding(AppSpacing.medium) // Tokenized padding
            .background(AppColors.backgroundPrimary)
        }
    }
}

// MARK: - FlowLayout Helper

/// A simple flow layout that wraps content horizontally and vertically
struct FlowLayout<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = AppSpacing.small // Tokenized spacing
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(ArrayMirror(content()).enumerated()), id: \.0) { index, view in
                view
                    .padding(.horizontal, spacing / 2)
                    .padding(.vertical, spacing / 2)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }
                        let result = width
                        if index == ArrayMirror(content()).count - 1 {
                            width = 0 // Last item
                        } else {
                            width -= dimension.width + spacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == ArrayMirror(content()).count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
}

// Helper to convert ViewBuilder content into an array of views
fileprivate struct ArrayMirror<Content: View>: RandomAccessCollection {
    typealias Element = AnyView
    typealias Index = Int
    private let views: [AnyView]

    init(_ content: Content) {
        // Wrap in AnyView for storage
        if let tupleView = content as? TupleView<(AnyView, AnyView)> {
            self.views = Mirror(reflecting: tupleView).children.compactMap { $0.value as? AnyView }
        } else {
            self.views = [AnyView(content)]
        }
    }

    var startIndex: Int { 0 }
    var endIndex: Int { views.count }

    subscript(position: Int) -> AnyView {
        views[position]
    }
}

// MARK: - Preview

/// Demo/business/tokenized preview of EditAppointmentView showcasing token usage and accessibility
#if DEBUG
struct EditAppointmentView_Previews: PreviewProvider {
    static var previews: some View {
        let dog = Dog(id: UUID(), name: "Bella")
        let owner = DogOwner(id: UUID(), ownerName: "Jane Doe", dogs: [dog])
        let appointment = Appointment(id: UUID(), date: Date().addingTimeInterval(3600), owner: owner, dog: dog, serviceType: "Full Groom", duration: 90, notes: "Use gentle shampoo", tags: ["VIP"])

        let viewModel = EditAppointmentViewModel(appointment: appointment, owners: [owner])
        EditAppointmentView(viewModel: viewModel)
            .environment(\.colorScheme, .light)
            .font(AppFonts.body) // Tokenized font for preview
            .accentColor(AppColors.accent) // Tokenized accent color for preview
    }
}
#endif
