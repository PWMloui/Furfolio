//
//  DashboardViewModel.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import Combine

/// ViewModel for the dashboard, providing summary statistics and progress.
@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var upcomingAppointmentsCount: Int = 0
    @Published var totalRevenue: Double = 0.0
    @Published var inactiveCustomersCount: Int = 0
    @Published var loyaltyProgress: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Initialization

    init() {
        Task {
            await refreshData()
        }
    }

    // MARK: - Public Methods

    /// Refreshes all dashboard data asynchronously with simulated delay.
    func refreshData() async {
        isLoading = true
        errorMessage = nil

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay

            // Replace with real data sources
            upcomingAppointmentsCount = Int.random(in: 0...10)
            totalRevenue = Double.random(in: 1000...10000)
            inactiveCustomersCount = Int.random(in: 0...5)
            loyaltyProgress = Double.random(in: 0...1)

        } catch {
            errorMessage = "Failed to load dashboard data."
        }

        isLoading = false
    }
}

#if DEBUG
import SwiftUI

struct DashboardViewModel_Previews: PreviewProvider {
    @StateObject static var viewModel = DashboardViewModel()

    static var previews: some View {
        VStack(spacing: 16) {
            Text("Upcoming Appointments: \(viewModel.upcomingAppointmentsCount)")
            Text("Total Revenue: $\(String(format: "%.2f", viewModel.totalRevenue))")
            Text("Inactive Customers: \(viewModel.inactiveCustomersCount)")
            Text("Loyalty Progress: \(Int(viewModel.loyaltyProgress * 100))%")

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .task {
            await viewModel.refreshData()
        }
    }
}
#endif
