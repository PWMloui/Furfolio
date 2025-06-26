//
//  OwnerActivityTimelineView.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise, Auditable, Accessible Timeline
//

import SwiftUI

struct OwnerActivityEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let description: String?
    let icon: String
    let color: Color
}

struct OwnerActivityTimelineView: View {
    let events: [OwnerActivityEvent]

    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent Activity")
                    .font(.title3.bold())
                    .padding(.bottom, 8)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("OwnerActivityTimelineView-Header")

                if events.isEmpty {
                    ContentUnavailableView("No activity found.", systemImage: "clock.arrow.circlepath")
                        .padding(.top, 32)
                        .accessibilityIdentifier("OwnerActivityTimelineView-Empty")
                        .onAppear {
                            OwnerActivityTimelineAudit.record(action: "AppearEmpty", count: 0)
                        }
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 16) {
                            VStack {
                                // Timeline marker
                                ZStack {
                                    Circle()
                                        .fill(event.color)
                                        .frame(width: 20, height: 20)
                                        .shadow(color: event.color.opacity(0.21), radius: 3, x: 0, y: 1)
                                    Image(systemName: event.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                if index < events.count - 1 {
                                    Rectangle()
                                        .fill(event.color.opacity(0.22))
                                        .frame(width: 4, height: 46)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                    .accessibilityIdentifier("OwnerActivityTimelineView-Title-\(event.id)")
                                if let desc = event.description {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("OwnerActivityTimelineView-Desc-\(event.id)")
                                }
                                HStack(spacing: 8) {
                                    Text(event.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(event.date, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityIdentifier("OwnerActivityTimelineView-Date-\(event.id)")
                            }
                            .padding(.vertical, 6)
                            Spacer()
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(event.color.opacity(appeared ? 0.06 : 0.0))
                                .animation(.easeIn(duration: 0.8), value: appeared)
                        )
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(event.title), \(event.description ?? ""), \(event.date.formatted(date: .abbreviated, time: .shortened))")
                        .accessibilityIdentifier("OwnerActivityTimelineView-Event-\(event.id)")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .onAppear {
                appeared = true
                OwnerActivityTimelineAudit.record(action: "Appear", count: events.count)
            }
        }
        .navigationTitle("Owner Activity")
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Owner activity timeline")
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerActivityTimelineAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let count: Int
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerActivityTimeline] \(action): \(count) event(s) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerActivityTimelineAudit {
    static private(set) var log: [OwnerActivityTimelineAuditEvent] = []
    static func record(action: String, count: Int) {
        let event = OwnerActivityTimelineAuditEvent(timestamp: Date(), action: action, count: count)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum OwnerActivityTimelineAuditAdmin {
    public static func lastSummary() -> String { OwnerActivityTimelineAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { OwnerActivityTimelineAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { OwnerActivityTimelineAudit.recentSummaries(limit: limit) }
}

#if DEBUG
struct OwnerActivityTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerActivityTimelineView(
            events: [
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 3), title: "Appointment Booked", description: "Full Groom for Bella", icon: "calendar.badge.plus", color: .blue),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 2), title: "Payment Received", description: "Charge for Max - $85", icon: "dollarsign.circle.fill", color: .green),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 7), title: "Owner Info Updated", description: "Changed address", icon: "pencil.circle.fill", color: .orange)
            ]
        )
    }
}
#endif
