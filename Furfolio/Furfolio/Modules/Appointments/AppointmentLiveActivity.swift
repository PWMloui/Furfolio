//
//  AppointmentLiveActivity.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Live Activity with Compliance Logging
//

import Foundation
import ActivityKit
import SwiftUI
import UIKit

// MARK: - Audit/Event Logging

fileprivate struct AppointmentLiveActivityAuditEvent: Codable {
    let timestamp: Date
    let operation: String         // "start", "update", "end", "fail"
    let appointmentID: UUID
    let status: String?
    let minutesRemaining: Int?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) \(status ?? "") \(minutesRemaining ?? -1)min [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentLiveActivityAudit {
    static private(set) var log: [AppointmentLiveActivityAuditEvent] = []

    static func record(
        operation: String,
        appointmentID: UUID,
        status: String? = nil,
        minutesRemaining: Int? = nil,
        tags: [String] = [],
        actor: String? = "system",
        context: String? = "AppointmentLiveActivity",
        detail: String? = nil
    ) {
        let event = AppointmentLiveActivityAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            status: status,
            minutesRemaining: minutesRemaining,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 300 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No live activity events recorded."
    }
    
    /// Exports all audit events as a CSV string (with headers).
    static func exportAllCSV() -> String {
        var csv = "timestamp,operation,appointmentID,status,minutesRemaining,tags,actor,context,detail\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let ts = dateFormatter.string(from: event.timestamp)
            let op = event.operation
            let id = event.appointmentID.uuidString
            let status = event.status ?? ""
            let minRem = event.minutesRemaining.map { "\($0)" } ?? ""
            let tags = event.tags.joined(separator: "|")
            let actor = event.actor ?? ""
            let context = event.context ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let detailEscaped = "\"\(detail)\""
            csv += "\(ts),\(op),\(id),\(status),\(minRem),\(tags),\(actor),\(context),\(detailEscaped)\n"
        }
        return csv
    }
}

// MARK: - AppointmentLiveActivityAttributes

struct AppointmentLiveActivityAttributes: ActivityAttributes {
    // Dynamic state of the live activity.
    public struct ContentState: Codable, Hashable {
        var status: Status
        var minutesRemaining: Int?

        var isStartingSoon: Bool {
            if let min = minutesRemaining {
                return min <= 10
            }
            return false
        }
    }

    enum Status: String, Codable, CaseIterable {
        case upcoming, inProgress, completed, cancelled

        var label: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }

        var color: Color {
            switch self {
            case .upcoming: return AppColors.info
            case .inProgress: return AppColors.success
            case .completed: return AppColors.secondaryText
            case .cancelled: return AppColors.critical
            }
        }

        var iconName: String {
            switch self {
            case .upcoming: return "clock"
            case .inProgress: return "scissors"
            case .completed: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            }
        }
    }

    // Static appointment properties.
    var appointmentID: UUID
    var serviceType: String
    var dogName: String
    var ownerName: String
    var appointmentDate: Date
}

// MARK: - AppointmentLiveActivityManager (Auditable Live Activity Management)

enum AppointmentLiveActivityManager {
    static func startOrUpdateActivity(
        for appointment: AppointmentLiveActivityAttributes,
        status: AppointmentLiveActivityAttributes.Status,
        minutesRemaining: Int?
    ) {
        let state = AppointmentLiveActivityAttributes.ContentState(
            status: status,
            minutesRemaining: minutesRemaining
        )
        let content = ActivityContent(state: state, staleDate: .distantFuture)

        Task {
            if let existingActivity = Activity<AppointmentLiveActivityAttributes>.activities.first(where: { $0.attributes.appointmentID == appointment.appointmentID }) {
                await existingActivity.update(content)
                AppointmentLiveActivityAudit.record(
                    operation: "update",
                    appointmentID: appointment.appointmentID,
                    status: status.rawValue,
                    minutesRemaining: minutesRemaining,
                    tags: ["update", status.rawValue]
                )
            } else {
                do {
                    try await Activity<AppointmentLiveActivityAttributes>.request(
                        attributes: appointment,
                        content: content
                    )
                    AppointmentLiveActivityAudit.record(
                        operation: "start",
                        appointmentID: appointment.appointmentID,
                        status: status.rawValue,
                        minutesRemaining: minutesRemaining,
                        tags: ["start", status.rawValue]
                    )
                } catch {
                    // Log error for audit/compliance
                    AppointmentLiveActivityAudit.record(
                        operation: "fail",
                        appointmentID: appointment.appointmentID,
                        status: status.rawValue,
                        minutesRemaining: minutesRemaining,
                        tags: ["fail", status.rawValue],
                        detail: error.localizedDescription
                    )
                    print("Failed to start live activity: \(error.localizedDescription)")
                }
            }
        }
    }

    static func endActivity(for appointmentID: UUID) {
        Task {
            if let activity = Activity<AppointmentLiveActivityAttributes>.activities.first(where: { $0.attributes.appointmentID == appointmentID }) {
                await activity.end(dismissalPolicy: .immediate)
                AppointmentLiveActivityAudit.record(
                    operation: "end",
                    appointmentID: appointmentID,
                    tags: ["end"]
                )
            }
        }
    }
}

// MARK: - Live Activity View

@available(iOS 16.1, *)
struct AppointmentLiveActivityView: View {
    let context: ActivityViewContext<AppointmentLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: context.state.status.iconName)
                    .font(AppFonts.title2)
                    .foregroundColor(context.state.status.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.dogName)
                        .font(AppFonts.headline)
                        .lineLimit(1)
                    Text(context.attributes.serviceType)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(context.state.status.label)
                    .font(AppFonts.subheadline)
                    .foregroundColor(context.state.status.color)
            }

            if let minutes = context.state.minutesRemaining, context.state.status == .upcoming {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .foregroundColor(AppColors.info)
                    Text("Starts in \(minutes) min")
                        .fontWeight(minutes <= 10 ? .bold : .regular)
                        .foregroundColor(minutes <= 10 ? AppColors.warning : AppColors.textPrimary)
                }
                .padding(.vertical, 2)
            }

            if context.state.status == .inProgress {
                Text("Appointment in progress...")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(AppSpacing.medium)
        .activityBackgroundTint(AppColors.background)
        .activitySystemActionForegroundColor(context.state.status.color)
        // --- Accessibility enhancements ---
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "Appointment status: \(context.state.status.label), \(context.state.minutesRemaining ?? 0) minutes remaining")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.attributes.dogName), \(context.attributes.serviceType)")
        .accessibilityValue("\(context.state.status.label), \(context.state.minutesRemaining ?? 0) minutes remaining")
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentLiveActivityAuditAdmin {
    public static var lastSummary: String { AppointmentLiveActivityAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentLiveActivityAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentLiveActivityAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Export all audit events as CSV string.
    public static func exportCSV() -> String { AppointmentLiveActivityAudit.exportAllCSV() }
    /// For analytics/testing: get all events as readable strings.
    public static func allEvents() -> [String] {
        AppointmentLiveActivityAudit.log.map { $0.accessibilityLabel }
    }
}

// MARK: - DEV Audit Preview Utility

#if DEBUG
struct AppointmentLiveActivityAuditPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Live Activity Audits").bold()
            ForEach(AppointmentLiveActivityAuditAdmin.recentEvents(limit: 5), id: \.self) { entry in
                Text(entry)
                    .font(.caption)
                    .padding(.vertical, 2)
            }
        }
        .padding()
    }
}
#endif
