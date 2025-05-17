
//  ChargeSummaryView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 2, 2025 — added totals, averages, grouping by payment method, empty state.
//

import SwiftUI
import SwiftData

// TODO: Move summary logic and formatting into a dedicated ViewModel; use a shared NumberFormatter for performance.

@MainActor
/// Displays a summary and history of charges for a specific DogOwner, with totals and breakdowns.
struct ChargeSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let owner: DogOwner

    /// Shared currency formatter to avoid repeated allocations.
    private static let currencyFormatter: NumberFormatter = {
      let fmt = NumberFormatter()
      fmt.numberStyle = .currency
      fmt.locale = .current
      return fmt
    }()

    /// All charges for the owner, sorted newest first.
    private var charges: [Charge] {
      owner.charges.sorted { $0.date > $1.date }
    }

    /// Sum of all charge amounts.
    private var totalAmount: Double {
      charges.reduce(0) { $0 + $1.amount }
    }

    /// Average charge amount, or zero if no charges.
    private var averageAmount: Double {
      guard !charges.isEmpty else { return 0 }
      return totalAmount / Double(charges.count)
    }

    /// Number of charges grouped by payment method.
    private var paymentBreakdown: [Charge.PaymentMethod: Int] {
      Dictionary(
        grouping: charges,
        by: \.paymentMethod
      ).mapValues(\.count)
    }

    var body: some View {
        NavigationStack {
            List {
                // Header with totals
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Charged: \(formatted(totalAmount))")
                            .font(.headline)
                        Text("Average: \(formatted(averageAmount))")
                            .font(.subheadline)
                        HStack {
                            ForEach(Charge.PaymentMethod.allCases) { method in
                                if let count = paymentBreakdown[method], count > 0 {
                                    Text("\(method.symbol) \(count)")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
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
                if charges.isEmpty {
                    Section {
                        Text("No charges recorded yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(header: Text("Charge History")) {
                        ForEach(charges) { charge in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(charge.formattedDate)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(charge.formattedAmount)
                                        .font(.body)
                                        .bold()
                                    if let notes = charge.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(charge.paymentMethod.localized)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Charges for \(owner.dogName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: – Actions

    /// Deletes selected charges from the context.
    private func delete(at offsets: IndexSet) {
      for idx in offsets {
        let toDelete = charges[idx]
        context.delete(toDelete)
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
