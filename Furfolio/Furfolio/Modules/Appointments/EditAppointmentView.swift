//
// MARK: - EditAppointmentView (Tokenized, Modular, Auditable Appointment Edit UI)
//
//  EditAppointmentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import UIKit

// MARK: - Audit/Event Logging

fileprivate struct EditAppointmentAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "appear", "editField", "toggleTag", "save", "cancel", "error", "conflictDetected"
    let appointmentID: UUID
    let field: String?
    let oldValue: String?
    let newValue: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let fieldPart = field.map { " field:\($0)" } ?? ""
        let tagStr = tags.isEmpty ? "" : " [\(tags.joined(separator: ","))]"
        let valuePart = newValue != nil ? " \"\(newValue!)\"" : ""
        return "[\(op)] \(appointmentID)\(fieldPart)\(valuePart)\(tagStr) at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class EditAppointmentAudit {
    static private(set) var log: [EditAppointmentAuditEvent] = []

    static func record(
        operation: String,
        appointmentID: UUID,
        field: String? = nil,
        oldValue: String? = nil,
        newValue: String? = nil,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "EditAppointmentView",
        detail: String? = nil
    ) {
        let event = EditAppointmentAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 300 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No edit events recorded."
    }

    /// Export all audit events as CSV string (for analytics/compliance)
    static func exportCSV() -> String {
        var csv = "timestamp,operation,appointmentID,field,oldValue,newValue,tags,actor,context,detail\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let ts = dateFormatter.string(from: event.timestamp)
            let op = event.operation
            let id = event.appointmentID.uuidString
            let field = event.field ?? ""
            let oldValue = event.oldValue?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let newValue = event.newValue?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tags = event.tags.joined(separator: "|")
            let actor = event.actor ?? ""
            let context = event.context ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let detailEscaped = "\"\(detail)\""
            csv += "\(ts),\(op),\(id),\(field),\"\(oldValue)\",\"\(newValue)\",\(tags),\(actor),\(context),\(detailEscaped)\n"
        }
        return csv
    }
}

// MARK: - Audit/Admin Accessors

public enum EditAppointmentAuditAdmin {
    public static var lastSummary: String { EditAppointmentAudit.accessibilitySummary }
    public static var lastJSON: String? { EditAppointmentAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        EditAppointmentAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Export all audit events as CSV string.
    public static func exportCSV() -> String { EditAppointmentAudit.exportCSV() }
}

// MARK: - EditAppointmentView

struct EditAppointmentView: View {
    @ObservedObject var viewModel: EditAppointmentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDurationPicker = false
    @State private var lastError: String? = nil

