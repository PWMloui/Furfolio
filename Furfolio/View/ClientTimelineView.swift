//
//  ClientTimelineView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 4, 2025 — implemented timeline combining appointments, charges, behavior logs, and service history.
//


import SwiftUI
import SwiftData
import os

@MainActor
/// View displaying a unified timeline of appointments, charges, behavior logs, and service history for a client.
struct ClientTimelineView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ClientTimelineView")
    let owner: DogOwner
    @StateObject private var viewModel: ClientTimelineViewModel

    init(owner: DogOwner) {
        self.owner = owner
        let ctx = ModelContext.current
        _viewModel = StateObject(wrappedValue: ClientTimelineViewModel(owner: owner, context: ctx))
    }

    var body: some View {
      List {
          ForEach(viewModel.groupedEntries, id: \.key) { day, events in
              Section(header: Text(day)
                  .font(AppTheme.title)
                  .foregroundColor(AppTheme.primaryText)
              ) {
                  ForEach(events) { entry in
                      HStack(alignment: .top, spacing: 12) {
                          Image(systemName: entry.icon)
                              .frame(width: 24)
                          VStack(alignment: .leading, spacing: 2) {
                              Text(entry.title)
                                  .font(AppTheme.body)
                                  .foregroundColor(AppTheme.primaryText)
                              if let sub = entry.subtitle {
                                  Text(sub)
                                      .font(AppTheme.caption)
                                      .foregroundColor(AppTheme.secondaryText)
                              }
                              Text(entry.date.formatted(.dateTime.hour().minute()))
                                  .font(AppTheme.caption)
                                  .foregroundColor(AppTheme.secondaryText)
                          }
                      }
                      .onAppear {
                          logger.log("Displaying timeline entry: \(entry.title) at \(entry.date)")
                      }
                      .padding(.vertical, 4)
                  }
              }
          }
      }
      .onAppear {
          logger.log("ClientTimelineView appeared for owner id: \(owner.id), sections: \(viewModel.groupedEntries.count)")
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Timeline: \(owner.dogName)")
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
