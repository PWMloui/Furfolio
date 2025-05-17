//
//  AddDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, improved async handling, enhanced accessibility, and refined code structure.

import SwiftUI
import PhotosUI

// TODO: Move validation and save logic into AddDogOwnerViewModel; use FormValidator and ImageValidator for input checks.

@MainActor
/// View for adding a new Dog Owner with fields for owner & dog info, images, and inactive flag.
struct AddDogOwnerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  // MARK: - Form Fields
  @State private var ownerName = ""
  @State private var dogName = ""
  @State private var breed = ""
  @State private var contactInfo = ""
  @State private var address = ""
  @State private var notes = ""
  @State private var selectedImage: PhotosPickerItem? = nil
  @State private var selectedImageData: Data? = nil
  @State private var dogBirthdate: Date = Date() // Default to current date
  @State private var age: Int? = nil
  @State private var markAsInactive = false

  /// Shared date formatter for displaying birthdate.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    return fmt
  }()

  // MARK: - UI States
  @State private var showErrorAlert = false
  @State private var imageValidationError = false
  @State private var isSaving = false
  @State private var showTooltip = false

  // Closure called on successful save; insertion is handled using modelContext.
  var onSave: (String, String, String, String, String, String, Data?, Date?) -> Void

  // Haptic feedback for successful actions.
  private let feedbackGenerator = UINotificationFeedbackGenerator()

  var body: some View {
    NavigationStack {
      ZStack {
        Form {
        }
        .listStyle(.insetGrouped)
        ownerInformationSection()
          .transition(.move(edge: .leading).combined(with: .opacity))
        dogInformationSection()
          .transition(.move(edge: .trailing).combined(with: .opacity))
        dogAgeSection()
        dogImageSection()
        Section {
          Toggle("Mark as Inactive (optional)", isOn: $markAsInactive)
            .accessibilityLabel("Mark owner as inactive")
        }
        Section {
          let staticVisitCount = 3
          let remaining = max(0, 10 - staticVisitCount)
          HStack {
            Text("Loyalty Progress")
            Spacer()
            Text(remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath")
              .foregroundColor(.green)
          }
        }
        .navigationTitle(NSLocalizedString("Add Dog Owner", comment: "Navigation title for Add Dog Owner view"))
        .toolbar { toolbarContent() }
        .alert(
          NSLocalizedString("Missing Required Fields", comment: "Alert title for missing required fields"),
          isPresented: $showErrorAlert
        ) {
          Button(NSLocalizedString("OK", comment: "Dismiss alert button"), role: .cancel) {}
        } message: {
          Text(NSLocalizedString("Please fill out the required fields: Owner Name, Dog Name, and Breed.", comment: "Message for missing required fields"))
        }

        // Overlay progress view when saving
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
        Task {
          try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
          withAnimation { showTooltip = true }
          try? await Task.sleep(nanoseconds: 3_000_000_000) // Show tooltip for 3 seconds
          withAnimation { showTooltip = false }
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  // MARK: - Form Sections

  /// Builds the section for entering owner name, contact info, and address.
  @ViewBuilder
  private func ownerInformationSection() -> some View {
    Section(header: sectionHeader(icon: "person.fill", title: "Owner Information")) {
      customTextField(placeholder: "Owner Name", text: $ownerName)
      customTextField(placeholder: "Contact Info (Optional)", text: $contactInfo, keyboardType: .phonePad)
      customTextField(placeholder: "Address (Optional)", text: $address)
    }
  }

  /// Builds the section for entering dog name, breed, notes, and behavior tag.
  @ViewBuilder
  private func dogInformationSection() -> some View {
    Section(header: sectionHeader(icon: "pawprint.fill", title: "Dog Information")) {
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
    }
  }

  /// Builds the section for selecting birthdate and displaying calculated age.
  @ViewBuilder
  private func dogAgeSection() -> some View {
    Section(header: sectionHeader(icon: "calendar.fill", title: "Dog Age")) {
      DatePicker("Dog Birthdate", selection: $dogBirthdate, displayedComponents: .date)
        .onChange(of: dogBirthdate) { newValue in
          age = calculateAge(from: newValue)
        }
        .accessibilityLabel(NSLocalizedString("Select dog's birthdate", comment: "Accessibility label for birthdate picker"))
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

  /// Builds the notes input field with character limit and inline tooltip.
  @ViewBuilder
  private func notesField() -> some View {
    VStack(alignment: .leading, spacing: 4) {
      customTextField(placeholder: "Notes (Optional)", text: $notes)
        .onChange(of: notes) { _ in limitNotesLength() }
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

  /// Builds the image picker section with validation alerts.
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
        Button(NSLocalizedString("OK", comment: "Dismiss alert button"), role: .cancel) {}
      } message: {
        Text(NSLocalizedString("Please select an image under 5MB with appropriate dimensions.", comment: "Message for invalid image size or dimensions"))
      }
    }
  }

  // MARK: - Toolbar Content

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      Button(NSLocalizedString("Cancel", comment: "Cancel button label")) {
        withAnimation { dismiss() }
      }
      .accessibilityLabel(NSLocalizedString("Cancel", comment: "Accessibility label for cancel button"))
    }
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(NSLocalizedString("Save", comment: "Save button label")) {
        handleSave()
      }
      .disabled(isSaving || !validateFields())
      .accessibilityLabel(NSLocalizedString("Save Dog Owner", comment: "Accessibility label for save button"))
    }
  }

  // MARK: - Utility Methods

  /// Returns a section header view with an icon and title.
  private func sectionHeader(icon: String, title: String) -> some View {
    HStack {
      Image(systemName: icon)
      Text(NSLocalizedString(title, comment: "Section header"))
    }
  }

  /// A reusable custom text field.
  private func customTextField(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
    TextField(NSLocalizedString(placeholder, comment: "Placeholder for \(placeholder)"), text: text)
      .keyboardType(keyboardType)
      .textFieldStyle(RoundedBorderTextFieldStyle())
  }

  /// Validates inputs and invokes onSave closure, showing a saving overlay.
  private func handleSave() {
    if validateFields() {
      isSaving = true
      feedbackGenerator.notificationOccurred(.success)
      // Support for manual and future auto-inactive tagging
      let autoInactiveTag = "[AUTO-INACTIVE]"
      let manualInactiveTag = "[INACTIVE]"
      let inactiveNoteTag: String
      if markAsInactive {
        inactiveNoteTag = manualInactiveTag
      } else {
        // Placeholder logic for auto-inactive; real logic should evaluate appointment history if available
        inactiveNoteTag = ""
      }
      let finalNotes = inactiveNoteTag.isEmpty ? notes : "\(inactiveNoteTag) \(notes)"
      // Normalize the birthday to the start of the day for consistent tracking/filtering
      let normalizedBirthdate = Calendar.current.startOfDay(for: dogBirthdate)
      onSave(ownerName, dogName, breed, contactInfo, address, finalNotes, selectedImageData, normalizedBirthdate)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isSaving = false
        dismiss()
      }
    } else {
      showErrorAlert = true
    }
  }

  /// Loads image data and validates it asynchronously.
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
    do {
      try FormValidator.validateRequired(ownerName, fieldName: "Owner Name")
      try FormValidator.validateRequired(dogName, fieldName: "Dog Name")
      try FormValidator.validateRequired(breed, fieldName: "Breed")
      return true
    } catch {
      showErrorAlert = true
      return false
    }
  }

  /// Truncates notes to 250 characters.
  private func limitNotesLength() {
    if notes.count > 250 {
      notes = String(notes.prefix(250))
    }
  }

  /// Validates the selected image based on file size and dimensions.
  private func isValidImage(data: Data) -> Bool {
    guard ImageValidator.isAcceptableImage(data) else { return false }
    return true
  }

  /// Calculates age in years from a birthdate.
  private func calculateAge(from birthdate: Date) -> Int? {
    let calendar = Calendar.current
    let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
    return ageComponents.year
  }
  // MARK: - Behavior Badge Helper

  /// Computes an emoji badge based on keywords in notes.
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
}
