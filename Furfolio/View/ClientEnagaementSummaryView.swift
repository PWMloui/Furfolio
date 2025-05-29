//
//  ClientEngagementSummaryView.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//

import SwiftUI
import os

@MainActor
/// A summary card displaying client engagement metrics: total clients, retention risk, and top spenders.
struct ClientEngagementSummaryView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ClientEngagementSummaryView")
  @StateObject private var viewModel = ClientEngagementSummaryViewModel()

  init(appointments: [Appointment], charges: [Charge]) {
    _viewModel = StateObject(wrappedValue: ClientEngagementSummaryViewModel())
    viewModel.update(appointments: appointments, charges: charges)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Client Engagement")
        .font(AppTheme.header)
        .foregroundColor(AppTheme.primaryText)

      HStack {
        Label("\(viewModel.totalClients)", systemImage: "person.3.fill")
        Text("Clients")
        Spacer()
        Label(viewModel.retentionRiskPercentage, systemImage: "exclamationmark.triangle.fill")
          .foregroundColor(AppTheme.warning)
          .accessibilityLabel("\(viewModel.retentionRiskCount) at risk (\(viewModel.retentionRiskPercentage))")
        Text("At Risk")
        Spacer()
        Label(viewModel.topSpenderPercentage, systemImage: "star.fill")
          .foregroundColor(AppTheme.accent)
          .accessibilityLabel("\(viewModel.topSpenderCount) top spenders (\(viewModel.topSpenderPercentage))")
        Text("Top Spenders")
      }
      .font(AppTheme.body)
      .foregroundColor(AppTheme.primaryText)
    }
    .onAppear {
        logger.log("ClientEngagementSummaryView appeared: totalClients=\(viewModel.totalClients), atRisk=\(viewModel.retentionRiskCount), topSpenders=\(viewModel.topSpenderCount)")
    }
    .cardStyle()
    .accessibilityElement(children: .combine)
  }
}
