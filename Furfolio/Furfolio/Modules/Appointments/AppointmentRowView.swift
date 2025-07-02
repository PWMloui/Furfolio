//
//  AppointmentRowView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Appointment Row UI
//

import SwiftUI
import Combine
import UIKit

// MARK: - Audit/Event Logging

fileprivate struct AppointmentRowAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "appear", "tap", "markNoShow", "copy"
    let appointmentID: UUID
    let dogName: String
    let ownerName: String
    let serviceType: String
    let hasConflict: Bool
    let conflictType: String
    let status: String
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) (\(dogName)/\(ownerName)) [\(serviceType)]\(hasConflict ? " [\(conflictType)]" : "") [\(tags.joined(separator: ","))] [Status: \(status)] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
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
            conflictType: appointment.conflictType ?? "Conflict",
            status: appointment.status ?? "Scheduled",
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

    /// Exports all audit logs as CSV string with headers:
    /// timestamp,operation,appointmentID,dogName,ownerName,serviceType,conflictType,status,tags,actor,context,detail
    static func exportCSV() -> String {
        let headers = [
            "timestamp", "operation", "appointmentID", "dogName", "ownerName",
            "serviceType", "conflictType", "status", "tags", "actor", "context", "detail"
        ]
        var csvRows = [headers.joined(separator: ",")]
        let formatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = formatter.string(from: event.timestamp)
            let operation = event.operation
            let appointmentID = event.appointmentID.uuidString
            let dogName = event.dogName.csvEscaped()
            let ownerName = event.ownerName.csvEscaped()
            let serviceType = event.serviceType.csvEscaped()
            let conflictType = event.conflictType.csvEscaped()
            let status = event.status.csvEscaped()
            let tags = event.tags.joined(separator: ";").csvEscaped()
            let actor = (event.actor ?? "").csvEscaped()
            let context = (event.context ?? "").csvEscaped()
            let detail = (event.detail ?? "").csvEscaped()
            let row = [
                timestamp, operation, appointmentID, dogName, ownerName,
                serviceType, conflictType, status, tags, actor, context, detail
            ].joined(separator: ",")
            csvRows.append(row)
        }
        return csvRows.joined(separator: "\n")
    }
}

fileprivate extension String {
    /// Escapes commas, quotes and newlines for CSV format
    func csvEscaped() -> String {
        if self.contains(",") || self.contains("\"") || self.contains("\n") {
            let escaped = self.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return self
        }
    }
}

// MARK: - AppointmentRowView (Tokenized, Modular, Auditable Appointment Row UI)

struct AppointmentRowView: View {
    let appointment: Appointment

    // Optional callbacks for quick actions
    var onViewDetails: (() -> Void)? = nil
    var onMarkNoShow: (() -> Void)? = nil

    // State for animation pulse
    @State private var animatePulse = false

    // Publisher for accessibility announcements
    private let accessibilityAnnouncement = PassthroughSubject<String, Never>()

