//
//  GroomingHistoryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Grooming History View
//

import SwiftUI

struct GroomingSession: Identifiable, Codable {
    let id: UUID
    var date: Date
    var services: [String]
    var durationMinutes: Int
    var notes: String?

    init(id: UUID = UUID(), date: Date, services: [String], durationMinutes: Int, notes: String? = nil) {
        self.id = id
        self.date = date
        self.services = services
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

// MARK: - Audit/Event Logging

fileprivate struct GroomingSessionAuditEvent: Codable {
    let timestamp: Date
    let sessionID: UUID
    let date: Date
    let services: [String]
    let duration: Int
    let notes: String?
    var summary: String {
        let f = DateFormatter(); f.dateStyle = .short; let dateStr = f.string(from: date)
        return "[GroomingHistory] \(sessionID): \(dateStr), services: \(services.joined(separator: ", ")), \(duration) min\(notes != nil ? ", notes: \(notes!)" : "")"
    }
}
fileprivate final class GroomingSessionAudit {
    static private(set) var log: [GroomingSessionAuditEvent] = []
    static func record(session: GroomingSession) {
        let event = GroomingSessionAuditEvent(
            timestamp: Date(),
            sessionID: session.id,
            date: session.date,
            services: session.services,
            duration: session.durationMinutes,
            notes: session.notes
        )
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Main View

struct GroomingHistoryView: View {
    let sessions: [GroomingSession]

    var body: some View {
        NavigationStack {
            List {
                Section(
                    header: Text("Grooming History")
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityIdentifier("GroomingHistoryView-Header"),
                    footer: Text("Total sessions: \(sessions.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .accessibilityIdentifier("GroomingHistoryView-Footer")
                ) {
                    if sessions.isEmpty {
                        Text("No grooming sessions found.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No grooming sessions found")
                            .accessibilityIdentifier("GroomingHistoryView-Empty")
                    } else {
                        ForEach(sessions) { session in
                            GroomingSessionRow(session: session)
                                .listRowBackground(Color(.secondarySystemBackground))
                                .onAppear {
                                    GroomingSessionAudit.record(session: session)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Grooming History")
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Row View

struct GroomingSessionRow: View {
    let session: GroomingSession
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.date, style: .date)
                .font(.headline)
                .accessibilityIdentifier("GroomingSessionRow-Date-\(session.id)")
            Text("Services: \(session.services.joined(separator: ", "))")
                .font(.subheadline)
                .accessibilityIdentifier("GroomingSessionRow-Services-\(session.id)")
            Text("Duration: \(session.durationMinutes) minutes")
                .font(.subheadline)
                .accessibilityIdentifier("GroomingSessionRow-Duration-\(session.id)")
            if let notes = session.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("GroomingSessionRow-Notes-\(session.id)")
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grooming session on \(session.date.formatted(date: .abbreviated, time: .omitted)), services: \(session.services.joined(separator: ", ")), duration: \(session.durationMinutes) minutes\(session.notes != nil && !session.notes!.isEmpty ? ", notes: \(session.notes!)" : "")")
        .accessibilityIdentifier("GroomingSessionRow-\(session.id)")
    }
}

// MARK: - Admin/Audit Accessors

public enum GroomingSessionAuditAdmin {
    public static func lastSummary() -> String { GroomingSessionAudit.log.last?.summary ?? "No grooming events yet." }
    public static func lastJSON() -> String? { GroomingSessionAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { GroomingSessionAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct GroomingHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSessions = [
            GroomingSession(date: Date(timeIntervalSinceNow: -86400 * 7), services: ["Full Groom", "Nail Trim"], durationMinutes: 90, notes: "Very calm, easy to groom."),
            GroomingSession(date: Date(timeIntervalSinceNow: -86400 * 30), services: ["Bath Only"], durationMinutes: 30, notes: nil),
            GroomingSession(date: Date(timeIntervalSinceNow: -86400 * 60), services: ["Nail Trim"], durationMinutes: 20, notes: "Slight anxiety noted."),
        ]

        GroomingHistoryView(sessions: sampleSessions)
    }
}
#endif
