//
//  AppointmentRowView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Appointment Row UI
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentRowAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "appear", "tap"
    let appointmentID: UUID
    let dogName: String
    let ownerName: String
    let serviceType: String
    let hasConflict: Bool
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) (\(dogName)/\(ownerName)) [\(serviceType)]\(hasConflict ? " [conflict]" : "") [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentRowAudit {
    static private(set) var log: [AppointmentRowAuditEvent] = []

    static func record(
        operation: String,
        appointment: Appointment,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentRowView",
        detail: String? = nil
    ) {
        let event = AppointmentRowAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointment.id,
            dogName: appointment.dog?.name ?? "Unknown Dog",
            ownerName: appointment.owner?.ownerName ?? "Unknown Owner",
            serviceType: appointment.serviceType,
            hasConflict: appointment.hasConflict,
            tags: tags,
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
        log.last?.accessibilityLabel ?? "No row actions recorded."
    }
}

// MARK: - AppointmentRowView (Tokenized, Modular, Auditable Appointment Row UI)

struct AppointmentRowView: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.dog?.name ?? "Unknown Dog")
                    .font(AppFonts.headline)
                Text(appointment.owner?.ownerName ?? "Unknown Owner")
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                Text(appointment.serviceType)
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.info)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(AppFonts.subheadline)
                if appointment.hasConflict {
                    Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.critical)
                        .accessibilityLabel("Scheduling conflict")
                }
            }
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Appointment with \(appointment.owner?.ownerName ?? "owner") for dog \(appointment.dog?.name ?? "dog") on \(formattedDate)")
        .contentShape(Rectangle())
        .onTapGesture {
            AppointmentRowAudit.record(
                operation: "tap",
                appointment: appointment,
                tags: appointment.hasConflict ? ["tap", "conflict"] : ["tap"]
            )
        }
        .onAppear {
            AppointmentRowAudit.record(
                operation: "appear",
                appointment: appointment,
                tags: appointment.hasConflict ? ["appear", "conflict"] : ["appear"]
            )
        }
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

// MARK: - Audit/Admin Accessors

public enum AppointmentRowAuditAdmin {
    public static var lastSummary: String { AppointmentRowAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentRowAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentRowAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

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
