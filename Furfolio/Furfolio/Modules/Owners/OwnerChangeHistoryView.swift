//
//  OwnerChangeHistoryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Change History
//

import SwiftUI

struct OwnerChangeHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let fieldChanged: String
    let oldValue: String
    let newValue: String
    let changedBy: String
}

struct OwnerChangeHistoryView: View {
    let changes: [OwnerChangeHistoryEntry]
    @State private var showExport: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if changes.isEmpty {
                    ContentUnavailableView("No change history.", systemImage: "clock.arrow.circlepath")
                        .padding(.top, 48)
                        .accessibilityIdentifier("OwnerChangeHistoryView-Empty")
                        .onAppear {
                            OwnerChangeHistoryAudit.record(action: "AppearEmpty", count: 0)
                        }
                } else {
                    Section(header:
                        HStack {
                            Text("Field Changes")
                                .font(.title3.bold())
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("OwnerChangeHistoryView-SectionHeader")
                            Spacer()
                            Button {
                                showExport = true
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .accessibilityIdentifier("OwnerChangeHistoryView-ExportButton")
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                    ) {
                        ForEach(changes) { entry in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Badge(text: entry.fieldChanged, color: .accentColor)
                                    Spacer()
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("OwnerChangeHistoryView-Date-\(entry.id)")
                                }
                                HStack(spacing: 10) {
                                    Text("From")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 2)
                                    Text(entry.oldValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 2)
                                    Text("→")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(entry.newValue)
                                        .font(.caption2.bold())
                                        .foregroundColor(.primary)
                                }
                                .accessibilityIdentifier("OwnerChangeHistoryView-FromTo-\(entry.id)")
                                Text("Changed by \(entry.changedBy)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .accessibilityIdentifier("OwnerChangeHistoryView-By-\(entry.id)")
                            }
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(entry.fieldChanged) changed from \(entry.oldValue) to \(entry.newValue), \(entry.date.formatted(date: .abbreviated, time: .shortened)), by \(entry.changedBy)")
                            .accessibilityIdentifier("OwnerChangeHistoryView-Entry-\(entry.id)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Change History")
            .background(Color(.systemGroupedBackground))
            .alert("Export Change Log", isPresented: $showExport, actions: {
                Button("Copy") {
                    UIPasteboard.general.string = changes.map(exportSummary).joined(separator: "\n")
                }
                Button("OK", role: .cancel) { }
            }, message: {
                ScrollView {
                    Text(changes.map(exportSummary).joined(separator: "\n"))
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            })
            .onAppear {
                OwnerChangeHistoryAudit.record(action: "Appear", count: changes.count)
            }
        }
    }

    private func exportSummary(_ entry: OwnerChangeHistoryEntry) -> String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[\(df.string(from: entry.date))] \(entry.fieldChanged): \"\(entry.oldValue)\" → \"\(entry.newValue)\" by \(entry.changedBy)"
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.20))
            .foregroundColor(color)
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerChangeHistoryAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let count: Int
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerChangeHistoryView] \(action): \(count) entr\(count == 1 ? "y" : "ies") at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerChangeHistoryAudit {
    static private(set) var log: [OwnerChangeHistoryAuditEvent] = []
    static func record(action: String, count: Int) {
        let event = OwnerChangeHistoryAuditEvent(timestamp: Date(), action: action, count: count)
        log.append(event)
        if log.count > 24 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

#if DEBUG
struct OwnerChangeHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerChangeHistoryView(
            changes: [
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 2), fieldChanged: "Phone Number", oldValue: "555-123-4567", newValue: "555-987-6543", changedBy: "Admin"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 1), fieldChanged: "Address", oldValue: "123 Main St", newValue: "321 Bark Ave", changedBy: "Staff1"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 3), fieldChanged: "Email", oldValue: "jane@old.com", newValue: "jane@new.com", changedBy: "Admin")
            ]
        )
    }
}
#endif
