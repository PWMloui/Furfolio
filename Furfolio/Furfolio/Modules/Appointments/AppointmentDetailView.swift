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

                // Enhanced Conflict Banner: Shows a colored chip with overlap range, summary array, and conflicting appointments.
                // Includes info popover/sheet, accessibility, event logging, and toast for auto-dismiss
                if viewModel.hasConflict, let conflictMsg = viewModel.conflictMessage {
                    EnhancedAppointmentConflictBanner(
                        overlapChip: {
                            // Show colored chip for overlap time range if available
                            if let overlapRange = viewModel.conflictOverlapRange {
                                ChipLabel(text: "Overlap: \(overlapRange)", color: .red)
                                    .accessibilityLabel("Overlap: \(overlapRange)")
                            }
                        }(),
                        summary: viewModel.conflictSummary, // Array of summary strings
                        conflictingAppointments: viewModel.conflictingAppointments.map { conflict in
                            EnhancedAppointmentConflictBanner.ConflictingAppointment(
                                time: conflict.time,
                                dog: conflict.dog,
                                owner: conflict.owner,
                                onView: {
                                    // For demo: print which appointment is being viewed
                                    print("View conflicting appointment at \(conflict.time) for \(conflict.dog) / \(conflict.owner)")
                                    AppointmentDetailAudit.record(
                                        operation: "viewConflict",
                                        appointmentID: viewModel.appointment.id,
                                        tags: ["conflict", "viewOther"],
                                        detail: "Viewed conflicting appointment: \(conflict.dog), \(conflict.owner), \(conflict.time)"
                                    )
                                }
                            )
                        },
                        onResolve: {
                            showEdit = true
                            AppointmentDetailAudit.record(
                                operation: "editSheet",
                                appointmentID: viewModel.appointment.id,
                                tags: ["editSheet", "fromConflict"],
                                detail: "Edit sheet opened via enhanced conflict banner"
                            )
                        },
                        onInfo: {
                            // Show info popover/sheet as designed
                            showConflictInfoSheet = true
                            AppointmentDetailAudit.record(
                                operation: "showConflictInfo",
                                appointmentID: viewModel.appointment.id,
                                tags: ["conflict", "info"],
                                detail: "Conflict info sheet shown"
                            )
                        },
                        isVisible: $conflictBannerVisible, // Bind to local state for auto-dismiss
                        onAutoDismiss: {
                            // Show brief toast/overlay when banner is auto-dismissed
                            showConflictDismissedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showConflictDismissedToast = false
                            }
                            AppointmentDetailAudit.record(
                                operation: "conflictBannerDismissed",
                                appointmentID: viewModel.appointment.id,
                                tags: ["conflict", "bannerDismissed"],
                                detail: "Conflict banner auto-dismissed"
                            )
                        }
                    )
                    .accessibilityIdentifier("conflict_banner")
                    .padding(.top, 6)
                    .onAppear {
                        AppointmentDetailAudit.record(
                            operation: "showConflict",
                            appointmentID: viewModel.appointment.id,
                            tags: ["conflict", "enhancedBanner"],
                            detail: viewModel.conflictMessage
                        )
                    }
                }
    // MARK: - Enhanced Conflict Banner Local State
    @State private var conflictBannerVisible: Bool = true
    @State private var showConflictInfoSheet: Bool = false
    @State private var showConflictDismissedToast: Bool = false
        // Info sheet for conflict details (shown from info button in banner)
        .sheet(isPresented: $showConflictInfoSheet) {
            ConflictInfoSheetView(summary: viewModel.conflictSummary)
        }
        // Toast overlay for conflict banner auto-dismiss
        .overlay(
            Group {
                if showConflictDismissedToast {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Conflict warning dismissed.")
                                .foregroundColor(.white)
                                .bold()
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(10)
                        Spacer()
                    }
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        )

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

// MARK: - Enhanced Conflict Banner API Placeholders
// These would be implemented elsewhere in the real app, but are stubbed here for demo/testing.
struct EnhancedAppointmentConflictBanner: View {
    struct ConflictingAppointment: Identifiable {
        let id = UUID()
        let time: String
        let dog: String
        let owner: String
        let onView: () -> Void
    }
    let overlapChip: AnyView?
    let summary: [String]
    let conflictingAppointments: [ConflictingAppointment]
    let onResolve: () -> Void
    let onInfo: () -> Void
    @Binding var isVisible: Bool
    let onAutoDismiss: () -> Void

    // Demo: simulate auto-dismiss after 7 seconds
    @State private var timerStarted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Appointment Conflict")
                    .fontWeight(.bold)
                Spacer()
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .accessibilityLabel("More conflict info")
                }
            }
            if let chip = overlapChip {
                chip
            }
            ForEach(summary, id: \.self) { item in
                Text("• \(item)")
                    .font(.subheadline)
                    .accessibilityLabel(item)
            }
            if !conflictingAppointments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conflicting Appointments:")
                        .font(.footnote).bold()
                    ForEach(conflictingAppointments) { appt in
                        HStack {
                            Text("\(appt.time): \(appt.dog) (\(appt.owner))")
                                .font(.footnote)
                            Spacer()
                            Button("View") {
                                appt.onView()
                            }
                            .accessibilityLabel("View conflicting appointment: \(appt.dog)")
                        }
                    }
                }
            }
            Button("Resolve") {
                onResolve()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Resolve conflict")
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appointment conflict warning. \(summary.joined(separator: ", "))")
        .onAppear {
            // Start auto-dismiss timer once
            if !timerStarted {
                timerStarted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    if isVisible {
                        isVisible = false
                        onAutoDismiss()
                    }
                }
            }
        }
    }
}

