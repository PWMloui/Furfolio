//
//  WellnessChecklistView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Data Model

struct WellnessChecklistItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    var isChecked: Bool
    var note: String?
}

struct WellnessChecklist {
    var petName: String
    var checklist: [WellnessChecklistItem]
    var ownerNote: String?
    var date: Date
}

// MARK: - WellnessChecklistView

struct WellnessChecklistView: View {
    @State var wellness: WellnessChecklist
    var onUpdate: ((WellnessChecklist) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("\(wellness.petName) Wellness Checklist")
                    .font(.headline)
                Spacer()
                BadgeView(
                    completed: completedCount,
                    total: wellness.checklist.count,
                    date: wellness.date
                )
            }
            Divider()
            // Checklist
            ForEach($wellness.checklist) { $item in
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        item.isChecked.toggle()
                        onUpdate?(wellness)
                    } label: {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(item.isChecked ? .green : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.body)
                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        Button("Add Note") {
                            showNotePrompt(for: item)
                        }
                        .font(.caption2)
                        .opacity(0.8)
                    }
                }
                .padding(.vertical, 4)
            }
            Divider()
            // Owner note
            VStack(alignment: .leading, spacing: 4) {
                Text("Owner Note:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Add a note...", text: Binding(
                    get: { wellness.ownerNote ?? "" },
                    set: { newVal in
                        wellness.ownerNote = newVal
                        onUpdate?(wellness)
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(radius: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wellness.petName) wellness checklist, \(completedCount) of \(wellness.checklist.count) completed.")
    }

    private var completedCount: Int {
        wellness.checklist.filter { $0.isChecked }.count
    }

    // MARK: - Note Prompt Logic (Simple Demo)
    private func showNotePrompt(for item: WellnessChecklistItem) {
        // For demo: In real use, present a prompt (sheet/alert) to edit note for `item`
        // You may implement a custom note editing logic here.
        // This is left as a placeholder for your UX.
    }
}

// MARK: - BadgeView

struct BadgeView: View {
    let completed: Int
    let total: Int
    let date: Date

    var body: some View {
        HStack(spacing: 4) {
            Text("\(completed)/\(total)")
                .font(.caption)
                .foregroundColor(completed == total ? .green : .orange)
            Image(systemName: completed == total ? "checkmark.seal.fill" : "clock")
                .foregroundColor(completed == total ? .green : .orange)
            Text(date, formatter: DateFormatter.shortDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(radius: 1)
        )
    }
}

// MARK: - Short Date Formatter

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt
    }()
}

// MARK: - Preview

#if DEBUG
struct WellnessChecklistView_Previews: PreviewProvider {
    static var previews: some View {
        WellnessChecklistView(wellness: .init(
            petName: "Bailey",
            checklist: [
                WellnessChecklistItem(label: "Ears Clean", isChecked: true, note: nil),
                WellnessChecklistItem(label: "Nails Trimmed", isChecked: false, note: "Quicked last time"),
                WellnessChecklistItem(label: "Teeth Brushed", isChecked: false, note: nil),
                WellnessChecklistItem(label: "Anal Glands Checked", isChecked: true, note: nil),
                WellnessChecklistItem(label: "Skin Check", isChecked: false, note: nil),
            ],
            ownerNote: "Please watch for itching this week.",
            date: Date()
        ))
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
