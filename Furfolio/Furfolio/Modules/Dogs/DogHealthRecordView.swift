//
//  DogHealthRecordView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Health Record View
//

import SwiftUI

// MARK: - Data Models

struct VaccinationRecord: Identifiable, Equatable, Codable {
    let id: UUID
    var vaccineName: String
    var dateGiven: Date
    var nextDueDate: Date?
    init(id: UUID = UUID(), vaccineName: String, dateGiven: Date, nextDueDate: Date? = nil) {
        self.id = id
        self.vaccineName = vaccineName
        self.dateGiven = dateGiven
        self.nextDueDate = nextDueDate
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogHealthAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let item: String
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Health] \(action) \(item): \(details) at \(dateStr)"
    }
}
fileprivate final class DogHealthAudit {
    static private(set) var log: [DogHealthAuditEvent] = []
    static func record(action: String, item: String, details: String) {
        let event = DogHealthAuditEvent(
            timestamp: Date(),
            action: action,
            item: item,
            details: details
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - ViewModel

@MainActor
class DogHealthRecordViewModel: ObservableObject {
    @Published var vaccinations: [VaccinationRecord] = []
    @Published var allergies: [String] = []
    @Published var healthNotes: String = ""
    @Published var isEditing: Bool = false

    @Published var lastDeletedVaccination: VaccinationRecord?
    @Published var lastDeletedAllergy: String?

    func addVaccination(_ record: VaccinationRecord) {
        vaccinations.append(record)
        DogHealthAudit.record(action: "Add", item: "Vaccination", details: record.vaccineName)
    }

    func removeVaccination(at offsets: IndexSet) {
        if let idx = offsets.first {
            lastDeletedVaccination = vaccinations[idx]
            let record = vaccinations.remove(at: idx)
            DogHealthAudit.record(action: "Delete", item: "Vaccination", details: record.vaccineName)
        }
    }

    func undoVaccinationDelete() {
        if let record = lastDeletedVaccination {
            vaccinations.append(record)
            DogHealthAudit.record(action: "UndoDelete", item: "Vaccination", details: record.vaccineName)
            lastDeletedVaccination = nil
        }
    }

    func addAllergy(_ allergy: String) {
        allergies.append(allergy)
        DogHealthAudit.record(action: "Add", item: "Allergy", details: allergy)
    }

    func removeAllergy(at offsets: IndexSet) {
        if let idx = offsets.first {
            lastDeletedAllergy = allergies[idx]
            let allergy = allergies.remove(at: idx)
            DogHealthAudit.record(action: "Delete", item: "Allergy", details: allergy)
        }
    }

    func undoAllergyDelete() {
        if let allergy = lastDeletedAllergy {
            allergies.append(allergy)
            DogHealthAudit.record(action: "UndoDelete", item: "Allergy", details: allergy)
            lastDeletedAllergy = nil
        }
    }
}

// MARK: - Main View

struct DogHealthRecordView: View {
    @StateObject private var viewModel = DogHealthRecordViewModel()
    @State private var newVaccineName: String = ""
    @State private var newDateGiven: Date = Date()
    @State private var newNextDueDate: Date = Date()
    @State private var newAllergy: String = ""
    @State private var showUndoVaccine = false
    @State private var showUndoAllergy = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Vaccination Records").accessibilityLabel("Vaccination Records")) {
                    if viewModel.isEditing {
                        VStack(spacing: 8) {
                            TextField("Vaccine Name", text: $newVaccineName)
                                .accessibilityLabel("Vaccine Name")
                                .accessibilityIdentifier("DogHealthRecordView-VaccineNameField")
                            DatePicker("Date Given", selection: $newDateGiven, displayedComponents: .date)
                                .accessibilityLabel("Date Given")
                                .accessibilityIdentifier("DogHealthRecordView-DateGivenPicker")
                            DatePicker("Next Due Date", selection: $newNextDueDate, displayedComponents: .date)
                                .accessibilityLabel("Next Due Date")
                                .accessibilityIdentifier("DogHealthRecordView-NextDueDatePicker")
                            Button("Add Vaccination") {
                                let record = VaccinationRecord(vaccineName: newVaccineName, dateGiven: newDateGiven, nextDueDate: newNextDueDate)
                                viewModel.addVaccination(record)
                                newVaccineName = ""
                                newDateGiven = Date()
                                newNextDueDate = Date()
                            }
                            .accessibilityLabel("Add Vaccination")
                            .accessibilityIdentifier("DogHealthRecordView-AddVaccinationButton")
                            .disabled(newVaccineName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if viewModel.vaccinations.isEmpty {
                        Text("No vaccination records.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No vaccination records")
                            .accessibilityIdentifier("DogHealthRecordView-NoVaccinations")
                    } else {
                        ForEach(viewModel.vaccinations) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.vaccineName)
                                    .font(.headline)
                                    .accessibilityLabel("Vaccine: \(record.vaccineName)")
                                    .accessibilityIdentifier("DogHealthRecordView-Vaccine-\(record.vaccineName)")
                                Text("Date Given: \(formattedDate(record.dateGiven))")
                                    .font(.subheadline)
                                    .accessibilityLabel("Date Given: \(formattedDate(record.dateGiven))")
                                    .accessibilityIdentifier("DogHealthRecordView-DateGiven-\(record.vaccineName)")
                                if let nextDue = record.nextDueDate {
                                    Text("Next Due: \(formattedDate(nextDue))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .accessibilityLabel("Next Due: \(formattedDate(nextDue))")
                                        .accessibilityIdentifier("DogHealthRecordView-NextDue-\(record.vaccineName)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            if viewModel.isEditing {
                                viewModel.removeVaccination(at: indexSet)
                                showUndoVaccine = true
                            }
                        }
                    }
                    if let last = viewModel.lastDeletedVaccination, showUndoVaccine {
                        Button {
                            viewModel.undoVaccinationDelete()
                            showUndoVaccine = false
                        } label: {
                            Label("Undo delete \(last.vaccineName)", systemImage: "arrow.uturn.backward")
                        }
                        .accessibilityIdentifier("DogHealthRecordView-UndoVaccinationButton")
                    }
                }

                Divider()

                Section(header: Text("Allergies").accessibilityLabel("Allergies")) {
                    if viewModel.isEditing {
                        HStack {
                            TextField("Add Allergy", text: $newAllergy)
                                .accessibilityLabel("Add Allergy")
                                .accessibilityIdentifier("DogHealthRecordView-AddAllergyField")
                            Button(action: {
                                let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                viewModel.addAllergy(trimmed)
                                newAllergy = ""
                            }) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .accessibilityLabel("Add Allergy")
                            .accessibilityIdentifier("DogHealthRecordView-AddAllergyButton")
                            .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if viewModel.allergies.isEmpty {
                        Text("No known allergies.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No known allergies")
                            .accessibilityIdentifier("DogHealthRecordView-NoAllergies")
                    } else {
                        ForEach(viewModel.allergies, id: \.self) { allergy in
                            Text(allergy)
                                .padding(.vertical, 4)
                                .accessibilityLabel("Allergy: \(allergy)")
                                .accessibilityIdentifier("DogHealthRecordView-Allergy-\(allergy)")
                        }
                        .onDelete { indexSet in
                            if viewModel.isEditing {
                                viewModel.removeAllergy(at: indexSet)
                                showUndoAllergy = true
                            }
                        }
                    }
                    if let last = viewModel.lastDeletedAllergy, showUndoAllergy {
                        Button {
                            viewModel.undoAllergyDelete()
                            showUndoAllergy = false
                        } label: {
                            Label("Undo delete \(last)", systemImage: "arrow.uturn.backward")
                        }
                        .accessibilityIdentifier("DogHealthRecordView-UndoAllergyButton")
                    }
                }

                Divider()

                Section(header: Text("Health Notes").accessibilityLabel("Health Notes")) {
                    if viewModel.isEditing {
                        TextEditor(text: $viewModel.healthNotes)
                            .frame(minHeight: 120)
                            .accessibilityLabel("Health Notes Editor")
                            .accessibilityIdentifier("DogHealthRecordView-HealthNotesEditor")
                            .onChange(of: viewModel.healthNotes) { newValue in
                                DogHealthAudit.record(action: "Edit", item: "HealthNotes", details: newValue)
                            }
                    } else {
                        Text(viewModel.healthNotes.isEmpty ? "No health notes." : viewModel.healthNotes)
                            .foregroundColor(viewModel.healthNotes.isEmpty ? .secondary : .primary)
                            .accessibilityLabel(viewModel.healthNotes.isEmpty ? "No health notes" : "Health Notes: \(viewModel.healthNotes)")
                            .accessibilityIdentifier("DogHealthRecordView-HealthNotesLabel")
                    }
                }
            }
            .navigationTitle("Health Records")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(viewModel.isEditing ? "Done" : "Edit") {
                        withAnimation {
                            viewModel.isEditing.toggle()
                        }
                    }
                    .accessibilityLabel(viewModel.isEditing ? "Done Editing" : "Edit Health Records")
                    .accessibilityIdentifier("DogHealthRecordView-EditButton")
                }
            }
        }
        .onAppear {
            // Load sample data for preview/demo
            if viewModel.vaccinations.isEmpty && viewModel.allergies.isEmpty {
                loadSampleData()
            }
        }
    }

    private func loadSampleData() {
        viewModel.vaccinations = [
            VaccinationRecord(vaccineName: "Rabies", dateGiven: Date(timeIntervalSinceNow: -86400 * 365 * 2), nextDueDate: Date(timeIntervalSinceNow: 86400 * 365)),
            VaccinationRecord(vaccineName: "Distemper", dateGiven: Date(timeIntervalSinceNow: -86400 * 365 * 1), nextDueDate: Date(timeIntervalSinceNow: 86400 * 365 * 2))
        ]
        viewModel.allergies = ["Pollen", "Flea bites"]
        viewModel.healthNotes = "Regular checkups are recommended. Watch for signs of allergies during spring."
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Audit/Admin Accessors

public enum DogHealthAuditAdmin {
    public static func lastSummary() -> String { DogHealthAudit.log.last?.summary ?? "No health events yet." }
    public static func lastJSON() -> String? { DogHealthAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { DogHealthAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogHealthRecordView_Previews: PreviewProvider {
    static var previews: some View {
        DogHealthRecordView()
    }
}
#endif
