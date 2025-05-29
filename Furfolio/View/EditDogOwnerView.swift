//
//  EditDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with modern navigation, animations, and haptic feedback.


import SwiftUI
import PhotosUI
import os

// TODO: Move validation and save logic into a dedicated ViewModel; use FormValidator and ImageValidator for input checks.

@MainActor
/// View for editing an existing DogOwner, with fields for owner & dog info, images, and inactive status.
struct EditDogOwnerView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "EditDogOwnerView")
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditDogOwnerViewModel

    /// Shared date formatter for birthdate display.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      return fmt
    }()

    var dogOwner: DogOwner
    var onSave: (DogOwner) -> Void

    init(dogOwner: DogOwner, onSave: @escaping (DogOwner) -> Void) {
        self.dogOwner = dogOwner
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: EditDogOwnerViewModel(dogOwner: dogOwner, onSave: onSave))
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
                    Section(header: Text("Dog Birthdate")
                                .font(AppTheme.title)
                                .foregroundColor(AppTheme.primaryText)) {
                        DatePicker("Select Birthdate", selection: $viewModel.dogBirthdate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .accessibilityLabel("Dog Birthdate Picker")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    }
                    Section {
                        Toggle("Mark as Inactive", isOn: $viewModel.markAsInactive)
                            .accessibilityLabel("Mark owner as inactive")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Edit Dog Owner")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            logger.log("EditDogOwnerView Cancel tapped")
                            withAnimation {
                                dismiss()
                            }
                        }
                        .buttonStyle(FurfolioButtonStyle())
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            logger.log("EditDogOwnerView Save tapped: ownerName=\(viewModel.ownerName), dogName=\(viewModel.dogName)")
                            viewModel.save()
                        }
                        .disabled(viewModel.isSaving || !viewModel.validateFields())
                        .buttonStyle(FurfolioButtonStyle())
                    }
                }
                // Overlay progress indicator while saving
                if viewModel.isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadius).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                        .transition(.opacity)
                        .onAppear {
                            logger.log("EditDogOwnerView showing saving overlay")
                        }
                }
            }
        }
        .onAppear {
            logger.log("EditDogOwnerView appeared for owner id: \(dogOwner.id)")
        }
        .onChange(of: viewModel.showValidationError) { new in
            if new { logger.log("EditDogOwnerView validation error alert shown") }
        }
        .onChange(of: viewModel.showImageError) { new in
            if new { logger.log("EditDogOwnerView image error alert shown") }
        }
        .alert("Missing Required Fields", isPresented: $viewModel.showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please fill out the required fields: Owner Name, Dog Name, and Breed.")
        }
        .alert("Invalid Image", isPresented: $viewModel.showImageError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please select an image under 5MB with appropriate dimensions.")
        }
    }

    // MARK: - Form Sections

    /// Builds the section for editing owner name, contact info, and address.
    private func ownerInformationSection() -> some View {
        Section(header: Text("Owner Information")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)) {
            customTextField(placeholder: "Owner Name", text: $viewModel.ownerName)
            customTextField(placeholder: "Contact Info (Optional)", text: $viewModel.contactInfo, keyboardType: .phonePad)
            customTextField(placeholder: "Address (Optional)", text: $viewModel.address)
        }
    }

    /// Builds the section for editing dog name, breed, notes, and loyalty tags.
    private func dogInformationSection() -> some View {
        Section(header: Text("Dog Information")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)) {
            customTextField(placeholder: "Dog Name", text: $viewModel.dogName)
            customTextField(placeholder: "Breed", text: $viewModel.breed)
            notesField()
            if !viewModel.notes.isEmpty {
                HStack {
                    Text("Behavior Tag")
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
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
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Text(remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath")
                    .foregroundColor(.green)
            }
        }
    }

    /// Builds the section for selecting and validating the dog image.
    private func dogImageSection() -> some View {
        Section(header: Text("Dog Image")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)) {
            PhotosPicker(
                selection: Binding(get: { nil }, set: { newValue in
                    viewModel.handleImageSelection(newValue)
                }),
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    if let selectedImageData = viewModel.selectedImageData, let uiImage = UIImage(data: selectedImageData) {
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
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
                }
            }
        }
    }

    /// Builds the notes input field with character limit enforcement.
    private func notesField() -> some View {
        VStack(alignment: .leading) {
            customTextField(placeholder: "Notes (Optional)", text: $viewModel.notes)
                .onChange(of: viewModel.notes) { _ in limitNotesLength() }
            if viewModel.notes.count > 250 {
                Text("Notes must be 250 characters or less.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    /// Custom text field with rounded style and keyboard configuration.
    private func customTextField(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(keyboardType)
            .autocapitalization(.words)
            .font(AppTheme.body)
            .foregroundColor(AppTheme.primaryText)
    }

    /// Truncates notes to a maximum of 250 characters.
    private func limitNotesLength() {
        if viewModel.notes.count > 250 {
            viewModel.notes = String(viewModel.notes.prefix(250))
        }
    }

    /// Computes an emoji badge based on keywords in the notes.
    private var computedBehaviorBadge: String {
        let lowercased = viewModel.notes.lowercased()
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
}
