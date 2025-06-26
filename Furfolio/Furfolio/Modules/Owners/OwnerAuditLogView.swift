//
//  OwnerAuditLogView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Owner Audit Log
//

import SwiftUI

struct OwnerAuditLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let action: String
    let performedBy: String
    let details: String?
}

struct OwnerAuditLogView: View {
    let logEntries: [OwnerAuditLogEntry]
    @State private var showExport: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if logEntries.isEmpty {
                    ContentUnavailableView("No audit log entries.", systemImage: "doc.badge.gearshape")
                        .padding(.top, 60)
                        .accessibilityIdentifier("OwnerAuditLogView-Empty")
                } else {
                    List {
                        Section(header:
                            HStack {
                                Text("Activity")
                                    .font(.title3.bold())
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityIdentifier("OwnerAuditLogView-SectionHeader")
                                Spacer()
                                Button {
                                    showExport = true
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .accessibilityIdentifier("OwnerAuditLogView-ExportButton")
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                        ) {
                            ForEach(logEntries) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 10) {
                                        Image(systemName: icon(for: entry.action))
                                            .font(.headline)
                                            .foregroundColor(color(for: entry.action))
                                            .accessibilityHidden(true)
                                            .accessibilityIdentifier("OwnerAuditLogView-Icon-\(entry.id)")
                                        Text(entry.action)
                                            .font(.headline)
                                            .accessibilityIdentifier("OwnerAuditLogView-Action-\(entry.id)")
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text(entry.date, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(entry.date, style: .time)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .accessibilityIdentifier("OwnerAuditLogView-Date-\(entry.id)")
                                    }
                                    if let details = entry.details, !details.isEmpty {
                                        Text(details)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("OwnerAuditLogView-Details-\(entry.id)")
                                    }
                                    Text("By \(entry.performedBy)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .accessibilityIdentifier("OwnerAuditLogView-By-\(entry.id)")
                                }
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(color(for: entry.action).opacity(0.07))
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(entry.action), \(entry.details ?? ""), \(entry.date.formatted(date: .abbreviated, time: .shortened)), by \(entry.performedBy)")
                                .accessibilityIdentifier("OwnerAuditLogView-Entry-\(entry.id)")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Owner Audit Log")
            .background(Color(.systemGroupedBackground))
            .alert("Export Log", isPresented: $showExport, actions: {
                Button("Copy") {
                    UIPasteboard.general.string = logEntries.map(exportSummary).joined(separator: "\n")
                }
                Button("OK", role: .cancel) { }
            }, message: {
                ScrollView {
                    Text(logEntries.map(exportSummary).joined(separator: "\n"))
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            })
            .onAppear {
                OwnerAuditLogAudit.record(action: "Appear", count: logEntries.count)
            }
        }
    }

    private func icon(for action: String) -> String {
        let a = action.lowercased()
        if a.contains("add") { return "plus.circle.fill" }
        if a.contains("delete") || a.contains("remove") { return "trash.fill" }
        if a.contains("edit") || a.contains("update") { return "pencil.circle.fill" }
        if a.contains("appointment") { return "calendar" }
        if a.contains("charge") || a.contains("payment") { return "creditcard.fill" }
        return "doc.text"
    }
    private func color(for action: String) -> Color {
        let a = action.lowercased()
        if a.contains("add") { return .green }
        if a.contains("delete") || a.contains("remove") { return .red }
        if a.contains("edit") || a.contains("update") { return .orange }
        if a.contains("appointment") { return .blue }
        if a.contains("charge") || a.contains("payment") { return .purple }
        return .accentColor
    }
    private func exportSummary(_ entry: OwnerAuditLogEntry) -> String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let details = entry.details?.isEmpty == false ? " (\(entry.details!))" : ""
        return "[\(df.string(from: entry.date))] \(entry.action)\(details) by \(entry.performedBy)"
    }
}

// --- Optional: Audit/event log for this view's lifecycle (admin/QA/exportable) ---
fileprivate struct OwnerAuditLogAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let count: Int
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerAuditLogView] \(action): \(count) entry(s) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerAuditLogAudit {
    static private(set) var log: [OwnerAuditLogAuditEvent] = []
    static func record(action: String, count: Int) {
        let event = OwnerAuditLogAuditEvent(timestamp: Date(), action: action, count: count)
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

#if DEBUG
struct OwnerAuditLogView_Previews: PreviewProvider {
   