    // You must provide this from your parent view/model!
    var existingAppointments: [Appointment] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date & Time").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    DatePicker("Appointment Date", selection: $viewModel.date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("appointmentDatePicker")
                        .font(AppFonts.body)
                        .onChange(of: viewModel.date) { newVal in
                            EditAppointmentAudit.record(
                                operation: "editField",
                                appointmentID: viewModel.originalAppointment.id,
                                field: "date",
                                oldValue: Self.formatDate(viewModel.originalAppointment.date),
                                newValue: Self.formatDate(newVal),
                                tags: ["date"],
                                detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                            )
                        }
                }
                Section(header: Text("Client").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    Picker("Owner", selection: $viewModel.selectedOwner) {
                        Text("Select Owner").tag(DogOwner?.none)
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .onChange(of: viewModel.selectedOwner) { newOwner in
                        viewModel.resetDogIfOwnerChanged()
                        EditAppointmentAudit.record(
                            operation: "editField",
                            appointmentID: viewModel.originalAppointment.id,
                            field: "owner",
                            oldValue: viewModel.originalAppointment.owner?.ownerName,
                            newValue: newOwner?.ownerName,
                            tags: ["owner"],
                            detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                        )
                    }
                    .accessibilityIdentifier("ownerPicker")
                    .font(AppFonts.body)

                    if let owner = viewModel.selectedOwner {
                        Picker("Dog", selection: $viewModel.selectedDog) {
                            Text("Select Dog").tag(Dog?.none)
                            ForEach(owner.dogs ?? []) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .onChange(of: viewModel.selectedDog) { newDog in
                            EditAppointmentAudit.record(
                                operation: "editField",
                                appointmentID: viewModel.originalAppointment.id,
                                field: "dog",
                                oldValue: viewModel.originalAppointment.dog?.name,
                                newValue: newDog?.name,
                                tags: ["dog"],
                                detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                            )
                        }
                        .accessibilityIdentifier("dogPicker")
                        .font(AppFonts.body)
                    }
                }
                Section(header: Text("Service").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    Picker("Service Type", selection: $viewModel.serviceType) {
                        ForEach(viewModel.serviceTypes, id: \.self) { type in
                            Text(type).font(AppFonts.body)
                        }
                    }
                    .onChange(of: viewModel.serviceType) { newVal in
                        EditAppointmentAudit.record(
                            operation: "editField",
                            appointmentID: viewModel.originalAppointment.id,
                            field: "serviceType",
                            oldValue: viewModel.originalAppointment.serviceType,
                            newValue: newVal,
                            tags: ["serviceType"],
                            detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                        )
                    }
                    .accessibilityIdentifier("servicePicker")
                    .font(AppFonts.body)
                }
                Section(header: Text("Duration").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    HStack {
                        Text("\(viewModel.duration) min").font(AppFonts.body)
                        Spacer()
                        Button("Change") {
                            withAnimation { showDurationPicker = true }
                            EditAppointmentAudit.record(
                                operation: "editField",
                                appointmentID: viewModel.originalAppointment.id,
                                field: "duration",
                                oldValue: "\(viewModel.originalAppointment.duration)",
                                newValue: "\(viewModel.duration)",
                                tags: ["duration"],
                                detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                            )
                        }
                        .accessibilityIdentifier("changeDurationButton")
                        .font(AppFonts.body)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(AppColors.backgroundSecondary)
                        .foregroundColor(AppColors.accent)
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                }
                Section(header: Text("Notes").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                    TextField("Add notes...", text: $viewModel.notes, axis: .vertical)
                        .onChange(of: viewModel.notes) { newVal in
                            EditAppointmentAudit.record(
                                operation: "editField",
                                appointmentID: viewModel.originalAppointment.id,
                                field: "notes",
                                oldValue: viewModel.originalAppointment.notes,
                                newValue: newVal,
                                tags: ["notes"],
                                detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                            )
                        }
                        .lineLimit(1...3)
                        .accessibilityIdentifier("notesTextField")
                        .font(AppFonts.body)
                        .padding(AppSpacing.xSmall)
                }
                if !viewModel.availableTags.isEmpty {
                    Section(header: Text("Tags").font(AppFonts.subheadline).foregroundColor(AppColors.textPrimary)) {
                        FlowLayout(alignment: .leading, spacing: AppSpacing.small) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                Button {
                                    withAnimation { viewModel.toggleTag(tag) }
                                    EditAppointmentAudit.record(
                                        operation: "toggleTag",
                                        appointmentID: viewModel.originalAppointment.id,
                                        field: "tag",
                                        oldValue: viewModel.selectedTags.contains(tag) ? "selected" : "notSelected",
                                        newValue: !viewModel.selectedTags.contains(tag) ? "selected" : "notSelected",
                                        tags: ["tag", tag],
                                        detail: "Changed fields: \(viewModel.changedFields.joined(separator: ",")), Count: \(viewModel.fieldChangeCount)"
                                    )
                                } label: {
                                    Text(tag)
                                        .font(AppFonts.caption)
                                        .padding(.horizontal, AppSpacing.medium)
                                        .padding(.vertical, AppSpacing.xSmall)
                                        .background(viewModel.selectedTags.contains(tag) ? AppColors.accent : AppColors.backgroundSecondary)
                                        .foregroundColor(viewModel.selectedTags.contains(tag) ? AppColors.textOnAccent : AppColors.textPrimary)
                                        .clipShape(Capsule())
                                }
                                .accessibilityIdentifier("tagButton_\(tag)")
                            }
                        }
                        .padding(.vertical, AppSpacing.xSmall)
                    }
                }
            }
            .navigationTitle("Edit Appointment")
            .font(AppFonts.body)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.validateAndSave(existingAppointments: existingAppointments) {
                            EditAppointmentAudit.record(
                                operation: "save",
                                appointmentID: viewModel.originalAppointment.id,
                                tags: ["save"]
                            )
                            dismiss()
                        } else {
                            EditAppointmentAudit.record(
                                operation: "error",
                                appointmentID: viewModel.originalAppointment.id,
                                tags: ["save", "fail"],
                                detail: "Validation failed"
                            )
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("saveButton")
                    .font(AppFonts.body)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(viewModel.canSave ? AppColors.accent : AppColors.backgroundSecondary)
                    .foregroundColor(viewModel.canSave ? AppColors.textOnAccent : AppColors.secondaryText)
                    .clipShape(Capsule())
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        EditAppointmentAudit.record(
                            operation: "cancel",
                            appointmentID: viewModel.originalAppointment.id,
                            tags: ["cancel"]
                        )
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                    .font(AppFonts.body)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(AppColors.backgroundSecondary)
                    .foregroundColor(AppColors.accent)
                    .clipShape(Capsule())
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPicker(minutes: $viewModel.duration)
            }
            .onAppear {
                EditAppointmentAudit.record(
                    operation: "appear",
                    appointmentID: viewModel.originalAppointment.id,
                    tags: ["appear"]
                )
            }
        }
    }

    private static func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced ViewModel for editing an appointment
