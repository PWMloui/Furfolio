//
//  DashboardSummaryRow.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DashboardSummaryRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(valueColor)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

#if DEBUG
struct DashboardSummaryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardSummaryRow(
                iconName: "chart.bar.fill",
                iconColor: .blue,
                title: "Total Revenue",
                value: "$12,345",
                valueColor: .green
            )
            .previewLayout(.sizeThatFits)
            .padding()

            DashboardSummaryRow(
                iconName: "calendar",
                iconColor: .orange,
                title: "Upcoming Appointments",
                value: "5",
                valueColor: .primary
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif
