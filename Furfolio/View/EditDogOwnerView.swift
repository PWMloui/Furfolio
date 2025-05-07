//
//  EditDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with modern navigation, animations, and haptic feedback.

import SwiftUI
import PhotosUI

struct EditDogOwnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ownerName: String
    @State private var dogName: String
    @State private var breed: String
    @State private var contactInfo: String
    @State private var address: String
    @State private var notes: String
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var showValidationError = false
    @State private var showImageError = false
    @State private var markAsInactive = false
    @State private var dogBirthdate: Date

    var dogOwner: DogOwner
    var onSave: (DogOwner) -> Void

    // Haptic feedback generator for successful actions.
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    init(dogOwner: DogOwner, onSave: @escaping (DogOwner) -> Void) {
        _ownerName = State(initialValue: dogOwner.ownerName)
        _dogName = State(initialValue: dogOwner.dogName)
        _breed = State(initialValue: dogOwner.breed)
        _contactInfo = State(initialValue: dogOwner.contactInfo)
        _address = State(initialValue: dogOwner.address)
        _notes = State(initialValue: dogOwner.notes)
        _selectedImageData = State(initialValue: dogOwner.dogImage)
        _dogBirthdate = State(initialValue: dogOwner.birthdate ?? Date())
        
        self.dogOwner = dogOwner
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    ownerInformationSection()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    dogInformationSection()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    dogImageSection()
                        .transition(.opacity)
                    Section(header: Text("Dog Birthdate")) {
                        DatePicker("Select Birthdate", selection: $dogBirthdate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .accessibilityLabel("Dog Birthdate Picker")
                    }
                    Section {
                        Toggle("Mark as Inactive", isOn: $markAsInactive)
                            .accessibilityLabel("Mark owner as inactive")
                    }
                }
                .navigationTitle("Edit Dog Owner")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            withAnimation {
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            handleSave()
                        }
                        .disabled(isSaving || !validateFields())
                    }
                }
                // Overlay progress indicator while saving
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                        .transition(.opacity)
                }
            }
            .alert("Missing Required Fields", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please fill out the required fields: Owner Name, Dog Name, and Breed.")
            }
            .alert("Invalid Image", isPresented: $showImageError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select an image under 5MB with appropriate dimensions.")
            }
        }
    }

    // MARK: - Form Sections

    private func ownerInformationSection() -> some View {
        Section(header: Text("Owner Information")) {
            customTextField(placeholder: "Owner Name", text: $ownerName)
            customTextField(placeholder: "Contact Info (Optional)", text: $contactInfo, keyboardType: .phonePad)
            customTextField(placeholder: "Address (Optional)", text: $address)
        }
    }

    private func dogInformationSection() -> some View {
        Section(header: Text("Dog Information")) {
            customTextField(placeholder: "Dog Name", text: $dogName)
            customTextField(placeholder: "Breed", text: $breed)
            notesField()
            if !notes.isEmpty {
                HStack {
                    Text("Behavior Tag")
                    Spacer()
                    Text(computedBehaviorBadge)
                        .foregroundColor(.orange)
                }
            }

            // Simulate loyalty reward badge based on 4 prior visits
            let simulatedVisits = 4
            let remaining = max(0, 10 - simulatedVisits)
            HStack {
                Text("Loyalty Progress")
                Spacer()
                Text(remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath")
                    .foregroundColor(.green)
            }
        }
    }

    private func dogImageSection() -> some View {
        Section(header: Text("Dog Image")) {
            PhotosPicker(
                selection: $selectedImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            .accessibilityLabel("Selected dog image")
                    } else {
                        Image(systemName: "photo.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                            .accessibilityLabel("Placeholder dog image")
                    }
                    Spacer()
                    Text("Select an Image")
                }
            }
            .onChange(of: selectedImage) { newValue in
                handleImageSelection(newValue)
            }
        }
    }

    private func notesField() -> some View {
        VStack(alignment: .leading) {
            customTextField(placeholder: "Notes (Optional)", text: $notes)
                .onChange(of: notes) { _ in limitNotesLength() }
            if notes.count > 250 {
                Text("Notes must be 250 characters or less.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func customTextField(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(keyboardType)
            .autocapitalization(.words)
    }

    // MARK: - Save Handling

    private func handleSave() {
        if validateFields() {
            isSaving = true
            // Provide success haptic feedback
            feedbackGenerator.notificationOccurred(.success)
            let autoInactiveTag = "[AUTO-INACTIVE]"
            let manualInactiveTag = "[INACTIVE]"

            let inactiveTag: String
            if markAsInactive {
                inactiveTag = manualInactiveTag
            } else if shouldBeAutoInactive() {
                inactiveTag = autoInactiveTag
            } else {
                inactiveTag = ""
            }

            let updatedNotes = inactiveTag.isEmpty ? notes : "\(inactiveTag) \(notes)"
            dogOwner.ownerName = ownerName
            dogOwner.dogName = dogName
            dogOwner.breed = breed
            dogOwner.contactInfo = contactInfo
            dogOwner.address = address
            dogOwner.notes = updatedNotes
            dogOwner.dogImage = selectedImageData
            dogOwner.birthdate = Calendar.current.startOfDay(for: dogBirthdate)
            onSave(dogOwner)
            // Simulate a short delay to allow animations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                dismiss()
            }
        } else {
            showValidationError = true
            // Provide error haptic feedback if fields are missing
            feedbackGenerator.notificationOccurred(.error)
        }
    }

    /// Updates the `DogOwner` object and calls the `onSave` closure.
    private func updateDogOwner() {
        dogOwner.ownerName = ownerName
        dogOwner.dogName = dogName
        dogOwner.breed = breed
        dogOwner.contactInfo = contactInfo
        dogOwner.address = address
        dogOwner.notes = notes
        dogOwner.dogImage = selectedImageData
        onSave(dogOwner)
    }

    // MARK: - Helper Methods

    private func handleImageSelection(_ newValue: PhotosPickerItem?) {
        Task {
            if let newValue, let data = try? await newValue.loadTransferable(type: Data.self) {
                if isValidImage(data: data) {
                    selectedImageData = data
                } else {
                    showImageError = true
                    // Provide error haptic feedback for invalid image
                    feedbackGenerator.notificationOccurred(.error)
                }
            }
        }
    }

    private func validateFields() -> Bool {
        return !ownerName.isEmpty && !dogName.isEmpty && !breed.isEmpty
    }

    private func limitNotesLength() {
        if notes.count > 250 {
            notes = String(notes.prefix(250))
        }
    }

    private func isValidImage(data: Data) -> Bool {
        let maxSizeMB = 5.0
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        guard data.count <= Int(maxSizeBytes), let image = UIImage(data: data) else { return false }
        return image.size.width > 100 && image.size.height > 100
    }

    private var computedBehaviorBadge: String {
        let lowercased = notes.lowercased()
        if lowercased.contains("calm") || lowercased.contains("friendly") {
            return "🟢 Calm"
        } else if lowercased.contains("aggressive") || lowercased.contains("bite") {
            return "🔴 Aggressive"
        } else if lowercased.contains("anxious") || lowercased.contains("timid") {
            return "🟠 Anxious"
        } else {
            return "😐 Neutral"
        }
    }
    // Detects if the owner should be automatically marked as inactive (mock logic)
    private func shouldBeAutoInactive() -> Bool {
        guard let lastAppointment = dogOwner.appointments.map(\.date).max() else { return false }
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        return lastAppointment < ninetyDaysAgo
    }
}
