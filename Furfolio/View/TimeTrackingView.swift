//
//  TimeTrackingView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os
import AppTheme

struct TimeTrackingView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TimeTrackingView")
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.startTime, order: .reverse)]) private var sessions: [SessionLog]

    @State private var isClockedIn: Bool = false
    @State private var currentSession: SessionLog?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if isClockedIn {
                    Button(action: {
                        logger.log("Clock Out tapped")
                        clockOut()
                    }) {
                        Label("Clock Out", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(FurfolioButtonStyle())
                } else {
                    Button(action: {
                        logger.log("Clock In tapped")
                        clockIn()
                    }) {
                        Label("Clock In", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(FurfolioButtonStyle())
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
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                                Text(session.startTime, style: .time)
                                    .font(AppTheme.body)
                                    .foregroundColor(AppTheme.primaryText)
                            }
                            if let end = session.endTime {
                                HStack {
                                    Text("End:")
                                        .font(AppTheme.caption)
                                        .foregroundColor(AppTheme.secondaryText)
                                    Text(end, style: .time)
                                        .font(AppTheme.body)
                                        .foregroundColor(AppTheme.primaryText)
                                }
                                HStack {
                                    Text("Duration:")
                                        .font(AppTheme.caption)
                                        .foregroundColor(AppTheme.secondaryText)
                                    Text(durationString(from: session.startTime, to: end))
                                        .font(AppTheme.body)
                                        .foregroundColor(AppTheme.primaryText)
                                }
                            } else {
                                Text("In progress…")
                                    .italic()
                                    .foregroundColor(AppTheme.warning)
                                    .font(AppTheme.body)
                            }
                        }
                        .padding(.vertical, 4)
                        .onAppear {
                            logger.log("Rendering session row: start=\(session.startTime), end=\(String(describing: session.endTime))")
                        }
                    }
                }
                .onAppear {
                    logger.log("Sessions section displayed with count: \(sessions.count)")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Time Tracking")
        .onAppear(perform: syncClockState)
        .onAppear {
            logger.log("TimeTrackingView appeared; isClockedIn=\(isClockedIn), sessionCount=\(sessions.count)")
        }
    }

    // MARK: - Actions

    private func clockIn() {
        logger.log("clockIn() invoked")
        let newSession = SessionLog(startTime: Date(), endTime: nil)
        context.insert(newSession)
        currentSession = newSession
        isClockedIn = true
    }

    private func clockOut() {
        logger.log("clockOut() invoked")
        guard let session = currentSession else { return }
        session.endTime = Date()
        do {
            try context.save()
        } catch {
            logger.error("Failed to save clock-out: \(error.localizedDescription)")
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
