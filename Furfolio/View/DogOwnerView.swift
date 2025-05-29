//
//  AddDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, improved async handling, enhanced accessibility, and refined code structure.

import SwiftUI
import PhotosUI
import Combine
import os

// TODO: Move validation and save logic into AddDogOwnerViewModel; use FormValidator and ImageValidator for input checks.

@MainActor
/// View for adding a new Dog Owner with fields for owner & dog info, images, and inactive flag.
struct AddDogOwnerView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AddDogOwnerView")

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @StateObject private var viewModel = AddDogOwnerViewModel()

  /// Shared date formatter for displaying birthdate.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    return fmt
  }()

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
          Toggle("Mark as Inactive (optional)", isOn: $viewModel.markAsInactive)
            .accessibilityLabel("Mark owner as inactive")
        }
        Section {
          let staticVisitCount = 3
          let remaining = max(0, 10 - staticVisitCount)
          HStack {
            Text("Loyalty Progress")
              .font(AppTheme.body)
            Spacer()
            Text(remaining == 0 ? "🎁 Free Bath Earned!" : "🏆 \(remaining) more to free bath")
              .foregroundColor(AppTheme.accent)
              .font(AppTheme.body)
          }
          .onAppear {
              logger.log("Loyalty progress displayed: remaining=\(remaining)")
          }
        }
        .navigationTitle(NSLocalizedString("Add Dog Owner", comment: "Navigation title for Add Dog Owner view"))
        .toolbar { toolbarContent() }
        .alert(
          NSLocalizedString("Missing Required Fields", comment: "Alert title for missing required fields"),
          isPresented: $viewModel.showErrorAlert
        ) {
          Button(NSLocalizedString("OK", comment: "Dismiss alert button"), role: .cancel) {}
        } message: {
          Text(NSLocalizedString("Please fill out the required fields: Owner Name, Dog Name, and Breed.", comment: "Message for missing required fields"))
            .font(AppTheme.body)
        }
        .onChange(of: viewModel.showErrorAlert) { new in
            if new { logger.log("AddDogOwnerView validation error alert shown") }
        }

        // Overlay progress view when saving
        if viewModel.isSaving {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
          ProgressView(NSLocalizedString("Saving...", comment: "Progress indicator while saving"))
            .padding()
            .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadius).fill(Color(.systemBackground)))
            .shadow(radius: 10)
            .onAppear {
                logger.log("AddDogOwnerView showing saving overlay")
            }
        }
      }
      .onAppear {
        viewModel.onAppear()
      }
    }
    .accessibilityElement(children: .contain)
    .onAppear {
        logger.log("AddDogOwnerView appeared")
    }
  }

  // MARK: - Form Sections

  /// Builds the section for entering owner name, contact info, and address.
  @ViewBuilder
  private func ownerInformationSection() -> some View {
    Section(header: sectionHeader(icon: "person.fill", title: "Owner Information")) {
      customTextField(placeholder: "Owner Name", text: $viewModel.ownerName)
      customTextField(placeholder: "Contact Info (Optional)", text: $viewModel.contactInfo, keyboardType: .phonePad)
      customTextField(placeholder: "Address (Optional)", text: $viewModel.address)
    }
  }

  /// Builds the section for entering dog name, breed, notes, and behavior tag.
  @ViewBuilder
  private func dogInformationSection() -> some View {
    Section(header: sectionHeader(icon: "pawprint.fill", title: "Dog Information")) {
      customTextField(placeholder: "Dog Name", text: $viewModel.dogName)
      customTextField(placeholder: "Breed", text: $viewModel.breed)
      notesField()
      if !viewModel.notes.isEmpty {
        HStack {
          Text("Behavior Tag")
            .font(AppTheme.body)
          Spacer()
          Text(computedBehaviorBadge)
            .foregroundColor(.orange)
            .font(AppTheme.body)
        }
      }
    }
  }

  /// Builds the section for selecting birthdate and displaying calculated age.
  @ViewBuilder
  private func dogAgeSection() -> some View {
    Section(header: sectionHeader(icon: "calendar.fill", title: "Dog Age")) {
      DatePicker("Dog Birthdate", selection: $viewModel.dogBirthdate, displayedComponents: .date)
        .onChange(of: viewModel.dogBirthdate) { _ in
          viewModel.calculateAge()
        }
        .accessibilityLabel(NSLocalizedString("Select dog's birthdate", comment: "Accessibility label for birthdate picker"))
      if let age = viewModel.age {
        Text("Dog Age: \(age) years")
          .font(AppTheme.body)
          .transition(.opacity)
      } else {
        Text("Select a birthdate to calculate the dog's age")
          .font(AppTheme.caption)
          .foregroundColor(AppTheme.secondaryText)
      }
    }
  }

  /// Builds the notes input field with character limit and inline tooltip.
  @ViewBuilder
  private func notesField() -> some View {
    VStack(alignment: .leading, spacing: 4) {
      customTextField(placeholder: "Notes (Optional)", text: $viewModel.notes)
        .onChange(of: viewModel.notes) { _ in limitNotesLength() }
      if viewModel.showTooltip && viewModel.notes.isEmpty {
        Text(NSLocalizedString("Enter any extra details (max 250 characters)", comment: "Tooltip for additional notes"))
          .font(AppTheme.caption)
          .foregroundColor(AppTheme.secondaryText)
          .transition(.opacity)
          .onAppear {
              logger.log("Displaying notes tooltip")
          }
      }
      if viewModel.notes.count > 250 {
        Text(NSLocalizedString("Notes must be 250 characters or less.", comment: "Warning for note length"))
          .font(AppTheme.caption)
          .foregroundColor(.red)
      }
    }
  }

  /// Builds the image picker section with validation alerts.
  @ViewBuilder
  private func dogImageSection() -> some View {
    Section(header: sectionHeader(icon: "photo.fill", title: "Dog Image")) {
      PhotosPicker(
        selection: Binding(
          get: { nil },
          set: { newValue in viewModel.handleImageSelection(newValue) }
        ),
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
            .font(AppTheme.body)
        }
      }
      .alert(NSLocalizedString("Invalid Image", comment: "Alert title for invalid image"), isPresented: $viewModel.imageValidationError) {
        Button(NSLocalizedString("OK", comment: "Dismiss alert button"), role: .cancel) {}
      } message: {
        Text(NSLocalizedString("Please select an image under 5MB with appropriate dimensions.", comment: "Message for invalid image size or dimensions"))
          .font(AppTheme.body)
      }
    }
  }

  // MARK: - Toolbar Content

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      Button(NSLocalizedString("Cancel", comment: "Cancel button label")) {
          logger.log("AddDogOwnerView Cancel tapped")
          withAnimation { dismiss() }
      }
      .buttonStyle(FurfolioButtonStyle())
      .accessibilityLabel(NSLocalizedString("Cancel", comment: "Accessibility label for cancel button"))
    }
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(NSLocalizedString("Save", comment: "Save button label")) {
          logger.log("AddDogOwnerView Save tapped: ownerName=\(viewModel.ownerName), dogName=\(viewModel.dogName)")
          viewModel.handleSave(onSave: onSave, dismiss: { dismiss() })
      }
      .disabled(viewModel.isSaving || !validateFields())
      .buttonStyle(FurfolioButtonStyle())
      .accessibilityLabel(NSLocalizedString("Save Dog Owner", comment: "Accessibility label for save button"))
    }
  }

  // MARK: - Utility Methods

  /// Returns a section header view with an icon and title.
  private func sectionHeader(icon: String, title: String) -> some View {
    HStack {
      Image(systemName: icon)
      Text(NSLocalizedString(title, comment: "Section header"))
        .font(AppTheme.body)
    }
  }

  /// A reusable custom text field.
  private func customTextField(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
    TextField(NSLocalizedString(placeholder, comment: "Placeholder for \(placeholder)"), text: text)
      .keyboardType(keyboardType)
      .textFieldStyle(RoundedBorderTextFieldStyle())
      .font(AppTheme.body)
  }

  /// Validates inputs and invokes onSave closure, showing a saving overlay.
  private func validateFields() -> Bool {
    do {
      try FormValidator.validateRequired(viewModel.ownerName, fieldName: "Owner Name")
      try FormValidator.validateRequired(viewModel.dogName, fieldName: "Dog Name")
      try FormValidator.validateRequired(viewModel.breed, fieldName: "Breed")
      return true
    } catch {
      return false
    }
  }

  /// Truncates notes to 250 characters.
  private func limitNotesLength() {
    if viewModel.notes.count > 250 {
      viewModel.notes = String(viewModel.notes.prefix(250))
    }
  }

  /// Computes an emoji badge based on keywords in notes.
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
