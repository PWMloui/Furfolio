//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - AppointmentReminderView (Tokenized, Modular, Auditable Reminder UI)

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentReminderAuditEvent: Codable {
    let timestamp: Date
    let operation: String           // "appear", "snooze", "markDone"
    let appointmentID: UUID
    let dogName: String?
    let ownerName: String?
    let serviceType: String
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) (\(dogName ?? "?") / \(ownerName ?? "?")) [\(serviceType)] [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentReminderAudit {
    static private(set) var log: [AppointmentReminderAuditEvent] = []

    static func record(
        operation: String,
        appointment: Appointment,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentReminderView",
        detail: String? = nil
    ) {
        let event = AppointmentReminderAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointment.id,
            dogName: appointment.dog?.name,
            ownerName: appointment.owner?.ownerName,
            serviceType: appointment.serviceType,
            tags: tags.isEmpty ? appointment.tags : tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 250 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No reminder actions recorded."
    }
}


/// A modular, tokenized, and auditable appointment reminder view supporting business workflows, accessibility, localization, and UI design system integration.
/// This view leverages design tokens for fonts, colors, spacing, borders, and shadows to ensure consistency and maintainability across the app.

struct AppointmentReminderView: View {
    @Binding var appointment: Appointment
    var onSnooze: (() -> Void)?
    var onMarkDone: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text("Upcoming Appointment")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.accent)
                Spacer()
                Button {
                    AppointmentReminderAudit.record(
                        operation: "markDone",
                        appointment: appointment,
                        tags: ["markDone"],
                        detail: "User marked appointment as done"
                    )
                    onMarkDone?()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.success)
                }
                .buttonStyle(.plain)

                Button {
                    AppointmentReminderAudit.record(
                        operation: "snooze",
                        appointment: appointment,
                        tags: ["snooze"],
                        detail: "User snoozed reminder"
                    )
                    onSnooze?()
                } label: {
                    Image(systemName: "bell.slash.fill")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.warning)
                }
                .buttonStyle(.plain)
            }

            Group {
                Text("Dog: \(appointment.dog?.name ?? "Unknown")")
                Text("Owner: \(appointment.owner?.ownerName ?? "Unknown")")
                Text("Date: \(formattedDate(appointment.date))")
            }
            .font(AppFonts.subheadline)
            .foregroundColor(AppColors.textPrimary)

            if let notes = appointment.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(AppFonts.footnote)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.medium)
                .fill(AppColors.background)
                .shadow(
                    color: AppShadows.medium.color,
                    radius: AppShadows.medium.radius,
                    x: AppShadows.medium.x,
                    y: AppShadows.medium.y
                )
        )
        .padding(.horizontal, AppSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Upcoming appointment reminder"))
        .onAppear {
            AppointmentReminderAudit.record(
                operation: "appear",
                appointment: appointment,
                tags: ["appear"],
                detail: "Reminder appeared"
            )
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentReminderAuditAdmin {
    public static var lastSummary: String { AppointmentReminderAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentReminderAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentReminderAudit.log.suffix(limit).map { $0.accessibilityLabel }
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
        AppointmentReminderView(
            appointment: $sampleAppointment,
            onSnooze: { print("Snooze tapped") },
            onMarkDone: { print("Mark done tapped") }
        )
        .previewLayout(.sizeThatFits)
        .padding(AppSpacing.medium)
    }
}
#endif