    var body: some View {
        // Main row container with pulse animation if conflict exists
        HStack(spacing: 12) {
            // MARK: - Conflict indicator chip at far left
            if appointment.hasConflict {
                Text(appointment.conflictType ?? "Conflict")
                    .font(AppFonts.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.critical.opacity(0.2))
                    .foregroundColor(AppColors.critical)
                    .clipShape(Capsule())
                    .accessibilityLabel("Conflict type: \(appointment.conflictType ?? "Conflict")")
            }

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

            // MARK: - Appointment status badge at top right
            statusBadge
                .alignmentGuide(.top) { d in d[.top] }
                .alignmentGuide(.trailing) { d in d[.trailing] }
        }
        .padding(.vertical, AppSpacing.small)
        .padding(.horizontal, 8)
        // MARK: - Animate pulse background if conflict and visible
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.accent.opacity(animatePulse && appointment.hasConflict ? 0.1 : 0))
                .animation(
                    appointment.hasConflict ?
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                    value: animatePulse
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // MARK: - Accessibility modifiers including conflict and status announcements
        .accessibilityElement(children: .combine)
        .accessibilityHint("Appointment with \(appointment.owner?.ownerName ?? "owner") for dog \(appointment.dog?.name ?? "dog") on \(formattedDate). Status: \(appointment.status ?? "Scheduled").\(appointment.hasConflict ? " There is a scheduling conflict: \(appointment.conflictType ?? "Conflict")." : "")")
        .accessibilityAddTraits(appointment.hasConflict ? .isSelected : [])
        // MARK: - Context menu for quick actions on long press
        .contextMenu {
            Button("View Details") {
                onViewDetails?()
            }
            Button("Mark as No-Show") {
                onMarkNoShow?()
                AppointmentRowAudit.record(operation: "markNoShow", appointment: appointment, tags: ["contextMenu"])
                // Announce status change for accessibility
                accessibilityAnnouncement.send("Marked as No-Show")
            }
            Button("Copy Appointment Info") {
                copyAppointmentInfoToClipboard()
                AppointmentRowAudit.record(operation: "copy", appointment: appointment, tags: ["contextMenu"])
                accessibilityAnnouncement.send("Appointment information copied to clipboard")
            }
        }
        // MARK: - Tap gesture with audit and accessibility announcement
        .onTapGesture {
            AppointmentRowAudit.record(
                operation: "tap",
                appointment: appointment,
                tags: appointment.hasConflict ? ["tap", "conflict"] : ["tap"]
            )
            if appointment.hasConflict {
                accessibilityAnnouncement.send("Scheduling conflict: \(appointment.conflictType ?? "Conflict")")
            }
            accessibilityAnnouncement.send("Status: \(appointment.status ?? "Scheduled")")
        }
        // MARK: - On appear audit record and start pulse animation if conflict
        .onAppear {
            AppointmentRowAudit.record(
                operation: "appear",
                appointment: appointment,
                tags: appointment.hasConflict ? ["appear", "conflict"] : ["appear"]
            )
            if appointment.hasConflict {
                accessibilityAnnouncement.send("Scheduling conflict: \(appointment.conflictType ?? "Conflict")")
            }
            accessibilityAnnouncement.send("Status: \(appointment.status ?? "Scheduled")")
            animatePulse = appointment.hasConflict
        }
        // Accessibility announcements publisher
        .onReceive(accessibilityAnnouncement) { announcement in
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    /// Computes initials from dog's name (up to two initials)
    private var initials: String {
        let dogName = appointment.dog?.name ?? ""
        let components = dogName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined()
    }

    /// Formats appointment date using static formatter
    private var formattedDate: String {
        Self.dateFormatter.string(from: appointment.date)
    }

    /// Provides a badge view with status text and color coding
    private var statusBadge: some View {
        let status = appointment.status ?? "Scheduled"
        let color: Color = {
            switch status {
            case "Scheduled": return AppColors.accent
            case "In Progress": return AppColors.info
            case "Completed": return AppColors.secondaryText
            case "No-Show": return AppColors.critical
            default: return AppColors.accent
            }
        }()
        return Text(status)
            .font(AppFonts.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
            .accessibilityLabel("Status: \(status)")
            .padding(.top, 4)
            .padding(.trailing, 4)
    }

    /// Copies formatted appointment info to clipboard
    private func copyAppointmentInfoToClipboard() {
        let dogName = appointment.dog?.name ?? "Unknown Dog"
        let ownerName = appointment.owner?.ownerName ?? "Unknown Owner"
        let service = appointment.serviceType
        let time = formattedDate
        let info = """
        Appointment Info:
        Dog: \(dogName)
        Owner: \(ownerName)
        Service: \(service)
        Time: \(time)
        """
        UIPasteboard.general.string = info
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
    /// Exports all audit logs as CSV string with headers
    public static func exportCSV() -> String {
        AppointmentRowAudit.exportCSV()
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
                hasConflict: true,
                conflictType: "Overlap",
                status: "Scheduled"
            ))
            .previewLayout(.sizeThatFits)

            AppointmentRowView(appointment: Appointment(
                id: UUID(),
                date: Date(),
                dog: Dog(id: UUID(), name: String(localized: LocalizedStringKey("Charlie"))),
                owner: DogOwner(id: UUID(), ownerName: String(localized: LocalizedStringKey("John Smith"))),
                serviceType: String(localized: LocalizedStringKey("Bath Only")),
                hasConflict: false,
                conflictType: nil,
                status: "Completed"
            ))
            .previewLayout(.sizeThatFits)
        }
        .padding()
    }
}
#endif
// Note: Placeholder models removed. Real models should be imported from the model layer.
