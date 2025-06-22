//
//  RevenueGoalProgressView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct RevenueGoalProgressView: View {
    var currentRevenue: Double
    var goalRevenue: Double
    var label: String?

    private var progress: Double {
        guard goalRevenue > 0 else { return 0 }
        return min(currentRevenue / goalRevenue, 1.0)
    }

    private var progressColor: Color {
        switch progress {
        case 0.75...1.0:
            return .green
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }

    private var formattedCurrentRevenue: String {
        CurrencyFormatter.shared.string(from: currentRevenue)
    }

    private var formattedGoalRevenue: String {
        CurrencyFormatter.shared.string(from: goalRevenue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.headline)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 22)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 22)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 22)

            HStack {
                Text(formattedCurrentRevenue)
                    .font(.subheadline).bold()
                Spacer()
                Text("Goal: \(formattedGoalRevenue)")
                    .font(.subheadline)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let labelText = label ?? "Revenue progress"
        return "\(labelText), \(formattedCurrentRevenue) out of \(formattedGoalRevenue)"
    }
}

// Shared currency formatter
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private let formatter: NumberFormatter

    private init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
    }

    func string(from value: Double) -> String {
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#if DEBUG
struct RevenueGoalProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            RevenueGoalProgressView(currentRevenue: 7500, goalRevenue: 10000, label: "Monthly Revenue")
            RevenueGoalProgressView(currentRevenue: 4000, goalRevenue: 10000, label: "Monthly Revenue")
            RevenueGoalProgressView(currentRevenue: 2000, goalRevenue: 10000, label: "Monthly Revenue")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
