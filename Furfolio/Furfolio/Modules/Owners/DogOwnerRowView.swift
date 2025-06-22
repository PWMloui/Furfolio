//
//  DogOwnerRowView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.

import SwiftUI

struct DogOwnerRowView: View {
    let ownerName: String
    let phoneNumber: String?
    let email: String?
    let address: String?
    let dogCount: Int
    let upcomingAppointmentDate: Date?

    var body: some View {
        HStack(spacing: 12) {
            // Owner icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ownerName)
                        .font(.headline)
                        .lineLimit(1)
                    if dogCount > 1 {
                        Text("\(dogCount)")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(
                                Text("Dogs")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2),
                                alignment: .trailing
                            )
                    } else if dogCount == 1 {
                        Text("Dog")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .background(Color.secondary.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }

                if let nextDate = upcomingAppointmentDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(nextDate, style: .date)
                            .font(.caption)
                        Text(nextDate, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let phone = phoneNumber, !phone.isEmpty {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let email = email, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let addr = address, !addr.isEmpty {
                    Label(addr, systemImage: "map.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DogOwnerRowView(
        ownerName: "Jane Doe",
        phoneNumber: "555-987-6543",
        email: "jane@example.com",
        address: "321 Bark Ave",
        dogCount: 2,
        upcomingAppointmentDate: Date().addingTimeInterval(86400 * 2)
    )
}

