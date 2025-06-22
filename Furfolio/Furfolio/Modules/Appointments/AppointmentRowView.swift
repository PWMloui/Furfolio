//
//  AppointmentRowView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - AppointmentRowView (Tokenized, Modular, Auditable Appointment Row UI)

import SwiftUI

/// A modular, tokenized, and auditable view for displaying appointment details.
/// This view supports business workflows, accessibility, localization, and UI design system integration.
/// It leverages design tokens for colors, fonts, and spacing to ensure consistency and maintainability across the app.
struct AppointmentRowView: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.accent.opacity(0.15)) // Tokenized accent color with opacity for background circle
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(AppFonts.headline) // Tokenized headline font for initials
                        .foregroundColor(AppColors.accent) // Tokenized accent color for initials
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.dog?.name ?? "Unknown Dog")
                    .font(AppFonts.headline) // Tokenized headline font for dog name
                Text(appointment.owner?.ownerName ?? "Unknown Owner")
                    .font(AppFonts.subheadline) // Tokenized subheadline font for owner name
                    .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color
                Text(appointment.serviceType)
                    .font(AppFonts.subheadline) // Tokenized subheadline font for service type
                    .foregroundColor(AppColors.info) // Tokenized info color for service type
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(AppFonts.subheadline) // Tokenized subheadline font for date
                if appointment.hasConflict {
                    Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                        .font(AppFonts.caption) // Tokenized caption font for conflict label
                        .foregroundColor(AppColors.critical) // Tokenized critical color for conflict warning
                        .accessibilityLabel("Scheduling conflict")
                }
            }
        }
        .padding(.vertical, AppSpacing.small) // Tokenized vertical padding
        .accessibilityElement(children: .combine)
        .accessibilityHint("Appointment with \(appointment.owner?.ownerName ?? "owner") for dog \(appointment.dog?.name ?? "dog") on \(formattedDate)")
    }

    private var initials: String {
        let dogName = appointment.dog?.name ?? ""
        let components = dogName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined()
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: appointment.date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Demo / Business / Tokenized Preview

#if DEBUG
struct AppointmentRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppointmentRowView(appointment: Appointment(
                id: UUID(),
                date: Date(),
                dog: Dog(id: UUID(), name: String(localized: LocalizedStringKey("Bella"))),
                owner: DogOwner(id: UUID(), ownerName: String(localized: LocalizedStringKey("Jane Doe"))),
                serviceType: String(localized: LocalizedStringKey("Full Groom")),
                hasConflict: true
            ))
            .previewLayout(.sizeThatFits)

            AppointmentRowView(appointment: Appointment(
                id: UUID(),
                date: Date(),
                dog: Dog(id: UUID(), name: String(localized: LocalizedStringKey("Charlie"))),
                owner: DogOwner(id: UUID(), ownerName: String(localized: LocalizedStringKey("John Smith"))),
                serviceType: String(localized: LocalizedStringKey("Bath Only")),
                hasConflict: false
            ))
            .previewLayout(.sizeThatFits)
        }
        .padding()
    }
}
#endif

// Note: Placeholder models removed. Real models should be imported from the model layer.
