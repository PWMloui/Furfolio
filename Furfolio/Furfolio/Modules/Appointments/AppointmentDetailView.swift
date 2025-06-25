//
//  AppointmentDetailView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Unified, enhanced, and cleaned for Furfolio 2025
//

// MARK: - AppointmentDetailView (Tokenized, Modular, Auditable Appointment Detail UI)

import SwiftUI

fileprivate struct AppointmentDetailAuditEvent: Codable {
    let timestamp: Date
    let operation: String         // "view", "editSheet", "close", "showConflict"
    let appointmentID: UUID
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentDetailAudit {
    static private(set) var log: [AppointmentDetailAuditEvent] = []

    static func record(
        operation: String,
        appointmentID: UUID,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentDetailView",
        detail: String? = nil
    ) {
        let event = AppointmentDetailAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No appointment detail actions recorded."
    }
}


// MARK: - AppointmentDetailView

struct AppointmentDetailView: View {
    @ObservedObject var viewModel: AppointmentDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Conflict warning (modular, animated, accessible)
                if viewModel.hasConflict, let conflictMsg = viewModel.conflictMessage {
                    AppointmentConflictBanner(
                        message: conflictMsg,
                        onResolve: {
                            showEdit = true
                            AppointmentDetailAudit.record(
                                operation: "editSheet",
                                appointmentID: viewModel.appointment.id,
                                tags: ["editSheet", "fromConflict"],
                                detail: "Edit sheet opened via conflict banner"
                            )
                        },
                        isVisible: .constant(true)
                    )
                    .accessibilityIdentifier("conflict_banner")
                    .padding(.top, 6)
                    .onAppear {
                        AppointmentDetailAudit.record(
                            operation: "showConflict",
                            appointmentID: viewModel.appointment.id,
                            tags: ["conflict"],
                            detail: viewModel.conflictMessage
                        )
                    }
                }

                // Dog/Owner/Service Summary
                HStack(alignment: .center, spacing: 20) {
                    ProfileImageView(image: viewModel.dogImage)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.dogName)
                            .font(AppFonts.title3Bold)
                            .accessibilityLabel("Dog Name: \(viewModel.dogName)")
                        Text(viewModel.ownerName)
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                            .accessibilityLabel("Owner: \(viewModel.ownerName)")
                        Text(viewModel.serviceType)
                            .font(AppFonts.callout)
                            .foregroundColor(AppColors.accent)
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
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(8)
                    }
                }

                // Behavior Log
                if !viewModel.behaviorLog.isEmpty {
                    SectionBox(title: "Behavior Log") {
                        ForEach(viewModel.behaviorLog, id: \.date) { entry in
                            HStack {
                                Text(viewModel.formatDate(entry.date))
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Spacer()
                                Text(entry.mood)
                                if let note = entry.note, !note.isEmpty {
                                    Text("— \(note)").foregroundColor(.gray)
                                }
                            }
                            .padding(6)
                            .background(AppColors.warningBackground)
                            .cornerRadius(6)
                        }
                    }
                }

                // Edit/Reschedule button
                Button {
                    showEdit = true
                    AppointmentDetailAudit.record(
                        operation: "editSheet",
                        appointmentID: viewModel.appointment.id,
                        tags: ["editSheet"],
                        detail: "Edit sheet opened from button"
                    )
                } label: {
                    Label("Edit / Reschedule", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Edit or Reschedule Appointment")
                }
                .buttonStyle(PulseButtonStyle(color: AppColors.accent))
                .padding(.top, 14)
            }
            .padding()
            .navigationTitle("Appointment Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        AppointmentDetailAudit.record(
                            operation: "close",
                            appointmentID: viewModel.appointment.id,
                            tags: ["close"],
                            detail: "Detail view closed"
                        )
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            AppointmentDetailAudit.record(
                operation: "view",
                appointmentID: viewModel.appointment.id,
                tags: ["view"],
                detail: "Appointment detail viewed"
            )
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

public enum AppointmentDetailAuditAdmin {
    public static var lastSummary: String { AppointmentDetailAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentDetailAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentDetailAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
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
