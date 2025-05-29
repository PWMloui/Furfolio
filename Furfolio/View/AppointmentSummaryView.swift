//
//  AppointmentSummaryView.swift
//  Furfolio
//
//  Displays full details of a single appointment, including stats, photos, notes, and allows sharing.
//

import SwiftUI
import SwiftData
import UIKit
import os

@MainActor
/// Displays full details of a single appointment, including service info, photos, notes, and sharing options.
struct AppointmentSummaryView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentSummaryView")
    @Environment(\.dismiss) private var dismiss
    let appointment: Appointment

    // MARK: — Helpers

    private var owner: DogOwner { appointment.dogOwner }
    private var stats: ClientStats { ClientStats(owner: owner) }

    @State private var isSharePresented = false

    /// Items to share (text summary and optional photos).
    private var shareItems: [Any] {
        var items: [Any] = [shareText]
        if let data = appointment.beforePhoto, let img = UIImage(data: data) {
            items.append(img)
        }
        if let data = appointment.afterPhoto, let img = UIImage(data: data) {
            items.append(img)
        }
        return items
    }

    /// Text summary for sharing the appointment details.
    private var shareText: String {
        """
        Appointment Summary
        Date: \(appointment.formattedDate)
        Service: \(appointment.serviceType.localized)
        Duration: \(appointment.durationFormatted)
        Loyalty Reward: \(stats.loyaltyProgressTag)
        Behavior Trend: \(stats.recentBehaviorBadges.first ?? "None")
        Notes: \(appointment.notes ?? "None")
        """
    }

    // MARK: — Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Date & Service
                Text(appointment.formattedDate)
                    .font(AppTheme.title)
                HStack {
                    Text("Service:")
                        .font(AppTheme.body).fontWeight(.semibold)
                    Text(appointment.serviceType.localized)
                }

                // Duration
                if let _ = appointment.durationMinutes {
                    HStack {
                        Text("Duration:")
                            .font(AppTheme.body).fontWeight(.semibold)
                        Text(appointment.durationFormatted)
                    }
                }

                // Loyalty Reward
                if !stats.loyaltyProgressTag.isEmpty {
                    SectionBox(title: "Loyalty Reward", text: stats.loyaltyProgressTag, color: .green)
                }

                // Behavior Trend
                if let badge = stats.recentBehaviorBadges.first {
                    SectionBox(title: "Behavior Trend", text: badge, color: .orange)
                }

                // Estimated Duration (e.g., default for service type)
                if let est = appointment.estimatedDurationMinutes {
                    HStack {
                        Text("Estimated Duration:")
                            .font(AppTheme.body).fontWeight(.semibold)
                        Spacer()
                        Text("\(est) mins")
                            .foregroundColor(AppTheme.accent)
                    }
                }

                // Behavior Log Entries
                if !appointment.behaviorLog.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Behavior Log")
                            .font(AppTheme.title)
                        ForEach(appointment.behaviorLog.prefix(5), id: \.self) { entry in
                            Text("• \(entry)")
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(AppTheme.title)
                    if let notes = appointment.notes, !notes.isEmpty {
                        Text(notes)
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    } else {
                        Text("No notes provided.")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                // Before Photo
                if let data = appointment.beforePhoto, let image = UIImage(data: data) {
                    PhotoBox(title: "Before Photo", image: image)
                }

                // After Photo
                if let data = appointment.afterPhoto, let image = UIImage(data: data) {
                    PhotoBox(title: "After Photo", image: image)
                }
            }
            .padding()
        }
        .onAppear {
            logger.log("AppointmentSummaryView appeared for appointment id: \(appointment.id)")
        }
        .navigationTitle("Appointment Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    logger.log("Share button tapped for appointment id: \(appointment.id)")
                    isSharePresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share appointment")
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityView(activityItems: shareItems)
        }
    }
}

// MARK: — Subviews

private struct SectionBox: View {
    let title: String, text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            Text(text)
                .font(AppTheme.body)
                .padding(6)
                .background(color.opacity(0.1))
                .cornerRadius(AppTheme.cornerRadius)
                .foregroundColor(color)
        }
    }
}

private struct PhotoBox: View {
    let title: String, image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            Image(uiImage: image)
                .resizable()
                .accessibilityLabel(Text(title))
                .scaledToFit()
                .frame(maxWidth: 300)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: Color.black.opacity(0.2), radius: AppTheme.cornerRadius)
        }
    }
}

// MARK: — ActivityView for Sharing

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
