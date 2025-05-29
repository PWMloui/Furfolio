
//  ChargeSummaryView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 2, 2025 — added totals, averages, grouping by payment method, empty state.
//

import SwiftUI
import SwiftData
import os

@MainActor
class ChargeSummaryViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ChargeSummaryViewModel")
    @Published var charges: [Charge] = []
    
    private let owner: DogOwner
    private let context: ModelContext
    
    init(owner: DogOwner, context: ModelContext) {
        self.owner = owner
        self.context = context
        load()
    }
    
    func load() {
        logger.log("Loading charges for owner id: \(owner.id)")
        charges = owner.charges.sorted { $0.date > $1.date }
        logger.log("Loaded \(charges.count) charges")
    }
    
    var totalAmount: Double {
        logger.log("Computing totalAmount")
        return charges.reduce(0) { $0 + $1.amount }
    }
    
    var averageAmount: Double {
        logger.log("Computing averageAmount")
        guard !charges.isEmpty else { return 0 }
        return totalAmount / Double(charges.count)
    }
    
    var paymentBreakdown: [Charge.PaymentMethod: Int] {
        logger.log("Computing paymentBreakdown")
        return Dictionary(grouping: charges, by: \.paymentMethod).mapValues(\.count)
    }
    
    func delete(at offsets: IndexSet) {
        logger.log("Deleting charges at offsets: \(offsets)")
        for idx in offsets {
            let toDelete = charges[idx]
            context.delete(toDelete)
        }
        load()
        logger.log("Post-delete, \(charges.count) charges remain")
    }
}

// TODO: Move summary logic and formatting into a dedicated ViewModel; use a shared NumberFormatter for performance.

@MainActor
/// Displays a summary and history of charges for a specific DogOwner, with totals and breakdowns.
struct ChargeSummaryView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ChargeSummaryView")
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let owner: DogOwner
    @StateObject private var viewModel: ChargeSummaryViewModel

    /// Shared currency formatter to avoid repeated allocations.
    private static let currencyFormatter: NumberFormatter = {
      let fmt = NumberFormatter()
      fmt.numberStyle = .currency
      fmt.locale = .current
      return fmt
    }()

    init(owner: DogOwner) {
        self.owner = owner
        _viewModel = StateObject(wrappedValue: ChargeSummaryViewModel(owner: owner, context: PreviewContext.container.mainContext))
    }

    var body: some View {
        NavigationStack {
            List {
                // Header with totals
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Charged: \(formatted(viewModel.totalAmount))")
                            .font(AppTheme.header)
                            .foregroundColor(AppTheme.primaryText)
                        Text("Average: \(formatted(viewModel.averageAmount))")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.secondaryText)
                        HStack {
                            ForEach(Charge.PaymentMethod.allCases) { method in
                                if let count = viewModel.paymentBreakdown[method], count > 0 {
                                    Text("\(method.symbol) \(count)")
                                        .font(AppTheme.caption)
                                        .padding(4)
                                        .background(AppTheme.disabled)
                                        .foregroundColor(AppTheme.primaryText)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Summary")
                }

                // Individual charges
                if viewModel.charges.isEmpty {
                    Section {
                        Text("No charges recorded yet.")
                            .foregroundColor(AppTheme.secondaryText)
                            .font(AppTheme.body)
                    }
                } else {
                    Section(header: Text("Charge History")) {
                        ForEach(viewModel.charges) { charge in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(charge.formattedDate)
                                        .font(AppTheme.caption)
                                        .foregroundColor(AppTheme.secondaryText)
                                    Text(charge.formattedAmount)
                                        .font(AppTheme.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.primaryText)
                                    if let notes = charge.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(AppTheme.caption)
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                }
                                Spacer()
                                Text(charge.paymentMethod.localized)
                                    .font(AppTheme.caption)
                                    .padding(4)
                                    .background(AppTheme.info.opacity(0.1))
                                    .foregroundColor(AppTheme.info)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.delete)
                    }
                }
            }
            .navigationTitle("Charges for \(owner.dogName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        logger.log("ChargeSummaryView Close tapped")
                        dismiss()
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                logger.log("ChargeSummaryView appeared for owner id: \(owner.id)")
                viewModel.load()
            }
        }
    }

    // MARK: – Formatting

    private func formatted(_ amount: Double) -> String {
      return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

#if DEBUG
import SwiftUI

struct ChargeSummaryView_Previews: PreviewProvider {
    static var owner: DogOwner = {
        let o = DogOwner.sample
        // insert a few sample charges
        o.charges = [
            Charge.sample(dateOffset: -2, amount: 40.0, method: .cash),
            Charge.sample(dateOffset: -1, amount: 60.0, method: .credit),
            Charge.sample(dateOffset: 0, amount: 80.0, method: .zelle)
        ]
        return o
    }()

    static var previews: some View {
        ChargeSummaryView(owner: owner)
            .environment(\.modelContext, PreviewContext.container.mainContext)
    }
}
#endif
