//
//  DogBehaviorLogView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Behavior Log View
//

import SwiftUI

// MARK: - BehaviorLog Model

struct BehaviorLog: Identifiable, Codable {
    let id: UUID
    var date: Date
    var note: String
    var mood: Mood

    init(id: UUID = UUID(), date: Date, note: String, mood: Mood) {
        self.id = id
        self.date = date
        self.note = note
        self.mood = mood
    }

    enum Mood: String, CaseIterable, Identifiable, Codable {
        case calm = "Calm"
        case anxious = "Anxious"
        case aggressive = "Aggressive"
        case playful = "Playful"
        case tired = "Tired"

        var id: String { rawValue }
        var emoji: String {
            switch self {
            case .calm: return "🟢"
            case .anxious: return "🟠"
            case .aggressive: return "🔴"
            case .playful: return "🟣"
            case .tired: return "⚫️"
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct BehaviorLogAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let mood: String?
    let noteLen: Int?
    let context: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[BehaviorLog] \(action) \(mood ?? "") len:\(noteLen ?? 0) \(context ?? "") at \(dateStr)"
    }
}
fileprivate final class BehaviorLogAudit {
    static private(set) var log: [BehaviorLogAuditEvent] = []
    static func record(action: String, log: BehaviorLog?, context: String? = nil) {
        let event = BehaviorLogAuditEvent(
            timestamp: Date(),
            action: action,
            mood: log?.mood.rawValue,
            noteLen: log?.note.count,
            context: context
        )
        BehaviorLogAudit.log.append(event)
        if BehaviorLogAudit.log.count > 30 { BehaviorLogAudit.log.removeFirst() }
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
class DogBehaviorLogViewModel: ObservableObject {
    @Published var logs: [BehaviorLog] = []
    private var lastAdded: BehaviorLog?

    func addLog(_ log: BehaviorLog) {
        logs.insert(log, at: 0)
        lastAdded = log
        BehaviorLogAudit.record(action: "Add", log: log)
    }

    func undoLastAdd() {
        guard let last = lastAdded, let idx = logs.firstIndex(where: { $0.id == last.id }) else { return }
        logs.remove(at: idx)
        BehaviorLogAudit.record(action: "UndoAdd", log: last)
        lastAdded = nil
    }
}

// MARK: - Main View

struct DogBehaviorLogView: View {
    @StateObject var viewModel: DogBehaviorLogViewModel
    @State private var showingAddLog = false
    @State private var showUndoAlert = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.logs.isEmpty {
                    Text("No behavior logs yet.")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No behavior logs yet")
                        .accessibilityIdentifier("DogBehaviorLogView-Empty")
                } else {
                    ForEach(viewModel.logs) { log in
                        HStack(alignment: .top, spacing: 12) {
                            Text(log.mood.emoji)
                                .font(.title2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.date, style: .date)
                                    .font(.headline)
                                Text(log.note)
                                    .font(.body)
                                    .accessibilityIdentifier("DogBehaviorLogView-Note-\(log.id)")
                            }
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(log.mood.rawValue) behavior on \(log.date.formatted(date: .abbreviated, time: .omitted)): \(log.note)")
                        .accessibilityIdentifier("DogBehaviorLogView-Log-\(log.id)")
                    }
                }
            }
            .navigationTitle("Behavior Logs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddLog = true }) {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add new behavior log")
                            .accessibilityIdentifier("DogBehaviorLogView-AddButton")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if viewModel.logs.first != nil {
                        Button {
                            showUndoAlert = true
                        } label: {
                            Label("Undo Last Add", systemImage: "arrow.uturn.backward")
                        }
                        .accessibilityIdentifier("DogBehaviorLogView-UndoButton")
                        .alert("Undo last add?", isPresented: $showUndoAlert) {
                            Button("Undo", role: .destructive) {
                                viewModel.undoLastAdd()
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("This will remove the last behavior log you added.")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddLog) {
                AddBehaviorLogView { newLog in
                    viewModel.addLog(newLog)
                    showingAddLog = false
                }
            }
            .onAppear {
                BehaviorLogAudit.record(action: "ScreenAppear", log: nil, context: "DogBehaviorLogView")
            }
        }
    }
}

// MARK: - Add Behavior Log View

struct AddBehaviorLogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var selectedMood: BehaviorLog.Mood = .calm

    var onSave: (BehaviorLog) -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .accessibilityLabel("Log date")
                    .accessibilityIdentifier("AddBehaviorLogView-DatePicker")

                Section(header: Text("Mood")) {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(BehaviorLog.Mood.allCases) { mood in
                            Text("\(mood.emoji) \(mood.rawValue)").tag(mood)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select mood")
                    .accessibilityIdentifier("AddBehaviorLogView-MoodPicker")
                }

                Section(header: Text("Note")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Behavior note")
                        .accessibilityIdentifier("AddBehaviorLogView-NoteEditor")
                }
            }
            .navigationTitle("Add Behavior Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("AddBehaviorLogView-CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newLog = BehaviorLog(date: date, note: note, mood: selectedMood)
                        onSave(newLog)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("AddBehaviorLogView-SaveButton")
                }
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DogBehaviorLogViewAuditAdmin {
    public static func lastSummary() -> String { BehaviorLogAudit.log.last?.summary ?? "No log events yet." }
    public static func lastJSON() -> String? { BehaviorLogAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { BehaviorLogAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogBehaviorLogView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleLogs = [
            BehaviorLog(date: Date().addingTimeInterval(-86400), note: "Very calm and relaxed during the walk.", mood: .calm),
            BehaviorLog(date: Date().addingTimeInterval(-43200), note: "Seemed anxious around strangers.", mood: .anxious),
            BehaviorLog(date: Date(), note: "Playful and energetic at the park.", mood: .playful)
        ]
        let viewModel = DogBehaviorLogViewModel()
        sampleLogs.forEach { viewModel.addLog($0) }

        return DogBehaviorLogView(viewModel: viewModel)
    }
}

struct AddBehaviorLogView_Previews: PreviewProvider {
    static var previews: some View {
        AddBehaviorLogView { _ in }
    }
}
#endif
