//
//  DogBehaviorLogView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - BehaviorLog Model

struct BehaviorLog: Identifiable {
    let id = UUID()
    var date: Date
    var note: String
    var mood: Mood

    enum Mood: String, CaseIterable, Identifiable {
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

// MARK: - ViewModel

@MainActor
class DogBehaviorLogViewModel: ObservableObject {
    @Published var logs: [BehaviorLog] = []

    func addLog(_ log: BehaviorLog) {
        logs.insert(log, at: 0)
    }
}

// MARK: - View

struct DogBehaviorLogView: View {
    @StateObject private var viewModel = DogBehaviorLogViewModel()
    @State private var showingAddLog = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.logs.isEmpty {
                    Text("No behavior logs yet.")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No behavior logs yet")
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
                            }
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(log.mood.rawValue) behavior on \(log.date.formatted(date: .abbreviated, time: .omitted)): \(log.note)")
                    }
                }
            }
            .navigationTitle("Behavior Logs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddLog = true }) {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add new behavior log")
                    }
                }
            }
            .sheet(isPresented: $showingAddLog) {
                AddBehaviorLogView { newLog in
                    viewModel.addLog(newLog)
                    showingAddLog = false
                }
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

                Section(header: Text("Mood")) {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(BehaviorLog.Mood.allCases) { mood in
                            Text("\(mood.emoji) \(mood.rawValue)").tag(mood)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select mood")
                }

                Section(header: Text("Note")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Behavior note")
                }
            }
            .navigationTitle("Add Behavior Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newLog = BehaviorLog(date: date, note: note, mood: selectedMood)
                        onSave(newLog)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
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
        viewModel.logs = sampleLogs

        return DogBehaviorLogView()
            .environmentObject(viewModel)
    }
}

struct AddBehaviorLogView_Previews: PreviewProvider {
    static var previews: some View {
        AddBehaviorLogView { _ in }
    }
}
#endif
