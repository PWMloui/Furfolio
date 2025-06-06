//  TopClientsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 18, 2025 — added full SwiftUI implementation for displaying top clients by revenue.
//

import SwiftUI
import SwiftData
import os

// TODO: Move client-stats calculation and top-clients filtering into a TopClientsViewModel for cleaner view code and better testability.

@MainActor
final class TopClientsViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TopClientsViewModel")
    @Published private(set) var topClients: [(owner: DogOwner, stats: ClientStats)] = []
    let maxCount = 5

    func update(owners: [DogOwner]) {
        logger.log("Updating top clients with \(owners.count) owners")
        topClients = owners
            .map { (owner: $0, stats: ClientStats(owner: $0)) }
            .sorted { $0.stats.totalCharges > $1.stats.totalCharges }
        logger.log("Computed topClients count: \(topClients.count)")
    }
}

@MainActor
/// Displays the top revenue-generating clients with their visit count and total charges.
struct TopClientsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TopClientsView")
    @Environment(\.modelContext) private var modelContext

    /// Fetches all DogOwner entities sorted by name.
    @Query(sort: \.ownerName, order: .forward) private var owners: [DogOwner]

    @StateObject private var viewModel = TopClientsViewModel()

    /// Shared formatter for currency values.
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Top \(viewModel.maxCount) Clients by Revenue")
                        .font(AppTheme.title)
                        .foregroundColor(AppTheme.primaryText)
                ) {
                    ForEach(Array(viewModel.topClients.prefix(viewModel.maxCount).enumerated()), id: \.element.owner.id) { index, entry in
                        TopClientRow(rank: index + 1, owner: entry.owner, stats: entry.stats)
                    }
                    if owners.count > viewModel.maxCount {
                      /// Navigate to full client list when tapped.
                        Button("Show All Clients") {
                            logger.log("Show All Clients tapped")
                            // Could navigate to a full list view
                        }
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.accent)
                        .buttonStyle(FurfolioButtonStyle())
                        .cardStyle()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Top Clients")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            logger.log("TopClientsView appeared; owners: \(owners.count), topClients: \(viewModel.topClients.count)")
            viewModel.update(owners: owners)
        }
        .onChange(of: owners) { newOwners in
            logger.log("Owners changed; new count: \(newOwners.count)")
            viewModel.update(owners: newOwners)
        }
    }
}

@MainActor
/// Row showing a ranked client with visit count and formatted charges.
private struct TopClientRow: View {
    private let rowLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TopClientRow")
    let rank: Int
    let owner: DogOwner
    let stats: ClientStats

    var body: some View {
        rowLogger.log("Rendering TopClientRow rank: \(rank), owner: \(owner.ownerName)")
        HStack {
            Text("\(rank).")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading) {
                Text(owner.ownerName)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                HStack {
                    Text("Visits: \(stats.totalAppointments)")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text(TopClientsView.currencyFormatter.string(from: NSNumber(value: stats.totalCharges)) ?? "")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
        .cardStyle()
    }
}

#if DEBUG
struct TopClientsView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [DogOwner.self, Appointment.self, Charge.self],
            modelConfiguration: config
        )
    }()

    static var previews: some View {
        let ctx = container.mainContext

        // Create sample owners with charges
        let owner1 = DogOwner.sample; ctx.insert(owner1)
        let owner2 = DogOwner.sample; owner2.ownerName = "Alice"; ctx.insert(owner2)
        let owner3 = DogOwner.sample; owner3.ownerName = "Bob"; ctx.insert(owner3)

        // Add sample charges
        Charge.create(date: Date.now, serviceType: .basic, amount: 50, paymentMethod: .cash, owner: owner1, in: ctx)
        Charge.create(date: Date.now, serviceType: .full, amount: 120, paymentMethod: .credit, owner: owner1, in: ctx)
        Charge.create(date: Date.now, serviceType: .basic, amount: 30, paymentMethod: .cash, owner: owner2, in: ctx)
        Charge.create(date: Date.now, serviceType: .full, amount: 80, paymentMethod: .credit, owner: owner3, in: ctx)
        Charge.create(date: Date.now, serviceType: .full, amount: 80, paymentMethod: .credit, owner: owner3, in: ctx)

        return TopClientsView()
            .environment(\.modelContext, ctx)
    }
}
#endif
