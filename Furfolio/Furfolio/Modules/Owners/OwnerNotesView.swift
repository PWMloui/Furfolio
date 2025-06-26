//
//  OwnerNotesView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Owner Notes
//

import SwiftUI

struct OwnerNotesView: View {
    @Binding var notes: String
    var placeholder: String = "Enter notes about this owner..."
    var maxLength: Int = 1000

    @State private var showLimitError: Bool = false
    @State private var appearedOnce: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Owner Notes")
                .font(.headline)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("OwnerNotesView-Header")

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .padding(.horizontal, 8)
                        .accessibilityIdentifier("OwnerNotesView-Placeholder")
                }
                TextEditor(text: $notes)
                    .padding(6)
                    .background(showLimitError ? Color.red.opacity(0.08) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .accessibilityIdentifier("OwnerNotesView-Editor")
                    .onChange(of: notes) { newValue in
                        if newValue.count > maxLength {
                            notes = String(newValue.prefix(maxLength))
                            showLimitError = true
                            OwnerNotesAudit.record(action: "EditError", noteCount: notes.count)
                        } else {
                            showLimitError = false
                            OwnerNotesAudit.record(action: "Edit", noteCount: notes.count)
                        }
                    }
            }
            HStack {
                Spacer()
                Text("\(notes.count)/\(maxLength)")
                    .font(.caption2)
                    .foregroundStyle(showLimitError ? .red : .secondary)
                    .accessibilityIdentifier("OwnerNotesView-CharCount")
            }
            if showLimitError {
                Text("Maximum note length reached.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("OwnerNotesView-LimitError")
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("OwnerNotesView-Root")
        .onAppear {
            if !appearedOnce {
                OwnerNotesAudit.record(action: "Appear", noteCount: notes.count)
                appearedOnce = true
            }
        }
    }
}

// --- Audit/Event Logging ---

fileprivate struct OwnerNotesAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let noteCount: Int
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerNotesView] \(action): \(noteCount) chars at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerNotesAudit {
    static private(set) var log: [OwnerNotesAuditEvent] = []
    static func record(action: String, noteCount: Int) {
        let event = OwnerNotesAuditEvent(timestamp: Date(), action: action, noteCount: noteCount)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum OwnerNotesAuditAdmin {
    public static func lastSummary() -> String { OwnerNotesAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { OwnerNotesAudit.recentSummaries(limit: limit) }
}

#Preview {
    @State var demoNotes = ""
    return OwnerNotesView(notes: $demoNotes)
}
