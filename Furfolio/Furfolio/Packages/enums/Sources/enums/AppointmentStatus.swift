//
//  AppointmentStatus.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Represents the status of an appointment.
enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case completed
    case cancelled
    case noShow
    case rescheduled

    var id: String { rawValue }

    /// Human-readable name for display.
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        }
    }

    /// SF Symbol icon name for each status.
    var iconName: String {
        switch self {
        case .scheduled: return "calendar"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .noShow: return "exclamationmark.triangle"
        case .rescheduled: return "arrow.uturn.right"
        }
    }

    /// Color (as string or Color, depending on use) for status.
    var colorName: String {
        switch self {
        case .scheduled: return "accentColor"
        case .completed: return "green"
        case .cancelled: return "red"
        case .noShow: return "orange"
        case .rescheduled: return "blue"
        }
    }
}
