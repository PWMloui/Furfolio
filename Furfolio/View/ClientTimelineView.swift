
//
//  ClientTimelineView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 4, 2025 — implemented timeline combining appointments, charges, behavior logs, and service history.
//


import SwiftUI
import SwiftData

// TODO: Move timeline-building logic into a dedicated ViewModel for cleaner views and easier testing

@MainActor
/// View displaying a unified timeline of appointments, charges, behavior logs, and service history for a client.
struct ClientTimelineView: View {
    @Environment(\.modelContext) private var context
    let owner: DogOwner

    /// Shared formatter for section headers.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .none
      return fmt
    }()
    /// Shared calendar for day grouping.
    private static let calendar = Calendar.current

    /// Represents a single entry in the client timeline (sorted by date descending).
    /// A unified event in the client timeline
    private struct TimelineEntry: Identifiable, Comparable {
        let id = UUID()
        let date: Date
        let title: String
        let subtitle: String?
        let icon: String

        static func < (lhs: TimelineEntry, rhs: TimelineEntry) -> Bool {
            lhs.date > rhs.date  // descending by date
        }
    }

    /// Aggregates all event entries (appointments, charges, logs, history) sorted by descending date.
    /// Build a sorted array of all timeline entries
    private var timeline: [TimelineEntry] {
        var entries: [TimelineEntry] = []

        // Appointments
        for appt in owner.appointments {
            entries.append(
                TimelineEntry(
                    date: appt.date,
                    title: "Appointment: \(appt.serviceType.localized)",
                    subtitle: appt.notes,
                    icon: "calendar"
                )
            )
        }

        // Charges
        for charge in owner.charges {
            entries.append(
                TimelineEntry(
                    date: charge.date,
                    title: "Charge: \(charge.formattedAmount)",
                    subtitle: charge.paymentMethod.localized,
                    icon: "dollarsign.circle"
                )
            )
        }

        // Behavior Logs
        for log in PetBehaviorLog.fetchAll(for: owner, in: context) {
            entries.append(
                TimelineEntry(
                    date: log.dateLogged,
                    title: "Behavior: \(log.tagEmoji ?? "")",
                    subtitle: log.note,
                    icon: "pawprint"
                )
            )
        }

        // Service History
        for hist in ServiceHistory.fetchAll(for: owner, in: context) {
            entries.append(
                TimelineEntry(
                    date: hist.date,
                    title: "Service: \(hist.serviceType.localized)",
                    subtitle: "Cost \(hist.formattedCost)",
                    icon: "scissors"
                )
            )
        }

        return entries.sorted()
    }

    var body: some View {
      List {
          ForEach(groupedByDay(), id: \.key) { day, events in
              Section(header: Text(day)) {
                  ForEach(events) { entry in
                      HStack(alignment: .top, spacing: 12) {
                          Image(systemName: entry.icon)
                              .frame(width: 24)
                          VStack(alignment: .leading, spacing: 2) {
                              Text(entry.title)
                                  .font(.headline)
                              if let sub = entry.subtitle {
                                  Text(sub)
                                      .font(.caption)
                                      .foregroundColor(.secondary)
                              }
                              Text(entry.date.formatted(.dateTime.hour().minute()))
                                  .font(.caption2)
                                  .foregroundColor(.gray)
                          }
                      }
                      .padding(.vertical, 4)
                  }
              }
          }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Timeline: \(owner.dogName)")
    }

    /// Groups timeline entries by calendar day, returning day-string and sorted events.
    private func groupedByDay() -> [(key: String, events: [TimelineEntry])] {
        let df = Self.dateFormatter

        let dict = Dictionary(grouping: timeline) { entry in
            df.string(from: entry.date)
        }
        // Sort keys descending by date value
        return dict.keys
            .compactMap { key -> (String, [TimelineEntry])? in
                guard let first = dict[key]?.first else { return nil }
                return (key, dict[key]!.sorted())
            }
            .sorted { lhs, rhs in
                // parse back to Date for sorting descending
                if let ld = df.date(from: lhs.0), let rd = df.date(from: rhs.0) {
                    return ld > rd
                }
                return lhs.0 > rhs.0
            }
    }
}

#if DEBUG
import SwiftUI

struct ClientTimelineView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        try! ModelContainer(
            for: DogOwner.self,
            Appointment.self,
            Charge.self,
            PetBehaviorLog.self,
            ServiceHistory.self
        )
    }()

    static var sampleOwner: DogOwner = {
        let o = DogOwner.sample
        let now = Date.now

        // insert appointments
        let appts = [
            Appointment(date: now.addingTimeInterval(-3600*24*3), dogOwner: o, serviceType: .basic, notes: "Grooming"),
            Appointment(date: now.addingTimeInterval(-3600*24*1), dogOwner: o, serviceType: .full,  notes: "Bath")
        ]
        o.appointments = appts

        // insert charges
        let charges = [
            Charge(date: now.addingTimeInterval(-3600*24*2), serviceType: .basic, amount: 45, paymentMethod: .cash, owner: o, notes: "Paid cash"),
            Charge(date: now.addingTimeInterval(-3600*12),     serviceType: .full,  amount: 80, paymentMethod: .credit, owner: o, notes: nil)
        ]
        o.charges = charges

        // behavior logs
        let logs = [
            PetBehaviorLog(note: "Calm",          owner: o),
            PetBehaviorLog(note: "Anxious vet visit", owner: o)
        ]

        // service history
        let histories = [
            ServiceHistory(date: now.addingTimeInterval(-3600*24*5), serviceType: .basic, durationMinutes: 60, cost: 40, notes: nil, dogOwner: o),
            ServiceHistory(date: now.addingTimeInterval(-3600*24*2), serviceType: .full,  durationMinutes: 90, cost: 80, notes: "Deluxe", dogOwner: o)
        ]

        container.mainContext.insert(o)
        appts.forEach     { container.mainContext.insert($0) }
        charges.forEach   { container.mainContext.insert($0) }
        logs.forEach      { container.mainContext.insert($0) }
        histories.forEach { container.mainContext.insert($0) }

        return o
    }()

    static var previews: some View {
        NavigationStack {
            ClientTimelineView(owner: sampleOwner)
                .environment(\.modelContext, container.mainContext)
        }
    }
}
#endif
