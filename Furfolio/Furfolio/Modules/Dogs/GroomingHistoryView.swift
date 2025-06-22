//
//  GroomingHistoryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  GroomingHistoryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct GroomingSession: Identifiable {
    let id = UUID()
    var date: Date
    var services: [String]
    var durationMinutes: Int
    var notes: String?
}

struct GroomingHistoryView: View {
    let sessions: [GroomingSession]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Grooming History")
                    .font(.title2)
                    .fontWeight(.bold)
                ) {
                    if sessions.isEmpty {
                        Text("No grooming sessions found.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No grooming sessions found")
                    } else {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.date, style: .date)
                                    .font(.headline)
                                Text("Services: \(session.services.joined(separator: ", "))")
                                    .font(.subheadline)
                                Text("Duration: \(session.durationMinutes) minutes")
                                    .font(.subheadline)
                                if let notes = session.notes, !notes.isEmpty {
                                    Text("Notes: \(notes)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Grooming session on \(session.date.formatted(date: .abbreviated, time: .omitted)), services: \(session.services.joined(separator: ", ")), duration: \(session.durationMinutes) minutes\(session.notes != nil && !session.notes!.isEmpty ? ", notes: \(session.notes!)" : "")")
                        }
                    }
                }
            }
            .navigationTitle("Grooming History")
            .listStyle(.insetGrouped)
        }
    }
}

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
