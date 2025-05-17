//
//  ClientEngagementSummaryView.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//

import SwiftUI

// TODO: Move engagement summary logic into a dedicated ViewModel for better testability.

@MainActor
/// A summary card displaying client engagement metrics: total clients, retention risk, and top spenders.
struct ClientEngagementSummaryView: View {
  let appointments: [Appointment]
  let charges: [Charge]

  /// Formatter for displaying percentages.
  private static let percentFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .percent
    fmt.maximumFractionDigits = 0
    return fmt
  }()

  /// Percentage of clients at retention risk.
  private var retentionRiskPercentage: String {
    guard totalClients > 0 else { return "0%" }
    let ratio = Double(retentionRiskCount) / Double(totalClients)
    return Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? "0%"
  }

  /// Percentage of top-spender clients.
  private var topSpenderPercentage: String {
    guard totalClients > 0 else { return "0%" }
    let ratio = Double(topSpenderCount) / Double(totalClients)
    return Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? "0%"
  }

  // Build a stats object for each owner and aggregate
  private var statsByOwner: [ClientStats] {
    let owners = Set(appointments.map { $0.dogOwner })
    return owners.map { ClientStats(owner: $0) }
  }

  private var totalClients: Int { statsByOwner.count }
  private var retentionRiskCount: Int {
    statsByOwner.filter { $0.isRetentionRisk }.count
  }
  private var topSpenderCount: Int {
    statsByOwner.filter { $0.isTopSpender }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Client Engagement")
        .font(.headline)

      HStack {
        Label("\(totalClients)", systemImage: "person.3.fill")
        Text("Clients")
        Spacer()
        Label(retentionRiskPercentage, systemImage: "exclamationmark.triangle.fill")
          .foregroundColor(.yellow)
          .accessibilityLabel("\(retentionRiskCount) at risk (\(retentionRiskPercentage))")
        Text("At Risk")
        Spacer()
        Label(topSpenderPercentage, systemImage: "star.fill")
          .foregroundColor(.orange)
          .accessibilityLabel("\(topSpenderCount) top spenders (\(topSpenderPercentage))")
        Text("Top Spenders")
      }
      .font(.subheadline)
    }
    .cardStyle()
    .accessibilityElement(children: .combine)
  }
}
