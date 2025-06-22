
//
//  ActionableInsightsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ActionableInsightsView: View {
    let upcomingAppointments: Int = 5
    let totalRevenue: Double = 3450.75
    let inactiveCustomers: Int = 3
    let loyaltyProgress: Double = 0.65

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actionable Insights")
                .font(.title2.bold())
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 16) {
                InsightCard(
                    title: "Upcoming Appointments",
                    value: "\(upcomingAppointments)",
                    systemImage: "calendar",
                    color: .blue,
                    accessibilityLabel: "\(upcomingAppointments) upcoming appointments"
                )

                InsightCard(
                    title: "Total Revenue",
                    value: currencyFormatter.string(from: NSNumber(value: totalRevenue)) ?? "$0",
                    systemImage: "dollarsign.circle",
                    color: .green,
                    accessibilityLabel: "Total revenue \(currencyFormatter.string(from: NSNumber(value: totalRevenue)) ?? "$0")"
                )
            }

            HStack(spacing: 16) {
                InsightCard(
                    title: "Inactive Customers",
                    value: "\(inactiveCustomers)",
                    systemImage: "person.fill.xmark",
                    color: .red,
                    accessibilityLabel: "\(inactiveCustomers) inactive customers"
                )

                LoyaltyProgressCard(progress: loyaltyProgress)
            }
        }
        .padding()
    }
}

private struct InsightCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundColor(color)
            Text(value)
                .font(.title)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct LoyaltyProgressCard: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.yellow)
            Text("\(Int(progress * 100))%")
                .font(.title)
                .bold()
                .foregroundColor(.yellow)
            Text("Loyalty Progress")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.yellow.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement()
        .accessibilityLabel("Loyalty program progress \(Int(progress * 100)) percent")
    }
}

#if DEBUG
struct ActionableInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        ActionableInsightsView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
