//
//  BehaviorBadgeEditorView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 2, 2025 — fixed preview initializer to pass model types variadically.
//

import SwiftUI
import SwiftData

// TODO: Move behavior-editing logic into a dedicated ViewModel; use FormValidator for note and badge validation.

@MainActor
class BehaviorBadgeEditorViewModel: ObservableObject {
    @Published var note: String
    @Published var tagEmoji: String

    private var log: PetBehaviorLog
    private static let maxNoteLength: Int = 250

    init(log: PetBehaviorLog) {
        self.log = log
        self.note = log.note
        self.tagEmoji = log.tagEmoji
    }

    var isValid: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !tagEmoji.isEmpty
    }

    func save(context: ModelContext) throws {
        let clampedNote = String(note.prefix(Self.maxNoteLength))
        log.note = clampedNote
        log.tagEmoji = tagEmoji
        try context.save()
    }
}

/// View for editing a single PetBehaviorLog entry, including notes and badge selection.
struct BehaviorBadgeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel: BehaviorBadgeEditorViewModel

    private static let maxNoteLength: Int = 250

    init(log: PetBehaviorLog) {
        _viewModel = StateObject(wrappedValue: BehaviorBadgeEditorViewModel(log: log))
    }

    var body: some View {
        NavigationStack {
            Form {
                /// Section for entering and editing behavior notes.
                Section(header: Text("Behavior Notes")) {
                    TextEditor(text: $viewModel.note)
                        .onChange(of: viewModel.note) { newValue in
                            if newValue.count > Self.maxNoteLength {
                                viewModel.note = String(newValue.prefix(Self.maxNoteLength))
                            }
                        }
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    VStack(alignment: .trailing) {
                        Text("\(viewModel.note.count)/\(Self.maxNoteLength)")
                            .font(.caption)
                            .foregroundColor(viewModel.note.count > Self.maxNoteLength ? .red : .secondary)
                    }
                }

                /// Section for choosing a behavior badge.
                Section(header: Text("Select Badge")) {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 12) {
                        ForEach(BadgeEngine.BehaviorBadge.allCases, id: \.self) { badge in
                            let emoji = badge.rawValue.components(separatedBy: " ").first!
                            Button {
                                viewModel.tagEmoji = emoji
                            } label: {
                                VStack {
                                    Text(emoji)
                                        .font(.largeTitle)
                                    Text(badge.rawValue)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.tagEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(badge.rawValue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Behavior")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    /// Saves changes to the behavior log if valid.
                    Button("Done") {
                        do {
                            try viewModel.save(context: context)
                        } catch {
                            print("⚠️ Failed to save behavior log:", error)
                        }
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    /// Discards changes and dismisses the editor.
                    Button("Cancel") {
                        context.rollback()
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
import SwiftUI

struct BehaviorBadgeEditorView_Previews: PreviewProvider {
    static var container: ModelContainer = {
        // Just pass the model types; in-memory is the default for previews
        try! ModelContainer(for: DogOwner.self, PetBehaviorLog.self)
    }()

    static var previews: some View {
        let owner = DogOwner.sample
        let log = PetBehaviorLog.sample
        log.dogOwner = owner
        container.mainContext.insert(owner)
        container.mainContext.insert(log)

        return BehaviorBadgeEditorView(log: log)
            .environment(\.modelContext, container.mainContext)
    }
}
#endif
