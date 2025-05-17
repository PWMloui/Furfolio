///
//  DogOwnerRowView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, transitions, haptic feedback, swipe actions for quick editing, and additional status indicators.

import SwiftUI

// TODO: Move business logic (tag generation, haptic feedback, and deletion) into a dedicated ViewModel for cleaner views and testing.

@MainActor
/// Row view displaying a dog owner’s avatar, details, and status badges, with tap, swipe, and haptic interactions.
struct DogOwnerRowView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var showingEditSheet = false
  @State private var showDeleteAlert = false
  @Binding var selectedOwner: DogOwner?
  let dogOwner: DogOwner

  var body: some View {
    Button {
      let generator = UIImpactFeedbackGenerator(style: .medium)
      generator.impactOccurred()
      selectedOwner = dogOwner
    } label: {
      HStack(spacing: 12) {
        // Dog image section with scaling and opacity transitions.
        dogImageSection()
          .transition(.scale.combined(with: .opacity))
          .animation(.spring(), value: dogOwner.dogImage)

        // Owner details section fades in.
        ownerDetailsSection()
          .transition(.opacity)
          .animation(.easeIn(duration: 0.3), value: dogOwner.ownerName)

        Spacer()

        // Tag for upcoming appointments (if any).
        upcomingAppointmentsTag()
          .transition(.scale.combined(with: .opacity))
          .animation(.spring(), value: dogOwner.hasUpcomingAppointments)

        // If essential owner info is missing, show an "Incomplete" badge.
        if !dogOwner.isValidOwner {
          incompleteInfoTag()
            .transition(.opacity)
            .animation(.easeIn(duration: 0.3), value: dogOwner.isValidOwner)
        }

        if !dogOwner.loyaltyStatus.isEmpty && dogOwner.loyaltyStatus != "New" {
          TagLabelView(text: dogOwner.loyaltyStatus, backgroundColor: .yellow, textColor: .orange)
            .accessibilityLabel(Text("Loyalty status: \(dogOwner.loyaltyStatus)"))
        }

        // 🎂 Birthday tag if pet's birthday is this month
        if dogOwner.hasBirthdayThisMonth {
          TagLabelView(text: "🎂 Birthday", backgroundColor: Color.purple.opacity(0.2), textColor: .purple)
        }

        // ⚠️ Retention Risk tag if owner hasn't had activity in 60+ days
        if dogOwner.retentionRisk {
          TagLabelView(text: "⚠️ Retention Risk", backgroundColor: Color.orange.opacity(0.2), textColor: .orange)
        }

        // 💸 Top Spender tag if their total charge value is high
        if let tag = dogOwner.lifetimeValueTag {
          TagLabelView(text: tag, backgroundColor: Color.yellow.opacity(0.2), textColor: .yellow)
        }
      }
      .padding(.vertical, 8)
      .accessibilityElement(children: .combine)
    }
    .buttonStyle(PlainButtonStyle())
    .swipeActions(edge: .trailing) {
      Button {
        showingEditSheet = true
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      Button(role: .destructive) {
        showDeleteAlert = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
    .sheet(isPresented: $showingEditSheet) {
      EditDogOwnerView(dogOwner: dogOwner, onSave: { _ in })
    }
    .alert("Delete Dog Owner?", isPresented: $showDeleteAlert) {
      Button("Delete", role: .destructive) {
        modelContext.delete(dogOwner)
      }
      Button("Cancel", role: .cancel) { }
    }
  }

  /// Displays the owner’s image or initials with styling and accessibility.
  @ViewBuilder private func dogImageSection() -> some View {
    if let imageData = dogOwner.dogImage, let image = UIImage(data: imageData) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
        .accessibilityLabel(String(format: NSLocalizedString("%@'s dog image", comment: "Accessibility label for dog image"), dogOwner.ownerName))
    } else {
      // If no image is available, show a placeholder with the owner's initials.
      Circle()
        .fill(Color.gray.opacity(0.4))
        .frame(width: 50, height: 50)
        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
        .overlay(
          Text(dogOwner.ownerName.prefix(1).uppercased())
            .font(.headline)
            .foregroundColor(.white)
        )
        .accessibilityLabel(String(format: NSLocalizedString("%@'s initials", comment: "Accessibility label for initials"), dogOwner.ownerName))
    }
  }

  /// Shows the owner name, dog name, breed, notes, and small badges for loyalty and behavior.
  @ViewBuilder private func ownerDetailsSection() -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(dogOwner.ownerName)
        .font(.headline)
        .foregroundColor(.primary)
        .lineLimit(1)

      Text(dogOwner.dogName)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .lineLimit(1)

      if !dogOwner.breed.isEmpty {
        Text(String(format: NSLocalizedString("Breed: %@", comment: "Label for dog breed"), dogOwner.breed))
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      if !dogOwner.notes.isEmpty {
        Text(String(format: NSLocalizedString("Notes: %@", comment: "Label for notes"), dogOwner.notes))
          .font(.caption2)
          .foregroundColor(.secondary)
          .italic()
          .lineLimit(2)
      }

      // Loyalty progress and behavior trend badges
      if !dogOwner.loyaltyProgressTag.isEmpty {
        Text("Loyalty: \(dogOwner.loyaltyProgressTag)")
          .font(.caption2)
          .foregroundColor(.green)
      }

      if !dogOwner.behaviorTrendBadge.isEmpty {
        Text("Behavior: \(dogOwner.behaviorTrendBadge)")
          .font(.caption2)
          .foregroundColor(.orange)
      }
    }
  }

  /// Badge indicating upcoming appointments.
  @ViewBuilder private func upcomingAppointmentsTag() -> some View {
    if dogOwner.hasUpcomingAppointments {
      Text(NSLocalizedString("Upcoming", comment: "Label for upcoming appointments"))
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
        .foregroundColor(.blue)
        .accessibilityLabel(NSLocalizedString("Upcoming appointments", comment: "Accessibility label for upcoming appointments tag"))
    }
  }

  /// Badge indicating incomplete profile information.
  @ViewBuilder private func incompleteInfoTag() -> some View {
    Text(NSLocalizedString("Incomplete", comment: "Badge for incomplete owner info"))
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.red.opacity(0.2))
      .cornerRadius(8)
      .foregroundColor(.red)
      .accessibilityLabel(NSLocalizedString("Incomplete owner information", comment: "Accessibility label for incomplete info tag"))
  }
}
