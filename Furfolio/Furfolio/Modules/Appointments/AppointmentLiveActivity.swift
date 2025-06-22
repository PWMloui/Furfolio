//
//  AppointmentLiveActivity.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import ActivityKit
import SwiftUI

// MARK: - AppointmentLiveActivityAttributes (Tokenized, Modular, Auditable Live Activity Attributes)

/// Defines the appointment live activity for lock screen and Dynamic Island.
/// This struct represents tokenized, modular, and auditable live activity attributes for appointment tracking.
/// Supports audit trails, business analytics, localization, accessibility, and UI token integration.
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

    /// Appointment status enumeration with UI properties.
    enum Status: String, Codable, CaseIterable {
        /// The appointment is scheduled and upcoming.
        /// Used in business logic to trigger reminders and audit logs for upcoming events.
        /// UI displays a clock icon and info color to indicate pending status.
        case upcoming
        /// The appointment is currently in progress.
        /// Important for audit trails to track active sessions and business analytics on service duration.
        /// UI shows a scissors icon and success color to indicate active service.
        case inProgress
        /// The appointment has been completed successfully.
        /// Critical for business reporting and audit confirmation of service fulfillment.
        /// UI uses a checkmark icon and secondaryText color for completed state.
        case completed
        /// The appointment has been cancelled.
        /// Essential for audit logs and business analytics on cancellations.
        /// UI displays an xmark icon and critical color to highlight cancellation.
        case cancelled

        var label: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }

        var color: Color {
            // Replaced hardcoded colors with AppColors tokens for consistency, theming, and accessibility.
            switch self {
            case .upcoming: return AppColors.info
            case .inProgress: return AppColors.success
            case .completed: return AppColors.secondaryText
            case .cancelled: return AppColors.critical
            }
        }

        var iconName: String {
            // TODO: Replace with tokenized icon names when available.
            switch self {
            case .upcoming: return "clock"          // Tokenize icon name for audit/UI consistency
            case .inProgress: return "scissors"     // Tokenize icon name for audit/UI consistency
            case .completed: return "checkmark.circle" // Tokenize icon name for audit/UI consistency
            case .cancelled: return "xmark.circle"  // Tokenize icon name for audit/UI consistency
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
    /// Start or update the live activity for an appointment.
    /// - Parameters:
    ///   - appointment: The static attributes representing the appointment.
    ///   - status: The current status of the appointment for dynamic updates.
    ///   - minutesRemaining: Optional minutes remaining until appointment start.
    /// This method supports audit by ensuring consistent state updates and business logic triggers.
    /// Errors during activity start are logged for debugging and operational monitoring.
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
            } else {
                do {
                    try await Activity<AppointmentLiveActivityAttributes>.request(
                        attributes: appointment,
                        content: content
                    )
                } catch {
                    // Log error for audit and operational awareness.
                    print("Failed to start live activity: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Ends the live activity for a specific appointment.
    /// - Parameter appointmentID: The unique identifier of the appointment to end.
    /// Ensures proper audit trail by explicitly ending live activities, supporting business logic cleanup.
    static func endActivity(for appointmentID: UUID) {
        Task {
            if let activity = Activity<AppointmentLiveActivityAttributes>.activities.first(where: { $0.attributes.appointmentID == appointmentID }) {
                await activity.end(dismissalPolicy: .immediate)
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
                    .font(AppFonts.title2) // Tokenized font for consistency and accessibility
                    .foregroundColor(context.state.status.color) // Tokenized color for theming and audit

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.dogName)
                        .font(AppFonts.headline) // Tokenized font for UI consistency
                        .lineLimit(1)

                    Text(context.attributes.serviceType)
                        .font(AppFonts.caption) // Tokenized font for UI consistency
                        .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color for accessibility
                        .lineLimit(1)
                }

                Spacer()

                Text(context.state.status.label)
                    .font(AppFonts.subheadline) // Tokenized font for UI consistency
                    .foregroundColor(context.state.status.color) // Tokenized color for theming
            }

            if let minutes = context.state.minutesRemaining, context.state.status == .upcoming {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .foregroundColor(AppColors.info) // Tokenized info color replacing .blue for consistency
                    Text("Starts in \(minutes) min")
                        .fontWeight(minutes <= 10 ? .bold : .regular)
                        .foregroundColor(minutes <= 10 ? AppColors.warning : AppColors.textPrimary) // Tokenized warning and primary text colors
                }
                .padding(.vertical, 2)
            }

            if context.state.status == .inProgress {
                Text("Appointment in progress...")
                    .font(AppFonts.callout) // Tokenized font for UI consistency
                    .foregroundColor(AppColors.success) // Tokenized success color replacing .green
            }
        }
        .padding(AppSpacing.medium) // Tokenized spacing for layout consistency
        .activityBackgroundTint(AppColors.background) // Tokenized background color for theming
        .activitySystemActionForegroundColor(context.state.status.color) // Tokenized color for system action foreground
    }
}
