//
//  DogHealthRecordView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  DogHealthRecordView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct VaccinationRecord: Identifiable, Equatable {
    let id = UUID()
    var vaccineName: String
    var dateGiven: Date
    var nextDueDate: Date?
}

@MainActor
class DogHealthRecordViewModel: ObservableObject {
    @Published var vaccinations: [VaccinationRecord] = []
    @Published var allergies: [String] = []
    @Published var healthNotes: String = ""
    @Published var isEditing: Bool = false

    func addVaccination(_ record: VaccinationRecord) {
        vaccinations.append(record)
    }

    func removeVaccination(at offsets: IndexSet) {
        vaccinations.remove(atOffsets: offsets)
    }

    func addAllergy(_ allergy: String) {
        allergies.append(allergy)
    }

    func removeAllergy(at offsets: IndexSet) {
        allergies.remove(atOffsets: offsets)
    }
}

struct DogHealthRecordView: View {
    @StateObject private var viewModel = DogHealthRecordViewModel()
    @State private var newVaccineName: String = ""
    @State private var newDateGiven: Date = Date()
    @State private var newNextDueDate: Date = Date()
    @State private var newAllergy: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Vaccination Records").accessibilityLabel("Vaccination Records")) {
                    if viewModel.isEditing {
                        VStack(spacing: 8) {
                            TextField("Vaccine Name", text: $newVaccineName)
                                .accessibilityLabel("Vaccine Name")
                            DatePicker("Date Given", selection: $newDateGiven, displayedComponents: .date)
                                .accessibilityLabel("Date Given")
                            DatePicker("Next Due Date", selection: $newNextDueDate, displayedComponents: .date)
                                .accessibilityLabel("Next Due Date")
                            Button("Add Vaccination") {
                                let record = VaccinationRecord(vaccineName: newVaccineName, dateGiven: newDateGiven, nextDueDate: newNextDueDate)
                                viewModel.addVaccination(record)
                                newVaccineName = ""
                                newDateGiven = Date()
                                newNextDueDate = Date()
                            }
                            .accessibilityLabel("Add Vaccination")
                            .disabled(newVaccineName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if viewModel.vaccinations.isEmpty {
                        Text("No vaccination records.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No vaccination records")
                    } else {
                        ForEach(viewModel.vaccinations) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.vaccineName)
                                    .font(.headline)
                                    .accessibilityLabel("Vaccine: \(record.vaccineName)")
                                Text("Date Given: \(record.dateGiven, style: .date)")
                                    .font(.subheadline)
                                    .accessibilityLabel("Date Given: \(formattedDate(record.dateGiven))")
                                if let nextDue = record.nextDueDate {
                                    Text("Next Due: \(nextDue, style: .date)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .accessibilityLabel("Next Due: \(formattedDate(nextDue))")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.isEditing ? viewModel.removeVaccination : nil)
                    }
                }

                Divider()

                Section(header: Text("Allergies").accessibilityLabel("Allergies")) {
                    if viewModel.isEditing {
                        HStack {
                            TextField("Add Allergy", text: $newAllergy)
                                .accessibilityLabel("Add Allergy")
                            Button(action: {
                                let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                viewModel.addAllergy(trimmed)
                                newAllergy = ""
                            }) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .accessibilityLabel("Add Allergy")
                            .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if viewModel.allergies.isEmpty {
                        Text("No known allergies.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No known allergies")
                    } else {
                        ForEach(viewModel.allergies, id: \.self) { allergy in
                            Text(allergy)
                                .padding(.vertical, 4)
                                .accessibilityLabel("Allergy: \(allergy)")
                        }
                        .onDelete(perform: viewModel.isEditing ? viewModel.removeAllergy : nil)
                    }
                }

                Divider()

                Section(header: Text("Health Notes").accessibilityLabel("Health Notes")) {
                    if viewModel.isEditing {
                        TextEditor(text: $viewModel.healthNotes)
                            .frame(minHeight: 120)
                            .accessibilityLabel("Health Notes Editor")
                    } else {
                        Text(viewModel.healthNotes.isEmpty ? "No health notes." : viewModel.healthNotes)
                            .foregroundColor(viewModel.healthNotes.isEmpty ? .secondary : .primary)
                            .accessibilityLabel(viewModel.healthNotes.isEmpty ? "No health notes" : "Health Notes: \(viewModel.healthNotes)")
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

#if DEBUG
struct DogHealthRecordView_Previews: PreviewProvider {
    static var previews: some View {
        DogHealthRecordView()
    }
}
#endif
