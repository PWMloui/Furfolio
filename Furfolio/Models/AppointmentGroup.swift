//
//  AppointmentGroup.swift
//  Furfolio
//
//  Provides utilities to group appointments by date, weekday, or month-year.

import Foundation

struct AppointmentGroup {

    /// Groups appointments by the hour of the day (0-23).
    static func byHour(_ appointments: [Appointment]) -> [Int: [Appointment]] {
        Dictionary(grouping: appointments) {
            Calendar.current.component(.hour, from: $0.date)
        }
    }

    /// Groups appointments by weekday (1 = Sunday, 7 = Saturday).
    static func byWeekday(_ appointments: [Appointment]) -> [Int: [Appointment]] {
        Dictionary(grouping: appointments) {
            Calendar.current.component(.weekday, from: $0.date)
        }
    }

    /// Groups appointments by month and year (e.g., "Apr 2025").
    static func byMonthYear(_ appointments: [Appointment]) -> [String: [Appointment]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return Dictionary(grouping: appointments) {
            formatter.string(from: $0.date)
        }
    }
}
