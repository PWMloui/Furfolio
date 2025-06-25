//
//  AddDogView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible AddDogView
//

import SwiftUI

struct DogData: Identifiable, Codable {
    let id: UUID
    var name: String
    var breed: String
    var birthdate: Date
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        breed: String = "",
        birthdate: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.notes = notes
    }
}

// MARK: - Audit/Event Logging

fileprivate struct AddDogAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let dogName: String
    let breed: String
    let notesLength: Int
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Dog \(action)] '\(dogName)' (\(breed)), notes \(notesLength) at \(dateStr)"
    }
}
fileprivate final class AddDogAudit {
    static private(set) var log: [AddDogAuditEvent] = []
    static func record(action: String, data: DogData) {
        let event = AddDogAuditEvent(
            timestamp: Date(),
            action: action,
            dogName: data.name,
            breed: data.breed,
            notesLength: data.notes.count
        )
        log.append(event)
        if log.count > 25 { log.removeFirst() }
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

// MARK: - AddDogView

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dogData = DogData()
    @State private var showCancelAlert = false

    var onSave: ((DogData) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dog Information")) {
                    TextField("Name", text: $dogData.name)
                        .accessibilityLabel("Dog Name")
                        .accessibilityIdentifier("AddDogView-NameField")
                        .autocapitalization(.words)
                    TextField("Breed", text: $dogData.breed)
                        .accessibilityLabel("Dog Breed")
                        .accessibilityIdentifier("AddDogView-BreedField")
                        .autocapitalization(.words)
                    DatePicker("Birthdate", selection: $dogData.birthdate, displayedComponents: .date)
                        .accessibilityLabel("Dog Birthdate")
                        .accessibilityIdentifier("AddDogView-BirthdatePicker")
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $dogData.notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Dog Notes")
                        .accessibilityIdentifier("AddDogView-NotesEditor")
                }
            }
            .navigationTitle("Add Dog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCancelAlert = true
                    }
                    .accessibilityIdentifier("AddDogView-CancelButton")
                    .alert("Discard changes?", isPresented: $showCancelAlert) {
                        Button("Discard", role: .destructive) {
                            AddDogAudit.record(action: "Cancel", data: dogData)
                            dismiss()
                        }
                        Button("Keep Editing", role: .cancel) { }
                    } message: {
                        Text("Are you sure you want to discard this dog's information?")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        onSave?(dogData)
                        AddDogAudit.record(action: "Save", data: dogData)
                        dismiss()
                    }) {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                    .accessibilityIdentifier("AddDogView-SaveButton")
                    .disabled(!formValid)
                }
            }
        }
    }

    private var formValid: Bool {
        !dogData.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dogData.breed.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Audit/Admin Accessors

public enum AddDogViewAuditAdmin {
    public static func lastSummary() -> String { AddDogAudit.log.last?.summary ?? "No add-dog actions yet." }
    public static func lastJSON() -> String? { AddDogAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { AddDogAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct AddDogView_Previews: PreviewProvider {
    static var previews: some View {
        AddDogView(onSave: { dog in
            print("Saved dog: \(dog.name)")
        })
    }
}
#endif
