//
//  OwnerActivityTimelineView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerActivityEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let description: String?
    let icon: String
    let color: Color
}

struct OwnerActivityTimelineView: View {
    let events: [OwnerActivityEvent]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if events.isEmpty {
                    ContentUnavailableView("No activity found.", systemImage: "clock.arrow.circlepath")
                        .padding(.top, 32)
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 16) {
                            VStack {
                                // Timeline marker
                                Circle()
                                    .fill(event.color)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: event.icon)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                if index < events.count - 1 {
                                    Rectangle()
                                        .fill(event.color.opacity(0.25))
                                        .frame(width: 4, height: 44)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                if let desc = event.description {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(event.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .navigationTitle("Owner Activity")
        .background(Color(.systemGroupedBackground))
    }
}

#if DEBUG
struct OwnerActivityTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerActivityTimelineView(
            events: [
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 3), title: "Appointment Booked", description: "Full Groom for Bella", icon: "calendar.badge.plus", color: .blue),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 2), title: "Payment Received", description: "Charge for Max - $85", icon: "dollarsign.circle.fill", color: .green),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 7), title: "Owner Info Updated", description: "Changed address", icon: "pencil.circle.fill", color: .orange)
            ]
        )
    }
}
#endif
