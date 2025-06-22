//
//  CalendarView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  Unified, owner-focused calendar and scheduling interface for Furfolio, enabling business owners to manage appointments, birthdays, and tasks efficiently with a consistent, two-pane SwiftUI experience.
//  Multi-Platform Ready: Designed to adapt between two-pane and compact navigation layouts for optimal user experience across devices.
//  Security/Privacy Note: All user data shown here is local/offline; ensure data never leaves device (matches Furfolio business model).
//

import SwiftUI

/// The main calendar view presenting a unified interface for managing appointments, birthdays, and tasks.
/// This view is fully modular and uses design tokens for colors, fonts, spacings, and corner radii,
/// ensuring consistency and audit readiness across Furfolio’s UI components.
struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel

    /// State controlling the presentation of the add appointment sheet.
    @State private var showingAddAppointment = false

    /// The currently selected date in the calendar grid.
    @State private var selectedDate: Date? = nil

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            CalendarHeaderView(
                currentMonth: viewModel.currentMonth,
                onPrev: { viewModel.changeMonth(by: -1) },
                onNext: { viewModel.changeMonth(by: 1) },
                showWeek: $viewModel.showingWeek
            )
            .padding(.horizontal, AppSpacing.medium)

            Divider()

            CalendarGridView(
                days: viewModel.daysInCurrentMonth,
                appointments: viewModel.appointmentsByDay,
                birthdays: viewModel.birthdaysByDay,
                tasks: viewModel.tasksByDay,
                selectedDate: $selectedDate,
                onTapDay: { date in
                    selectedDate = date
                    showingAddAppointment = true
                },
                onDragAppointment: { appointmentID, toDate in
                    viewModel.rescheduleAppointment(id: appointmentID, to: toDate)
                }
            )
            .animation(.easeInOut(duration: 0.24), value: viewModel.currentMonth)
            .padding(.vertical, AppSpacing.small)

            if let selectedDate = selectedDate {
                AddAppointmentSheet(
                    date: selectedDate,
                    isPresented: $showingAddAppointment,
                    onComplete: { viewModel.reloadAppointments() }
                )
            }
        }
        .background(AppColors.background)
        .onAppear {
            viewModel.reloadAppointments()
        }
    }
}


/// The header view for the calendar, showing the current month and navigation controls.
/// This component is fully tokenized for colors, fonts, spacings, and accessibility,
/// providing a consistent and audit-ready navigation interface in Furfolio.
struct CalendarHeaderView: View {
    /// The currently displayed month.
    var currentMonth: Date

    /// Action to perform when navigating to the previous month.
    var onPrev: () -> Void

    /// Action to perform when navigating to the next month.
    var onNext: () -> Void

    /// Binding controlling whether the calendar is in week or month view.
    @Binding var showWeek: Bool

    var body: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .foregroundColor(AppColors.primary)
            }
            Spacer()
            Text(DateUtils.monthYearString(currentMonth))
                .font(AppFonts.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.primary)
            }
            Button(action: { showWeek.toggle() }) {
                Image(systemName: showWeek ? "calendar" : "rectangle.split.3x1")
                    .foregroundColor(AppColors.primary)
                    .accessibilityLabel(showWeek ? "Switch to Month" : "Switch to Week")
            }
        }
        .padding(.vertical, AppSpacing.small)
    }
}


/// The grid view displaying days of the current month (or week) along with associated appointments, birthdays, and tasks.
/// This view uses modular tokens for spacing and colors, ensuring a consistent and audit-ready UI experience.
struct CalendarGridView: View {
    /// The array of dates to display in the grid.
    let days: [Date]

    /// Dictionary mapping dates to their appointments.
    let appointments: [Date: [Appointment]]

    /// Dictionary mapping dates to their birthdays.
    let birthdays: [Date: [Dog]]

    /// Dictionary mapping dates to their tasks.
    let tasks: [Date: [Task]]

    /// Binding to the currently selected date.
    @Binding var selectedDate: Date?

    /// Callback when a day is tapped.
    var onTapDay: (Date) -> Void

    /// Callback when an appointment is dragged to a new date.
    var onDragAppointment: (UUID, Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xSmall), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xSmall) {
            ForEach(days, id: \.self) { day in
                CalendarDayCell(
                    date: day,
                    appointments: appointments[day] ?? [],
                    birthdays: birthdays[day] ?? [],
                    tasks: tasks[day] ?? [],
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate ?? Date()),
                    onTap: { onTapDay(day) }
                    // Future implementation: integrate drag/drop support with audit logging and tokenized UI.
                )
            }
        }
        .padding(.horizontal, AppSpacing.xSmall)
    }
}


/// A sheet view for adding a new appointment on a selected date.
/// Currently a placeholder to be replaced with the actual add appointment UI.
struct AddAppointmentSheet: View {
    /// The date for which the appointment is being added.
    let date: Date

    /// Binding controlling the presentation of the sheet.
    @Binding var isPresented: Bool

    /// Callback invoked when the appointment addition is completed.
    var onComplete: () -> Void

    var body: some View {
        // Replace with your app's actual add appointment view!
        EmptyView()
    }
}


/// Utility functions related to date formatting and manipulation.
enum DateUtils {
    /// Returns a string representing the month and year of the given date, e.g. "June 2025".
    /// - Parameter date: The date to format.
    /// - Returns: A formatted string with full month name and year.
    static func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}


/// View model managing the state and data for the calendar view.
/// Handles current month, appointments, birthdays, tasks, and user interactions.
///
/// - Note: Data source should be injected via DependencyContainer for testability and scalability.
final class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var showingWeek: Bool = false

    /// Dictionary mapping dates to appointments.
    @Published var appointmentsByDay: [Date: [Appointment]] = [:]

    /// Dictionary mapping dates to dog birthdays.
    @Published var birthdaysByDay: [Date: [Dog]] = [:]

    /// Dictionary mapping dates to tasks.
    @Published var tasksByDay: [Date: [Task]] = [:]

    /// Returns an array of dates representing all visible days in the current calendar view (month or week).
    var daysInCurrentMonth: [Date] {
        // Placeholder for audit/event logging and tokenized UI design for date grid generation.
        return []
    }

    /// Changes the current month by the specified offset.
    /// - Parameter value: The number of months to shift. Negative for previous months, positive for next.
    func changeMonth(by value: Int) {
        // Placeholder for audit/event logging and tokenized UI design for month navigation.
    }

    /// Reloads appointments, birthdays, and tasks data.
    /// Typically fetches or refreshes data from the data source.
    func reloadAppointments() {
        // Placeholder for audit/event logging and tokenized data refresh implementation.
    }

    /// Reschedules an appointment to a new date.
    /// - Parameters:
    ///   - id: The unique identifier of the appointment.
    ///   - date: The new date to assign to the appointment.
    func rescheduleAppointment(id: UUID, to date: Date) {
        // Move an appointment to a new date with audit logging and tokenized UI updates.
    }
}


/// Represents an appointment with a unique identifier, date, and service type.
///
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for use in SwiftUI and data persistence.
struct Appointment: Identifiable, Hashable, Codable {
    var id: UUID
    var date: Date
    var serviceType: String
}


/// Represents a dog with a unique identifier, name, and birth date.
///
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for use in SwiftUI and data persistence.
struct Dog: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var birthDate: Date
}


/// Represents a task with a unique identifier, title, and due date.
///
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for use in SwiftUI and data persistence.
struct Task: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var dueDate: Date
}
