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
/// View for editing a single PetBehaviorLog entry, including notes and badge selection.
struct BehaviorBadgeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Maximum allowed length for behavior notes.
    private static let maxNoteLength: Int = 250

    @Bindable var log: PetBehaviorLog

    var body: some View {
        NavigationStack {
            Form {
                /// Section for entering and editing behavior notes.
                Section(header: Text("Behavior Notes")) {
                    TextEditor(text: $log.note)
                        .onChange(of: log.note) { newValue in
                            if newValue.count > Self.maxNoteLength {
                                log.note = String(newValue.prefix(Self.maxNoteLength))
                            }
                        }
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    VStack(alignment: .trailing) {
                        Text("\(log.note.count)/\(Self.maxNoteLength)")
                            .font(.caption)
                            .foregroundColor(log.note.count > Self.maxNoteLength ? .red : .secondary)
                    }
                }

                /// Section for choosing a behavior badge.
                Section(header: Text("Select Badge")) {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 12) {
                        ForEach(BadgeEngine.BehaviorBadge.allCases, id: \.self) { badge in
                            let emoji = badge.rawValue.components(separatedBy: " ").first!
                            Button {
                                log.tagEmoji = emoji
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
                                        .fill(log.tagEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
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
                            try context.save()
                        } catch {
                            print("⚠️ Failed to save behavior log:", error)
                        }
                        dismiss()
                    }
                    .disabled(log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || log.tagEmoji.isEmpty)
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
