///
//  DogOwnerRowView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, transitions, haptic feedback, swipe actions for quick editing, and additional status indicators.

import SwiftUI
import os

// TODO: Move business logic (tag generation, haptic feedback, and deletion) into a dedicated ViewModel for cleaner views and testing.

@MainActor
class DogOwnerRowViewModel: ObservableObject {
  static let imageCache = NSCache<NSString, UIImage>()
  @Published var uiImage: UIImage?

  func loadImage(from data: Data?) {
    guard let data = data else {
      uiImage = nil
      return
    }
    let key = NSString(string: "\(data.hashValue)")
    if let cachedImage = DogOwnerRowViewModel.imageCache.object(forKey: key) {
      uiImage = cachedImage
    } else if let image = UIImage(data: data) {
      DogOwnerRowViewModel.imageCache.setObject(image, forKey: key)
      uiImage = image
    } else {
      uiImage = nil
    }
  }

  func select(owner: DogOwner, selected: Binding<DogOwner?>) {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    selected.wrappedValue = owner
  }
}

/// Row view displaying a dog owner’s avatar, details, and status badges, with tap, swipe, and haptic interactions.
struct DogOwnerRowView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DogOwnerRowView")
  @Environment(\.modelContext) private var modelContext
  @State private var showingEditSheet = false
  @State private var showDeleteAlert = false
  @Binding var selectedOwner: DogOwner?
  let dogOwner: DogOwner
  @StateObject private var viewModel = DogOwnerRowViewModel()

  var body: some View {
    Button {
      viewModel.select(owner: dogOwner, selected: $selectedOwner)
    } label: {
      HStack(spacing: 12) {
        // Dog image section with scaling and opacity transitions.
        dogImageSection()

        // Owner details section fades in.
        ownerDetailsSection()

        Spacer()

        // Tag for upcoming appointments (if any).
        upcomingAppointmentsTag()

        // If essential owner info is missing, show an "Incomplete" badge.
        if !dogOwner.isValidOwner {
          incompleteInfoTag()
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
      .animation(.spring(), value: dogOwner)
      .onAppear {
        logger.log("DogOwnerRowView appeared for owner id: \(dogOwner.id)")
      }
    }
    .buttonStyle(FurfolioButtonStyle())
    .swipeActions(edge: .trailing) {
      Button {
        showingEditSheet = true
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      .buttonStyle(FurfolioButtonStyle())
      Button(role: .destructive) {
        showDeleteAlert = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .buttonStyle(FurfolioButtonStyle())
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
    .onAppear {
      viewModel.loadImage(from: dogOwner.dogImage)
      logger.log("Loading image for owner id: \(dogOwner.id), imageData present: \(dogOwner.dogImage != nil)")
    }
  }

  /// Displays the owner’s image or initials with styling and accessibility.
  @ViewBuilder private func dogImageSection() -> some View {
    if let image = viewModel.uiImage {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.accent.opacity(0.5), lineWidth: 1))
        .accessibilityLabel(String(format: NSLocalizedString("%@'s dog image", comment: "Accessibility label for dog image"), dogOwner.ownerName))
    } else {
      // If no image is available, show a placeholder with the owner's initials.
      Circle()
        .fill(AppTheme.disabled.opacity(0.4))
        .overlay(
            Circle().stroke(AppTheme.accent, lineWidth: 1)
        )
        .frame(width: 50, height: 50)
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
        .font(AppTheme.body)
        .foregroundColor(AppTheme.primaryText)
        .lineLimit(1)

      Text(dogOwner.dogName)
        .font(AppTheme.caption)
        .foregroundColor(AppTheme.secondaryText)
        .lineLimit(1)

      if !dogOwner.breed.isEmpty {
        Text(String(format: NSLocalizedString("Breed: %@", comment: "Label for dog breed"), dogOwner.breed))
          .font(AppTheme.caption)
          .foregroundColor(AppTheme.secondaryText)
          .lineLimit(1)
      }

      if !dogOwner.notes.isEmpty {
        Text(String(format: NSLocalizedString("Notes: %@", comment: "Label for notes"), dogOwner.notes))
          .font(AppTheme.caption)
          .foregroundColor(AppTheme.secondaryText)
          .italic()
          .lineLimit(2)
      }

      // Loyalty progress and behavior trend badges
      if !dogOwner.loyaltyProgressTag.isEmpty {
        Text("Loyalty: \(dogOwner.loyaltyProgressTag)")
          .font(.caption2)
          .foregroundColor(AppTheme.accent)
      }

      if !dogOwner.behaviorTrendBadge.isEmpty {
        Text("Behavior: \(dogOwner.behaviorTrendBadge)")
          .font(.caption2)
          .foregroundColor(AppTheme.warning)
      }
    }
  }

  /// Badge indicating upcoming appointments.
  @ViewBuilder private func upcomingAppointmentsTag() -> some View {
    if dogOwner.hasUpcomingAppointments {
      Text(NSLocalizedString("Upcoming", comment: "Label for upcoming appointments"))
        .font(AppTheme.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.info.opacity(0.2))
        .cornerRadius(8)
        .foregroundColor(AppTheme.info)
        .accessibilityLabel(NSLocalizedString("Upcoming appointments", comment: "Accessibility label for upcoming appointments tag"))
    }
  }

  /// Badge indicating incomplete profile information.
  @ViewBuilder private func incompleteInfoTag() -> some View {
    Text(NSLocalizedString("Incomplete", comment: "Badge for incomplete owner info"))
      .font(AppTheme.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(AppTheme.warning.opacity(0.2))
      .cornerRadius(8)
      .foregroundColor(AppTheme.warning)
      .accessibilityLabel(NSLocalizedString("Incomplete owner information", comment: "Accessibility label for incomplete info tag"))
  }
}
