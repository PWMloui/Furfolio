//
//  AddDogView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible AddDogView
//

import SwiftUI
import Combine

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
    
    /// Records an audit event with the given action and dog data.
    /// Also trims the log to keep a maximum of 25 events.
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
    
    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Returns summaries of the most recent audit events, limited by `limit`.
    static func recentSummaries(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
    
    // MARK: - New Analytics Computed Properties
    
    /// The action string that appears most frequently in the audit log.
    static var mostFrequentAction: String {
        let actions = log.map { $0.action }
        let frequencies = Dictionary(actions.map { ($0, 1) }, uniquingKeysWith: +)
        return frequencies.max(by: { $0.value < $1.value })?.key ?? "None"
    }
    
    /// The breed that appears most frequently in the audit log.
    static var mostFrequentBreed: String {
        let breeds = log.map { $0.breed }
        let frequencies = Dictionary(breeds.map { ($0, 1) }, uniquingKeysWith: +)
        return frequencies.max(by: { $0.value < $1.value })?.key ?? "None"
    }
    
    /// The average length of notes across all audit events.
    static var averageNotesLength: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.notesLength }
        return Double(total) / Double(log.count)
    }
    
    /// The total number of audit events.
    static var totalEvents: Int {
        log.count
    }
    
    // MARK: - CSV Export
    
    /// Exports the entire audit log as a CSV string with columns:
    /// timestamp,action,dogName,breed,notesLength
    static func exportCSV() -> String {
        let header = "timestamp,action,dogName,breed,notesLength"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event in
            let timestamp = formatter.string(from: event.timestamp)
            let escapedDogName = event.dogName.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedBreed = event.breed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(timestamp)\",\"\(event.action)\",\"\(escapedDogName)\",\"\(escapedBreed)\",\(event.notesLength)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - AddDogView

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dogData = DogData()
    @State private var showCancelAlert = false

    var onSave: ((DogData) -> Void)?
    
    /// Accessibility announcer for VoiceOver notifications
    private let accessibilityAnnouncer = AccessibilityAnnouncer()

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
                            // Accessibility announcement on cancel
                            accessibilityAnnouncer.announce("Dog \(dogData.name) canceled.")
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
                        // Accessibility announcement on save
                        accessibilityAnnouncer.announce("Dog \(dogData.name) saved.")
                        dismiss()
                    }) {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                    .accessibilityIdentifier("AddDogView-SaveButton")
                    .disabled(!formValid)
                }
            }
            #if DEBUG
            .overlay(
                VStack {
                    Spacer()
                    AuditDebugOverlay()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding()
                }
            )
            #endif
        }
    }

    private var formValid: Bool {
        !dogData.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dogData.breed.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Accessibility Announcement Helper

/// Helper class to post VoiceOver announcements for accessibility
fileprivate class AccessibilityAnnouncer {
    func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum AddDogViewAuditAdmin {
    /// Returns the summary string of the last audit event or a default message.
    public static func lastSummary() -> String { AddDogAudit.log.last?.summary ?? "No add-dog actions yet." }
    
    /// Returns the last audit event encoded as JSON string.
    public static func lastJSON() -> String? { AddDogAudit.exportLastJSON() }
    
    /// Returns recent audit event summaries limited by `limit`.
    public static func recentEvents(limit: Int = 5) -> [String] { AddDogAudit.recentSummaries(limit: limit) }
    
    /// Returns the most frequent action string in the audit log.
    public static var mostFrequentAction: String { AddDogAudit.mostFrequentAction }
    
    /// Returns the most frequent breed string in the audit log.
    public static var mostFrequentBreed: String { AddDogAudit.mostFrequentBreed }
    
    /// Returns the average notes length across audit events.
    public static var averageNotesLength: Double { AddDogAudit.averageNotesLength }
    
    /// Returns the total number of audit events recorded.
    public static var totalEvents: Int { AddDogAudit.totalEvents }
    
    /// Exports the entire audit log as a CSV string.
    public static func exportCSV() -> String { AddDogAudit.exportCSV() }
}

// MARK: - DEBUG Audit Debug Overlay

#if DEBUG
/// A SwiftUI overlay view showing recent audit events and analytics for development/debugging.
fileprivate struct AuditDebugOverlay: View {
    private let recentEvents = AddDogAudit.recentSummaries(limit: 3)
    private let mostFrequentAction = AddDogAudit.mostFrequentAction
    private let mostFrequentBreed = AddDogAudit.mostFrequentBreed
    private let averageNotesLength = AddDogAudit.averageNotesLength
    private let totalEvents = AddDogAudit.totalEvents
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Debug Info")
                .font(.headline)
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Last 3 Events:")
                    .fontWeight(.semibold)
                ForEach(recentEvents, id: \.self) { event in
                    Text(event)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Analytics:")
                    .fontWeight(.semibold)
                Text("Most Frequent Action: \(mostFrequentAction)")
                    .font(.caption)
                Text("Most Frequent Breed: \(mostFrequentBreed)")
                    .font(.caption)
                Text(String(format: "Average Notes Length: %.2f", averageNotesLength))
                    .font(.caption)
                Text("Total Events: \(totalEvents)")
                    .font(.caption)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
#endif

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
