//
//  AppointmentSummaryView.swift
//  Furfolio
//
//  Displays full details of a single appointment, including photos, notes, and duration.

import SwiftUI

struct AppointmentSummaryView: View {
    let appointment: Appointment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(appointment.formattedDate)
                    .font(.title2)

                HStack {
                    Text("Service: ")
                        .fontWeight(.semibold)
                    Text(appointment.serviceType.localized)
                }

                if let duration = appointment.durationMinutes {
                    HStack {
                        Text("Duration:")
                            .fontWeight(.semibold)
                        Text("\(appointment.durationFormatted)")
                    }
                }

                if !appointment.dogOwner.loyaltyProgressTag.isEmpty {
                    let progress = appointment.dogOwner.loyaltyProgressTag
                    HStack {
                        Text("Loyalty Reward")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(progress)
                            .foregroundColor(.green)
                    }
                }

                if !appointment.dogOwner.behaviorTrendBadge.isEmpty {
                    let badge = appointment.dogOwner.behaviorTrendBadge
                    HStack {
                        Text("Behavior")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(badge)
                            .foregroundColor(.orange)
                    }
                }

                if let estimated = appointment.estimatedDurationMinutes {
                    HStack {
                        Text("Estimated Duration")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(estimated) mins")
                            .foregroundColor(.blue)
                    }
                }

                if !appointment.behaviorLog.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Behavior Log")
                            .font(.headline)
                        ForEach(appointment.behaviorLog.prefix(5), id: \.self) { entry in
                            Text("• \(entry)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.headline)
                    if let notes = appointment.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text("No notes provided.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                if let data = appointment.beforePhoto, let image = UIImage(data: data) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Before Photo")
                            .font(.headline)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                    }
                }

                if let data = appointment.afterPhoto, let image = UIImage(data: data) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("After Photo")
                            .font(.headline)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Appointment Summary")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Add share/export functionality here if desired.
                    print("Export or share appointment.")
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share appointment")
            }
        }
    }
}
