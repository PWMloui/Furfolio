//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - AppointmentReminderView (Tokenized, Modular, Auditable Reminder UI)

import SwiftUI

/// A modular, tokenized, and auditable appointment reminder view supporting business workflows, accessibility, localization, and UI design system integration.
/// This view leverages design tokens for fonts, colors, spacing, borders, and shadows to ensure consistency and maintainability across the app.
struct AppointmentReminderView: View {
    @Binding var appointment: Appointment
    var onSnooze: (() -> Void)?
    var onMarkDone: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) { // Replaced hardcoded spacing with design token
            HStack {
                Text("Upcoming Appointment")
                    .font(AppFonts.headline) // Replaced .headline with AppFonts.headline token
                    .foregroundColor(AppColors.accent) // Replaced .accentColor with AppColors.accent token
                Spacer()
                Button {
                    onMarkDone?()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFonts.title2) // Replaced .title2 with AppFonts.title2 token
                        .foregroundColor(AppColors.success) // Replaced .green with AppColors.success token
                }
                .buttonStyle(.plain)

                Button {
                    onSnooze?()
                } label: {
                    Image(systemName: "bell.slash.fill")
                        .font(AppFonts.title2) // Replaced .title2 with AppFonts.title2 token
                        .foregroundColor(AppColors.warning) // Replaced .orange with AppColors.warning token
                }
                .buttonStyle(.plain)
            }

            Group {
                Text("Dog: \(appointment.dog?.name ?? "Unknown")")
                Text("Owner: \(appointment.owner?.ownerName ?? "Unknown")")
                Text("Date: \(formattedDate(appointment.date))")
            }
            .font(AppFonts.subheadline) // Replaced .subheadline with AppFonts.subheadline token
            .foregroundColor(AppColors.textPrimary) // Replaced .primary with AppColors.textPrimary token

            if let notes = appointment.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(AppFonts.footnote) // Replaced .footnote with AppFonts.footnote token
                    .foregroundColor(AppColors.secondaryText) // Replaced .secondary with AppColors.secondaryText token
                    .lineLimit(3)
            }
        }
        .padding(AppSpacing.medium) // Replaced hardcoded padding with design token
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.medium) // Replaced fixed cornerRadius with BorderRadius.medium token
                .fill(AppColors.background) // Replaced Color(.systemBackground) with AppColors.background token
                .shadow(
                    color: AppShadows.medium.color,
                    radius: AppShadows.medium.radius,
                    x: AppShadows.medium.x,
                    y: AppShadows.medium.y
                ) // Replaced fixed shadow with AppShadows.medium token for consistency
        )
        .padding(.horizontal, AppSpacing.medium) // Replaced hardcoded horizontal padding with design token
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Upcoming appointment reminder"))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct AppointmentReminderView_Previews: PreviewProvider {
    @State static var sampleAppointment = Appointment(
        id: UUID(),
        date: Date().addingTimeInterval(3600),
        dog: Dog(id: UUID(), name: "Bella", birthDate: Date()),
        owner: DogOwner(id: UUID(), ownerName: "Jane Doe"),
        serviceType: "Full Groom",
        duration: 90,
        tags: ["VIP"],
        notes: "Prefers gentle shampoo.",
        behaviorLog: [],
        hasConflict: false,
        conflictMessage: nil
    )

    static var previews: some View {
        // Demo / Business / Tokenized preview demonstrating design tokens in use
        AppointmentReminderView(
            appointment: $sampleAppointment,
            onSnooze: { print("Snooze tapped") },
            onMarkDone: { print("Mark done tapped") }
        )
        .previewLayout(.sizeThatFits)
        .padding(AppSpacing.medium) // Replaced hardcoded padding with design token
    }
}
#endif