final class EditAppointmentViewModel: ObservableObject {
    @Published var date: Date
    @Published var selectedOwner: DogOwner?
    @Published var selectedDog: Dog?
    @Published var serviceType: String
    @Published var duration: Int
    @Published var notes: String
    @Published var selectedTags: Set<String>
    @Published var owners: [DogOwner]
    @Published var serviceTypes: [String]
    @Published var availableTags: [String]
    var originalAppointment: Appointment

    init(
        appointment: Appointment,
        owners: [DogOwner],
        serviceTypes: [String] = ["Full Groom", "Bath Only", "Nail Trim"],
        availableTags: [String] = ["VIP", "First Visit", "Aggressive", "Sensitive Skin"]
    ) {
        self.originalAppointment = appointment
        self.date = appointment.date
        self.selectedOwner = appointment.owner
        self.selectedDog = appointment.dog
        self.serviceType = appointment.serviceType
        self.duration = appointment.duration
        self.notes = appointment.notes ?? ""
        self.selectedTags = Set(appointment.tags ?? [])
        self.owners = owners
        self.serviceTypes = serviceTypes
        self.availableTags = availableTags
    }

    /// Reset selected dog if the owner changes or becomes nil
    func resetDogIfOwnerChanged() {
        guard let selectedOwner = selectedOwner else {
            selectedDog = nil
            return
        }
        if selectedDog?.owner?.id != selectedOwner.id {
            selectedDog = nil
        }
    }

    var canSave: Bool {
        selectedOwner != nil && selectedDog != nil && !serviceType.isEmpty
    }

    /// Toggles a tag selection
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Returns true if any primary field has changed from the original appointment.
    var isEdited: Bool { changedFields.count > 0 }

    /// Number of changed fields.
    var fieldChangeCount: Int { changedFields.count }

    /// List of changed fields from the original appointment.
    var changedFields: [String] {
        var changes: [String] = []
        if date != originalAppointment.date { changes.append("date") }
        if selectedOwner?.id != originalAppointment.owner?.id { changes.append("owner") }
        if selectedDog?.id != originalAppointment.dog?.id { changes.append("dog") }
        if serviceType != originalAppointment.serviceType { changes.append("serviceType") }
        if duration != originalAppointment.duration { changes.append("duration") }
        if notes != (originalAppointment.notes ?? "") { changes.append("notes") }
        if Set(selectedTags) != Set(originalAppointment.tags ?? []) { changes.append("tags") }
        return changes
    }

    /// Checks if the current appointment conflicts with any in the given list (excluding itself).
    func detectConflict(with appointments: [Appointment]) -> Bool {
        for other in appointments where other.id != originalAppointment.id {
            if Calendar.current.isDate(self.date, equalTo: other.date, toGranularity: .minute) {
                EditAppointmentAudit.record(
                    operation: "conflictDetected",
                    appointmentID: originalAppointment.id,
                    field: "date",
                    oldValue: Self.formatDate(originalAppointment.date),
                    newValue: Self.formatDate(self.date),
                    tags: ["conflict"],
                    detail: "Overlaps with appointment \(other.id)"
                )
                return true
            }
        }
        return false
    }