// Demo chip label for overlap range
struct ChipLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.8))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// Info sheet for conflict details
struct ConflictInfoSheetView: View {
    let summary: [String]
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Conflict Details")) {
                    ForEach(summary, id: \.self) { item in
                        Text(item)
                    }
                }
            }
            .navigationTitle("Conflict Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        // Dismiss handled by SwiftUI sheet
                    }
                }
            }
        }
    }
}

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
    // Enhanced banner additions:
    var conflictOverlapRange: String? {
        // Demo: try to extract time range from message, or return nil
        // Example: "Overlaps with Bella's nail trim at 3:00 PM." → "3:00–3:30 PM"
        // In real code, this would use actual overlap data.
        if let msg = appointment.conflictMessage,
           let timeRange = msg.components(separatedBy: "at ").last?.components(separatedBy: ".").first {
            // Demo: assume duration is 30m
            return "\(timeRange)–\(addMinutes(to: timeRange, minutes: 30))"
        }
        return nil
    }
    var conflictSummary: [String] {
        // Demo: return array of conflict summary lines
        [
            "Reason: Overlapping appointment.",
            "Service: \(appointment.serviceType)",
            "Dog: \(dogName)",
            "Owner: \(ownerName)"
        ]
    }
    var conflictingAppointments: [ConflictingAppointmentStub] {
        // Demo: return one fake conflicting appointment for preview/testing
        if appointment.hasConflict {
            return [
                ConflictingAppointmentStub(
                    time: "3:00 PM",
                    dog: "Bella",
                    owner: "Jane Doe"
                )
            ]
        }
        return []
    }
    struct ConflictingAppointmentStub: Identifiable {
        let id = UUID()
        let time: String
        let dog: String
        let owner: String
    }
    // Helper for overlap chip
    private func addMinutes(to time: String, minutes: Int) -> String {
        // Parse "3:00 PM" and add minutes; fallback to "?" if parsing fails
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let date = formatter.date(from: time) {
            let newDate = date.addingTimeInterval(TimeInterval(minutes * 60))
            return formatter.string(from: newDate)
        }
        return "?"
    }

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
