//
//  OwnerProfileView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with modern navigation, animations, haptic feedback, extended pet details, and document attachment sections.

import SwiftUI
import SwiftData
import os

// TODO: Move data formatting, badge logic, and navigation state into an OwnerProfileViewModel for cleaner view code and easier testing.

@MainActor
/// Displays a detailed profile for a DogOwner, including info, pets, documents, and history sections.
struct OwnerProfileView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "OwnerProfileView")
    let dogOwner: DogOwner

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var showAppointments = true
    @State private var showCharges = true
    @State private var showAddAppointment = false
    @State private var showAddCharge = false

    /// Shared formatter for dates in history sections.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Owner Info Section
                    ownerInfoSection()
                        .transition(.slide)
                    
                    // Dog Info Section (includes primary dog info)
                    dogInfoSection()
                        .transition(.opacity)
                    
                    // Pet Details Section (if multiple pets are recorded)
                    petDetailsSection()
                        .transition(.move(edge: .leading))
                    
                    // Document Attachments Section (if any documents are attached)
                    documentAttachmentsSection()
                        .transition(.move(edge: .trailing))
                    
                    // Appointment History Section
                    appointmentHistorySection()
                        .transition(.move(edge: .bottom))
                    
                    // Charge History Section
                    chargeHistorySection()
                        .transition(.move(edge: .bottom))
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Owner Profile", comment: "Title for Owner Profile view"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                    .accessibilityLabel("More Options")
                }
            }
            .sheet(isPresented: $isEditing) {
                EditDogOwnerView(dogOwner: dogOwner) { updatedOwner in
                    isEditing = false
                }
            }
            .sheet(isPresented: $showAddAppointment) {
                AddAppointmentView(dogOwner: dogOwner)
            }
            .sheet(isPresented: $showAddCharge) {
                AddChargeView(dogOwner: dogOwner)
            }
            .refreshable {
                // Future: Insert logic to refresh/reload owner data if needed.
            }
            .confirmationDialog("Are you sure you want to delete this owner?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    logger.log("Confirmed delete for owner id: \(dogOwner.id)")
                    modelContext.delete(dogOwner)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                logger.log("OwnerProfileView appeared for owner id: \(dogOwner.id)")
            }
        }
    }
    
    /// Shows the owner’s name, contact details, and status badges.
    @ViewBuilder
    private func ownerInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dogOwner.ownerName)
                .font(.title)
                .bold()
            // Consolidate status tags into a single list
            let badgeItems: [(text: String, color: Color)] = [
                dogOwner.hasBirthdayThisMonth ? ("🎂 Birthday Month", .purple) : nil,
                dogOwner.retentionRisk ? ("⚠️ Retention Risk", .orange) : nil,
                dogOwner.lifetimeValueTag.map { ($0, .yellow) },
                !dogOwner.loyaltyProgressTag.isEmpty ? (dogOwner.loyaltyProgressTag, .green) : nil,
                !dogOwner.behaviorTrendBadge.isEmpty ? (dogOwner.behaviorTrendBadge, .orange) : nil
            ].compactMap { $0 }
            ForEach(badgeItems, id: \.text) { item in
                TagLabelView(text: item.text, backgroundColor: item.color, textColor: item.color)
            }
            contactInfoText
            addressText
        }
        .padding()
        .cardStyle()
        .onAppear {
            logger.log("ownerInfoSection rendered with badges count: \(badgeItems.count)")
        }
    }
    
    /// Shows primary dog info including image and basic details.
    @ViewBuilder
    private func dogInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Dog Info", comment: "Header for Dog Info section"))
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            Text(String(format: NSLocalizedString("Name: %@", comment: "Dog name label"), dogOwner.dogName))
            Text(String(format: NSLocalizedString("Breed: %@", comment: "Dog breed label"), dogOwner.breed))
            if !dogOwner.notes.isEmpty {
                Text(String(format: NSLocalizedString("Notes: %@", comment: "Dog notes label"), dogOwner.notes))
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            dogImageView
                .onAppear {
                    logger.log("dogInfoSection rendered; image available: \(dogOwner.dogImage != nil)")
                }
        }
        .padding()
        .cardStyle()
    }
    
    /// Lists additional pet profiles with key details.
    @ViewBuilder
    private func petDetailsSection() -> some View {
        if !dogOwner.pets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Pet Details", comment: "Section header for pet details"))
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ForEach(dogOwner.pets) { pet in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: NSLocalizedString("Name: %@", comment: "Pet name label"), pet.name))
                        Text(String(format: NSLocalizedString("Breed: %@", comment: "Pet breed label"), pet.breed))
                        if let petAge = pet.age {
                            Text(String(format: NSLocalizedString("Age: %d years", comment: "Pet age label"), petAge))
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        if let instructions = pet.specialInstructions, !instructions.isEmpty {
                            Text(String(format: NSLocalizedString("Special Instructions: %@", comment: "Pet instructions label"), instructions))
                                .font(.caption2)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .cardStyle()
        }
    }
    
    /// Displays document attachments for this owner.
    @ViewBuilder
    private func documentAttachmentsSection() -> some View {
        if !dogOwner.documentAttachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Documents", comment: "Section header for documents"))
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ForEach(dogOwner.documentAttachments, id: \.self) { url in
                    Link(destination: url) {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .underline()
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }
    
    /// Shows the owner’s past appointments with show/hide toggle.
    @ViewBuilder
    private func appointmentHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("Appointment History", comment: "Header for Appointment History section"))
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Button(action: {
                    logger.log("\(showAppointments ? "Hide" : "Show") Appointment History tapped")
                    withAnimation { showAppointments.toggle() }
                }) {
                    Text(showAppointments ? NSLocalizedString("Hide", comment: "Hide button label") : NSLocalizedString("Show", comment: "Show button label"))
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.accent)
                }
                addAppointmentButton
            }
            if showAppointments {
                appointmentList
                    .transition(.opacity)
            }
        }
        .padding()
        .cardStyle()
    }
    
    /// Shows the owner’s past charges with show/hide toggle.
    @ViewBuilder
    private func chargeHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("Charge History", comment: "Header for Charge History section"))
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Button(action: {
                    logger.log("\(showCharges ? "Hide" : "Show") Charge History tapped")
                    withAnimation { showCharges.toggle() }
                }) {
                    Text(showCharges ? NSLocalizedString("Hide", comment: "Hide button label") : NSLocalizedString("Show", comment: "Show button label"))
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.accent)
                }
                addChargeButton
            }
            if showCharges {
                chargeList
                    .transition(.opacity)
            }
        }
        .padding()
        .cardStyle()
    }
    
    // MARK: - Helper Views
    private var contactInfoText: some View {
        Group {
            if !dogOwner.contactInfo.isEmpty {
                Text(String(format: NSLocalizedString("Contact: %@", comment: "Contact information label"), dogOwner.contactInfo))
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
    }
    
    private var addressText: some View {
        Group {
            if !dogOwner.address.isEmpty {
                Text(String(format: NSLocalizedString("Address: %@", comment: "Address information label"), dogOwner.address))
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
    }
    
    private var dogImageView: some View {
        Group {
            if let imageData = dogOwner.dogImage, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.disabled, lineWidth: 1))
                    .padding(.top)
            } else {
                Text(NSLocalizedString("No image available", comment: "Message for missing dog image"))
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
    }
    
    private var addAppointmentButton: some View {
        Button {
            logger.log("AddAppointment tapped for owner id: \(dogOwner.id)")
            showAddAppointment = true
        } label: {
            Image(systemName: "calendar.badge.plus")
                .font(AppTheme.header)
        }
        .buttonStyle(FurfolioButtonStyle())
    }
    
    private var addChargeButton: some View {
        Button {
            logger.log("AddCharge tapped for owner id: \(dogOwner.id)")
            showAddCharge = true
        } label: {
            Image(systemName: "plus.circle")
                .font(AppTheme.header)
        }
        .buttonStyle(FurfolioButtonStyle())
    }
    
    private var appointmentList: some View {
        Group {
            if dogOwner.appointments.isEmpty {
                Text(NSLocalizedString("No appointments available.", comment: "Message for no appointments"))
                    .foregroundColor(AppTheme.secondaryText)
                    .italic()
            } else {
                ForEach(dogOwner.appointments.sorted(by: { $0.date > $1.date })) { appointment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: NSLocalizedString("Date: %@", comment: "Appointment date label"), appointment.date.formatted(.dateTime.month().day().year())))
                        Text(String(format: NSLocalizedString("Service: %@", comment: "Service type label"), appointment.serviceType.rawValue))
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        if let notes = appointment.notes, !notes.isEmpty {
                            Text(String(format: NSLocalizedString("Notes: %@", comment: "Appointment notes label"), notes))
                                .font(.caption2)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var chargeList: some View {
        Group {
            if dogOwner.charges.isEmpty {
                Text(NSLocalizedString("No charges recorded.", comment: "Message for no charges"))
                    .foregroundColor(AppTheme.secondaryText)
                    .italic()
            } else {
                ForEach(dogOwner.charges.sorted(by: { $0.date > $1.date })) { charge in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: NSLocalizedString("Date: %@", comment: "Charge date label"), charge.date.formatted(.dateTime.month().day().year())))
                            Text(String(format: NSLocalizedString("Type: %@", comment: "Charge type label"), charge.type.rawValue))
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText)
                            if let notes = charge.notes, !notes.isEmpty {
                                Text(String(format: NSLocalizedString("Notes: %@", comment: "Charge notes label"), notes))
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        Spacer()
                        Text(charge.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