    /// Validates and saves the appointment (placeholder for real persistence logic)
    /// Pass in all existing appointments for conflict detection.
    func validateAndSave(existingAppointments: [Appointment] = []) -> Bool {
        guard canSave else { return false }
        let conflict = detectConflict(with: existingAppointments)
        // Update fields in the original appointment object
        originalAppointment.date = date
        originalAppointment.owner = selectedOwner
        originalAppointment.dog = selectedDog
        originalAppointment.serviceType = serviceType
        originalAppointment.duration = duration
        originalAppointment.notes = notes
        originalAppointment.tags = Array(selectedTags)
        // Accessibility: Announce if conflict or saved
        if conflict {
            UIAccessibility.post(notification: .announcement, argument: "Warning: This appointment overlaps with another.")
        } else {
            UIAccessibility.post(notification: .announcement, argument: "Appointment saved.")
        }
        return true
    }

    private static func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Placeholder Models

/// Appointment model
struct Appointment: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var owner: DogOwner?
    var dog: Dog?
    var serviceType: String
    var duration: Int
    var notes: String?
    var tags: [String]?
}

/// Dog owner model
struct DogOwner: Identifiable, Hashable, Equatable {
    var id: UUID
    var ownerName: String
    var dogs: [Dog]?
}

/// Dog model
struct Dog: Identifiable, Hashable, Equatable {
    var id: UUID
    var name: String
    var owner: DogOwner? = nil
}

// MARK: - Duration Picker (reuse from AddAppointmentView)

/// Picker view to select appointment duration in minutes
struct DurationPicker: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    private let minMinutes = 15
    private let maxMinutes = 180

    var body: some View {
        NavigationView {
            VStack {
                Picker("Duration (minutes)", selection: $minutes) {
                    ForEach(Array(stride(from: minMinutes, through: maxMinutes, by: 5)), id: \.self) { min in
                        Text("\(min) min")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: AppSpacing.durationPickerHeight)
                Spacer()
            }
            .navigationTitle("Set Duration")
            .font(AppFonts.body)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppFonts.body)
                    .accessibilityIdentifier("durationPickerDoneButton")
                }
            }
            .padding(AppSpacing.medium)
            .background(AppColors.backgroundPrimary)
        }
    }
}

// MARK: - FlowLayout Helper

/// A simple flow layout that wraps content horizontally and vertically
struct FlowLayout<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = AppSpacing.small
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(ArrayMirror(content()).enumerated()), id: \.0) { index, view in
                view
                    .padding(.horizontal, spacing / 2)
                    .padding(.vertical, spacing / 2)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }
                        let result = width
                        if index == ArrayMirror(content()).count - 1 {
                            width = 0 // Last item
                        } else {
                            width -= dimension.width + spacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == ArrayMirror(content()).count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
}

// Helper to convert ViewBuilder content into an array of views
fileprivate struct ArrayMirror<Content: View>: RandomAccessCollection {
    typealias Element = AnyView
    typealias Index = Int
    private let views: [AnyView]

    init(_ content: Content) {
        // Wrap in AnyView for storage
        if let tupleView = content as? TupleView<(AnyView, AnyView)> {
            self.views = Mirror(reflecting: tupleView).children.compactMap { $0.value as? AnyView }
        } else {
            self.views = [AnyView(content)]
        }
    }

    var startIndex: Int { 0 }
    var endIndex: Int { views.count }

    subscript(position: Int) -> AnyView {
        views[position]
    }
}

// MARK: - Preview

#if DEBUG
struct EditAppointmentView_Previews: PreviewProvider {
    static var previews: some View {
        let dog = Dog(id: UUID(), name: "Bella")
        let owner = DogOwner(id: UUID(), ownerName: "Jane Doe", dogs: [dog])
        let appointment = Appointment(id: UUID(), date: Date().addingTimeInterval(3600), owner: owner, dog: dog, serviceType: "Full Groom", duration: 90, notes: "Use gentle shampoo", tags: ["VIP"])

        let viewModel = EditAppointmentViewModel(appointment: appointment, owners: [owner])
        EditAppointmentView(viewModel: viewModel, existingAppointments: [appointment])
            .environment(\.colorScheme, .light)
            .font(AppFonts.body)
            .accentColor(AppColors.accent)
    }
}
#endif
