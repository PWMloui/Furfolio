//
//  ClientEngagementSummaryView.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//

import SwiftUI

@MainActor
/// A summary card displaying client engagement metrics: total clients, retention risk, and top spenders.
struct ClientEngagementSummaryView: View {
  @StateObject private var viewModel = ClientEngagementSummaryViewModel()

  init(appointments: [Appointment], charges: [Charge]) {
    _viewModel = StateObject(wrappedValue: ClientEngagementSummaryViewModel())
    viewModel.update(appointments: appointments, charges: charges)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Client Engagement")
        .font(.headline)

      HStack {
        Label("\(viewModel.totalClients)", systemImage: "person.3.fill")
        Text("Clients")
        Spacer()
        Label(viewModel.retentionRiskPercentage, systemImage: "exclamationmark.triangle.fill")
          .foregroundColor(.yellow)
          .accessibilityLabel("\(viewModel.retentionRiskCount) at risk (\(viewModel.retentionRiskPercentage))")
        Text("At Risk")
        Spacer()
        Label(viewModel.topSpenderPercentage, systemImage: "star.fill")
          .foregroundColor(.orange)
          .accessibilityLabel("\(viewModel.topSpenderCount) top spenders (\(viewModel.topSpenderPercentage))")
        Text("Top Spenders")
      }
      .font(.subheadline)
    }
    .cardStyle()
    .accessibilityElement(children: .combine)
  }
}
