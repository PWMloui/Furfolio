//
//  OwnerLifetimeValueView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerLifetimeValueView: View {
    let ownerName: String
    let totalSpent: Double
    let appointmentCount: Int
    let lastVisit: Date?
    let isTopSpender: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ownerName)
                        .font(.title2.bold())
                    if isTopSpender {
                        Label("Top Spender", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(Color.yellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
                Text(totalSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.title)
                    .bold()
                    .foregroundStyle(.green)
            }
            HStack(spacing: 16) {
                VStack {
                    Text("\(appointmentCount)")
                        .font(.title2.bold())
                    Text("Visits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                VStack {
                    if let last = lastVisit {
                        Text(last, style: .date)
                            .font(.title3.bold())
                        Text("Last Visit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.title3.bold())
                        Text("Last Visit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    OwnerLifetimeValueView(
        ownerName: "Jane Doe",
        totalSpent: 1525.50,
        appointmentCount: 16,
        lastVisit: Date().addingTimeInterval(-86400 * 14),
        isTopSpender: true
    )
}
