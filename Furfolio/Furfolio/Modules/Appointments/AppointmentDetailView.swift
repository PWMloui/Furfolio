//
//  AppointmentDetailView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Unified, enhanced, and cleaned for Furfolio 2025
//

// MARK: - AppointmentDetailView (Tokenized, Modular, Auditable Appointment Detail UI)

import SwiftUI

struct AppointmentDetailView: View {
    @ObservedObject var viewModel: AppointmentDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // Sheet/presentation state
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Conflict warning (modular, animated, accessible)
                if viewModel.hasConflict, let conflictMsg = viewModel.conflictMessage {
                    AppointmentConflictBanner(
                        message: conflictMsg,
                        onResolve: { showEdit = true },
                        isVisible: .constant(true)
                    )
                    .accessibilityIdentifier("conflict_banner")
                    .padding(.top, 6)
                }

                // Dog/Owner/Service Summary
                HStack(alignment: .center, spacing: 20) {
                    ProfileImageView(image: viewModel.dogImage)
                    VStack(alignment: .leading, spacing: 6) {
                        // Using modular font and accessibility label
                        Text(viewModel.dogName)
                            .font(AppFonts.title3Bold) // Tokenized font for title3 bold
                            .accessibilityLabel("Dog Name: \(viewModel.dogName)")
                        Text(viewModel.ownerName)
                            .font(AppFonts.subheadline) // Tokenized font for subheadline
                            .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color
                            .accessibilityLabel("Owner: \(viewModel.ownerName)")
                        Text(viewModel.serviceType)
                            .font(AppFonts.callout) // Tokenized font for callout
                            .foregroundColor(AppColors.accent) // Tokenized accent color
                            .accessibilityLabel("Service: \(viewModel.serviceType)")
                    }
                }
                .padding(.top, 12)

                // Date, Time, Duration
                AppointmentMetaView(
                    dateString: viewModel.dateString,
                    durationString: viewModel.durationString
                )

                // Tags (badges)
                if !viewModel.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            AnimatedBadgeView(label: tag, color: .purple)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Tags: \(viewModel.tags.joined(separator: ", "))")
                }

                // Notes
                if !viewModel.notes.isEmpty {
                    SectionBox(title: "Notes") {
                        Text(viewModel.notes)
                            .font(AppFonts.body) // Tokenized body font
                            .foregroundColor(AppColors.textPrimary) // Tokenized primary text color
                            .padding(8)
                    }
                }

                // Behavior Log
                if !viewModel.behaviorLog.isEmpty {
                    SectionBox(title: "Behavior Log") {
                        ForEach(viewModel.behaviorLog, id: \.date) { entry in
                            HStack {
                                Text(viewModel.formatDate(entry.date))
                                    .font(AppFonts.caption) // Tokenized caption font
                                    .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color
                                Spacer()
                                Text(entry.mood)
                                if let note = entry.note, !note.isEmpty {
                                    Text("— \(note)").foregroundColor(.gray)
                                }
                            }
                            .padding(6)
                            .background(AppColors.warningBackground) // Tokenized warning background color
                            .cornerRadius(6)
                        }
                    }
                }

                // Edit/Reschedule button
                Button {
                    showEdit = true
                } label: {
                    Label("Edit / Reschedule", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Edit or Reschedule Appointment")
                }
                .buttonStyle(PulseButtonStyle(color: AppColors.accent)) // Tokenized button color
                .padding(.top, 14)
            }
            .padding()
            .navigationTitle("Appointment Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddAppointmentView(viewModel: viewModel.editViewModel)
        }
    }
}

// MARK: - Modular Subviews

private struct ProfileImageView: View {
    let image: UIImage?
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .foregroundColor(AppColors.accent) // Tokenized accent color
                    .background(Circle().fill(AppColors.accentBackground)) // Tokenized accent background color
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.accent, lineWidth: 2)) // Tokenized accent stroke color
        .shadow(color: AppShadows.medium.color, radius: AppShadows.medium.radius, x: AppShadows.medium.x, y: AppShadows.medium.y) // Tokenized shadow
        .accessibilityLabel("Dog Photo")
    }
}

private struct AppointmentMetaView: View {
    let dateString: String
    let durationString: String?
    var body: some View {
        HStack(spacing: 16) {
            Label(dateString, systemImage: "calendar")
                .font(AppFonts.subheadline) // Tokenized subheadline font
            if let duration = durationString {
                Label(duration, systemImage: "clock")
                    .font(AppFonts.subheadline) // Tokenized subheadline font
                    .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// A simple container for sectioned data
private struct SectionBox<Content: View>: View {
    let title: String
    let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    var body: some View {
        HStack(alignment: .center, spacing: spacing, content: content)
    }
}

// MARK: - ViewModel

final class AppointmentDetailViewModel: ObservableObject {
    @Published var appointment: Appointment

    // Computed properties for view
    var dogName: String { appointment.dog?.name ?? "Dog" }
    var dogImage: UIImage? { appointment.dog?.image }
    var ownerName: String { appointment.owner?.ownerName ?? "Owner" }
    var serviceType: String { appointment.serviceType }
    var dateString: String { DateFormatter.localizedString(from: appointment.date, dateStyle: .medium, timeStyle: .short) }
    var durationString: String? {
        appointment.duration > 0 ? "\(appointment.duration) min" : nil
    }
    var tags: [String] { appointment.tags ?? [] }
    var notes: String { appointment.notes ?? "" }
    var behaviorLog: [BehaviorLogEntry] { appointment.behaviorLog ?? [] }

    // Conflict
    var hasConflict: Bool { appointment.hasConflict }
    var conflictMessage: String? { appointment.conflictMessage }

    // View model for editing
    var editViewModel: AddAppointmentViewModel {
        AddAppointmentViewModel(
            owners: [appointment.owner].compactMap { $0 },
            serviceTypes: ["Full Groom", "Bath Only", "Nail Trim"],
            availableTags: ["VIP", "Aggressive", "First Visit", "Sensitive Skin"]
        )
    }

    init(appointment: Appointment) {
        self.appointment = appointment
    }

    func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - Placeholder Models

struct Appointment: Identifiable {
    var id: UUID
    var date: Date
    var dog: Dog?
    var owner: DogOwner?
    var serviceType: String
    var duration: Int = 0
    var tags: [String]? = []
    var notes: String? = ""
    var behaviorLog: [BehaviorLogEntry]? = []
    var hasConflict: Bool = false
    var conflictMessage: String? = nil
}

struct Dog: Identifiable, Hashable {
    var id: UUID
    var name: String
    var image: UIImage? = nil
    var owner: DogOwner? = nil
}

struct DogOwner: Identifiable, Hashable {
    var id: UUID
    var ownerName: String
    var dogs: [Dog]? = nil
}

struct BehaviorLogEntry: Identifiable, Hashable {
    var id: UUID { dateHash }
    var date: Date
    var mood: String
    var note: String?
    var dateHash: UUID { UUID() }
}

// MARK: - Preview

// Demo/business/tokenized preview for AppointmentDetailView
#if DEBUG
struct AppointmentDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let owner = DogOwner(id: UUID(), ownerName: "Jane Doe")
        let dog = Dog(id: UUID(), name: "Bella", image: nil, owner: owner)
        let appointment = Appointment(
            id: UUID(),
            date: Date(),
            dog: dog,
            owner: owner,
            serviceType: "Full Groom",
            duration: 90,
            tags: ["VIP", "First Visit"],
            notes: "Special shampoo, gentle handling.",
            behaviorLog: [
                BehaviorLogEntry(date: Date(), mood: "🟢 Calm", note: "Great with bath"),
                BehaviorLogEntry(date: Date().addingTimeInterval(-3600*24), mood: "🔴 Nervous", note: "Needed more breaks")
            ],
            hasConflict: true,
            conflictMessage: "Overlaps with Bella's nail trim at 3:00 PM."
        )
        AppointmentDetailView(viewModel: AppointmentDetailViewModel(appointment: appointment))
    }
}
#endif
