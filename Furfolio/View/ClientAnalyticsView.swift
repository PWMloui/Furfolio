//
//  ClientAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 4, 2025 — polished UI with summary cards, corrected Section syntax, enhanced previews.
//

import SwiftUI
import SwiftData

// TODO: Move analytics logic into a dedicated ViewModel; cache formatters to improve performance.

@MainActor
/// Displays client metrics including summary cards, overview details, visits, revenue, and behavior stats.
struct ClientAnalyticsView: View {
  @Environment(\.modelContext) private var context
  let owner: DogOwner

  /// Shared currency formatter for average and total charges.
  private static let currencyFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = .current
    return fmt
  }()

  /// All derived metrics for this client
  private var stats: ClientStats { ClientStats(owner: owner) }

  /// Computes and formats the average charge amount for the client.
  private var formattedAverageCharge: String {
    let avg = owner.charges.isEmpty
      ? 0
      : owner.charges.reduce(0) { $0 + $1.amount } / Double(owner.charges.count)
    return Self.currencyFormatter.string(from: NSNumber(value: avg)) ?? "\(avg)"
  }

  var body: some View {
    NavigationStack {
      List {
        // MARK: — Summary Cards
        summaryCardsSection()

        // MARK: — Overview
        Section {
          LabeledContent("Name") { Text(owner.ownerName) }
          LabeledContent("Pup") { Text(owner.dogName) }
          LabeledContent("Loyalty") { Text(stats.loyaltyStatus) }
          LabeledContent("Reward Progress") { Text(stats.loyaltyProgressTag) }
        } header: {
          Text("Overview")
        }

        // MARK: — Visits & Revenue
        Section {
          LabeledContent("Total Visits") { Text("\(stats.totalAppointments)") }
          LabeledContent("Upcoming Visits") { Text("\(stats.upcomingAppointmentsCount)") }
          LabeledContent("Past Visits") { Text("\(stats.pastAppointmentsCount)") }
          LabeledContent("Total Charged") { Text(stats.formattedTotalCharges) }
          LabeledContent("Average Charge") { Text(formattedAverageCharge) }
        } header: {
          Text("Visits & Revenue")
        }

        // MARK: — Behavior
        Section {
          LabeledContent("Avg. Severity") {
            Text(String(format: "%.1f", stats.averageBehaviorSeverity))
          }
          LabeledContent("Risk Level") {
            Text(stats.behaviorRiskCategory)
              .foregroundColor(stats.isBehaviorRisk ? .red : .green)
          }
          if !stats.recentBehaviorBadges.isEmpty {
            Text("Recent Badges")
              .font(.subheadline).bold()
            ForEach(stats.recentBehaviorBadges.prefix(3), id: \.self) { badge in
              Text("• \(badge)")
                .font(.caption)
            }
          }
        } header: {
          Text("Behavior")
        }

        // MARK: — Appointments
        Section {
          if let next = stats.nextAppointment {
            VStack(alignment: .leading) {
              Text("Next appointment:")
              Text(next.formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          } else {
            Text("No upcoming appointments")
              .foregroundColor(.secondary)
          }
          if !stats.recentAppointments.isEmpty {
            Text("Recent appointments:")
              .font(.subheadline).bold()
            ForEach(stats.recentAppointments.prefix(3)) { appt in
              Text("• \(appt.formattedDate) — \(appt.serviceType.localized)")
                .font(.caption)
            }
          }
        } header: {
          Text("Appointments")
        }

        // MARK: — Actions
        Section {
          Button("Add Appointment") {
            // TODO: present AddAppointmentView(owner:)
          }
          Button("Add Charge") {
            // TODO: present AddChargeView(owner:)
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Client Analytics")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  /// Builds horizontal, scrollable summary cards for key metrics.
  @ViewBuilder
  private func summaryCardsSection() -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        summaryCard(title: "Visits", value: "\(stats.totalAppointments)", color: .blue)
        summaryCard(title: "Revenue", value: stats.formattedTotalCharges, color: .green)
        summaryCard(title: "Avg Charge", value: formattedAverageCharge, color: .purple)
        summaryCard(title: "Behavior Risk", value: stats.behaviorRiskCategory, color: stats.isBehaviorRisk ? .red : .orange)
      }
      .padding(.vertical, 8)
    }
    .listRowInsets(EdgeInsets())  // extend full width
  }

  /// Renders a single summary card with title, value, and accent color.
  private func summaryCard(title: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.title3).bold()
        .foregroundColor(color)
    }
    .padding()
    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(radius: 2))
  }
}

// MARK: — Preview

#if DEBUG
import SwiftUI

struct ClientAnalyticsView_Previews: PreviewProvider {
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

    // appointments
    let appts = [
      Appointment(date: Calendar.current.date(byAdding: .day, value: -10, to: now)!, dogOwner: o, serviceType: .basic, notes: "Past"),
      Appointment(date: Calendar.current.date(byAdding: .day, value: 3, to: now)!,   dogOwner: o, serviceType: .full,  notes: "Upcoming"),
      Appointment(date: Calendar.current.date(byAdding: .day, value: -5, to: now)!, dogOwner: o, serviceType: .custom,notes: "Past")
    ]
    o.appointments = appts

    // charges
    let charges = [
      Charge(date: Calendar.current.date(byAdding: .day, value: -10, to: now)!, serviceType: .basic,  amount: 50, paymentMethod: .cash,   owner: o, notes: nil),
      Charge(date: Calendar.current.date(byAdding: .day, value: -5, to: now)!,  serviceType: .full,   amount: 75, paymentMethod: .credit, owner: o, notes: nil),
      Charge(date: Calendar.current.date(byAdding: .day, value: 3, to: now)!,   serviceType: .custom, amount: 65, paymentMethod: .zelle,  owner: o, notes: nil)
    ]
    o.charges = charges

    // behavior logs
    let logs = [
      PetBehaviorLog(note: "Calm and friendly", owner: o),
      PetBehaviorLog(note: "Anxious around loud noises", owner: o),
      PetBehaviorLog(note: "Aggressive behavior", owner: o)
    ]

    // insert into context
    container.mainContext.insert(o)
    appts.forEach { container.mainContext.insert($0) }
    charges.forEach { container.mainContext.insert($0) }
    logs.forEach    { container.mainContext.insert($0) }

    return o
  }()

  static var previews: some View {
    ClientAnalyticsView(owner: sampleOwner)
      .environment(\.modelContext, container.mainContext)
      .previewLayout(.sizeThatFits)
  }
}
#endif
