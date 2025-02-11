//
//  AddDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, haptic feedback, and onboarding enhancements.

import SwiftUI
import PhotosUI

struct AddDogOwnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ownerName = ""
    @State private var dogName = ""
    @State private var breed = ""
    @State private var contactInfo = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var showErrorAlert = false
    @State private var imageValidationError = false
    @State private var isSaving = false
    @State private var dogBirthdate: Date = Date() // Non-optional date with default value
    @State private var age: Int? = nil

    var onSave: (String, String, String, String, String, String, Data?, Date?) -> Void

    // Haptic feedback generator for success notifications.
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // For onboarding/tooltips.
    @State private var showTooltip = false

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    ownerInformationSection()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    dogInformationSection()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    dogAgeSection()
                    dogImageSection()
                }
                .navigationTitle(NSLocalizedString("Add Dog Owner", comment: "Navigation title for Add Dog Owner view"))
                .toolbar { toolbarContent() }
                .alert(
                    NSLocalizedString("Missing Required Fields", comment: "Alert title for missing required fields"),
                    isPresented: $showErrorAlert
                ) {
                    Button(NSLocalizedString("OK", comment: "Button label for dismissing alert"), role: .cancel) {}
                } message: {
                    Text(NSLocalizedString("Please fill out the required fields: Owner Name, Dog Name, and Breed.", comment: "Message for missing required fields"))
                }
                
                // Progress overlay when saving is in progress.
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
                // Display onboarding tooltip for 3 seconds.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showTooltip = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showTooltip = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Form Sections
    
    @ViewBuilder
    private func ownerInformationSection() -> some View {
        Section(header: sectionHeader(icon: "person.fill", title: "Owner Information")) {
            customTextField(placeholder: "Owner Name", text: $ownerName)
            customTextField(placeholder: "Contact Info (Optional)", text: $contactInfo, keyboardType: .phonePad)
            customTextField(placeholder: "Address (Optional)", text: $address)
        }
    }
    
    @ViewBuilder
    private func dogInformationSection() -> some View {
        Section(header: sectionHeader(icon: "pawprint.fill", title: "Dog Information")) {
            customTextField(placeholder: "Dog Name", text: $dogName)
            customTextField(placeholder: "Breed", text: $breed)
            notesField()
        }
    }
    
    @ViewBuilder
    private func dogAgeSection() -> some View {
        Section(header: sectionHeader(icon: "calendar.fill", title: "Dog Age")) {
            DatePicker("Dog Birthdate", selection: $dogBirthdate, displayedComponents: .date)
                .onChange(of: dogBirthdate) { newValue in
                    age = calculateAge(from: newValue)
                }
            if let age = age {
                Text("Dog Age: \(age) years")
                    .transition(.opacity)
            } else {
                Text("Select a birthdate to calculate the dog's age")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func notesField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            customTextField(placeholder: "Notes (Optional)", text: $notes)
                .onChange(of: notes) { _ in
                    limitNotesLength()
                }
            if showTooltip && notes.isEmpty {
                Text(NSLocalizedString("Enter any extra details (max 250 characters)", comment: "Tooltip for additional notes"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            if notes.count > 250 {
                Text(NSLocalizedString("Notes must be 250 characters or less.", comment: "Warning for note length"))
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func dogImageSection() -> some View {
        Section(header: sectionHeader(icon: "photo.fill", title: "Dog Image")) {
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
                            .accessibilityLabel(NSLocalizedString("Selected dog image", comment: "Accessibility label for selected dog image"))
                    } else {
                        Image(systemName: "photo.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                            .accessibilityLabel(NSLocalizedString("Placeholder dog image", comment: "Accessibility label for placeholder image"))
                    }
                    Spacer()
                    Text(NSLocalizedString("Select an Image", comment: "Label for selecting an image"))
                }
            }
            .onChange(of: selectedImage) { newValue in
                handleImageSelection(newValue)
            }
            .alert(NSLocalizedString("Invalid Image", comment: "Alert title for invalid image"), isPresented: $imageValidationError) {
                Button(NSLocalizedString("OK", comment: "Button label for dismissing alert"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Please select an image under 5MB with appropriate dimensions.", comment: "Message for invalid image size or dimensions"))
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("Cancel", comment: "Button label for cancel")) {
                withAnimation {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(NSLocalizedString("Save", comment: "Button label for save")) {
                handleSave()
            }
            .disabled(isSaving || !validateFields())
        }
    }
    
    // MARK: - Utility Methods
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(NSLocalizedString(title, comment: "Section header"))
        }
    }
    
    /// Custom text field component for reusability.
    private func customTextField(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        TextField(NSLocalizedString(placeholder, comment: "Placeholder for \(placeholder)"), text: text)
            .keyboardType(keyboardType)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
    
    /// Handles saving the entered data, triggers haptic feedback, and dismisses the view.
    private func handleSave() {
        if validateFields() {
            isSaving = true
            feedbackGenerator.notificationOccurred(.success)
            onSave(ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, dogBirthdate)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                dismiss()
            }
        } else {
            showErrorAlert = true
        }
    }
    
    /// Handles image selection asynchronously.
    private func handleImageSelection(_ newValue: PhotosPickerItem?) {
        if let newValue {
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    if !isValidImage(data: data) {
                        imageValidationError = true
                        selectedImageData = nil
                    }
                }
            }
        }
    }
    
    /// Validates that the required fields are not empty.
    private func validateFields() -> Bool {
        return !ownerName.isEmpty && !dogName.isEmpty && !breed.isEmpty
    }
    
    /// Limits the length of the notes to 250 characters.
    private func limitNotesLength() {
        if notes.count > 250 {
            notes = String(notes.prefix(250))
        }
    }
    
    /// Validates the uploaded image for size and dimensions.
    private func isValidImage(data: Data) -> Bool {
        let maxSizeMB = 5.0
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        guard data.count <= Int(maxSizeBytes), let image = UIImage(data: data) else { return false }
        return image.size.width > 100 && image.size.height > 100
    }
    
    /// Calculates the dog's age from the given birthdate.
    private func calculateAge(from birthdate: Date) -> Int? {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
        return ageComponents.year
    }
}
