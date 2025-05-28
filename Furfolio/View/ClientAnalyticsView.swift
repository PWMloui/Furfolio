//
//  ClientAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 4, 2025 — polished UI with summary cards, corrected Section syntax, enhanced previews.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class ClientAnalyticsViewModel: ObservableObject {
  @Published var formattedAverageCharge: String = ""
  @Published var totalVisits: Int = 0
  @Published var totalRevenue: String = ""
  @Published var behaviorRiskCategory: String = ""
  @Published var behaviorRiskColor: Color = .green

  private static let currencyFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = .current
    return fmt
  }()

  init(owner: DogOwner) {
    totalVisits = owner.charges.count

    let totalAmount = owner.charges.reduce(0) { $0 + $1.amount }
    totalRevenue = Self.currencyFormatter.string(from: NSNumber(value: totalAmount)) ?? "\(totalAmount)"

    let avg = owner.charges.isEmpty ? 0 : totalAmount / Double(owner.charges.count)
    formattedAverageCharge = Self.currencyFormatter.string(from: NSNumber(value: avg)) ?? "\(avg)"

    let stats = ClientStats(owner: owner)
    behaviorRiskCategory = stats.behaviorRiskCategory
    behaviorRiskColor = stats.isBehaviorRisk ? .red : .green
  }
}

@MainActor
/// Displays client metrics including summary cards, overview details, visits, revenue, and behavior stats.
struct ClientAnalyticsView: View {
  @Environment(\.modelContext) private var context
  let owner: DogOwner

  @StateObject private var viewModel: ClientAnalyticsViewModel

  init(owner: DogOwner) {
    self.owner = owner
    _viewModel = StateObject(wrappedValue: ClientAnalyticsViewModel(owner: owner))
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
          LabeledContent("Loyalty") { Text(ClientStats(owner: owner).loyaltyStatus) }
          LabeledContent("Reward Progress") { Text(ClientStats(owner: owner).loyaltyProgressTag) }
        } header: {
          Text("Overview")
        }

        // MARK: — Visits & Revenue
        Section {
          LabeledContent("Total Visits") { Text("\(viewModel.totalVisits)") }
          LabeledContent("Upcoming Visits") { Text("\(ClientStats(owner: owner).upcomingAppointmentsCount)") }
          LabeledContent("Past Visits") { Text("\(ClientStats(owner: owner).pastAppointmentsCount)") }
          LabeledContent("Total Charged") { Text(viewModel.totalRevenue) }
          LabeledContent("Average Charge") { Text(viewModel.formattedAverageCharge) }
        } header: {
          Text("Visits & Revenue")
        }

        // MARK: — Behavior
        Section {
          LabeledContent("Avg. Severity") {
            Text(String(format: "%.1f", ClientStats(owner: owner).averageBehaviorSeverity))
          }
          LabeledContent("Risk Level") {
            Text(viewModel.behaviorRiskCategory)
              .foregroundColor(viewModel.behaviorRiskColor)
          }
          if !ClientStats(owner: owner).recentBehaviorBadges.isEmpty {
            Text("Recent Badges")
              .font(.subheadline).bold()
            ForEach(ClientStats(owner: owner).recentBehaviorBadges.prefix(3), id: \.self) { badge in
              Text("• \(badge)")
                .font(.caption)
            }
          }
        } header: {
          Text("Behavior")
        }

        // MARK: — Appointments
        Section {
          if let next = ClientStats(owner: owner).nextAppointment {
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
          if !ClientStats(owner: owner).recentAppointments.isEmpty {
            Text("Recent appointments:")
              .font(.subheadline).bold()
            ForEach(ClientStats(owner: owner).recentAppointments.prefix(3)) { appt in
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
        summaryCard(title: "Visits", value: "\(viewModel.totalVisits)", color: .blue)
        summaryCard(title: "Revenue", value: viewModel.totalRevenue, color: .green)
        summaryCard(title: "Avg Charge", value: viewModel.formattedAverageCharge, color: .purple)
        summaryCard(title: "Behavior Risk", value: viewModel.behaviorRiskCategory, color: viewModel.behaviorRiskColor)
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
