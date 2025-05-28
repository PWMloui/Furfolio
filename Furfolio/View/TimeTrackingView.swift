//
//  TimeTrackingView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData

struct TimeTrackingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.startTime, order: .reverse)]) private var sessions: [SessionLog]

    @State private var isClockedIn: Bool = false
    @State private var currentSession: SessionLog?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if isClockedIn {
                    Button(action: clockOut) {
                        Label("Clock Out", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: clockIn) {
                        Label("Clock In", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()

            List {
                Section("Sessions") {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Start:")
                                Text(session.startTime, style: .time)
                            }
                            if let end = session.endTime {
                                HStack {
                                    Text("End:")
                                    Text(end, style: .time)
                                }
                                HStack {
                                    Text("Duration:")
                                    Text(durationString(from: session.startTime, to: end))
                                }
                            } else {
                                Text("In progress…")
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Time Tracking")
        .onAppear(perform: syncClockState)
    }

    // MARK: - Actions

    private func clockIn() {
        let newSession = SessionLog(startTime: Date(), endTime: nil)
        context.insert(newSession)
        currentSession = newSession
        isClockedIn = true
    }

    private func clockOut() {
        guard let session = currentSession else { return }
        session.endTime = Date()
        do {
            try context.save()
        } catch {
            print("Failed to save clock-out: \(error)")
        }
        isClockedIn = false
        currentSession = nil
    }

    private func syncClockState() {
        if let last = sessions.first, last.endTime == nil {
            // There's an active session
            currentSession = last
            isClockedIn = true
        } else {
            isClockedIn = false
            currentSession = nil
        }
    }

    // MARK: - Helpers

    private func durationString(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "--"
    }
}

#Preview {
    NavigationStack {
        TimeTrackingView()
    }
    .modelContainer(for: SessionLog.self)
}
