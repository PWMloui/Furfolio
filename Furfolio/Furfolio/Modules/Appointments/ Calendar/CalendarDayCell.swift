//
//  CalendarDayCell.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/**
 `CalendarDayCell` represents a single day within the calendar grid, designed primarily for owner-focused business management in a pet care context. 

 Architecturally, this view supports:
 - Offline-first usage by displaying local event data (appointments, birthdays, tasks).
 - Data security by limiting exposure to only necessary event details.
 - SwiftUI-centric design enabling declarative UI, accessibility, and theming integration.
 
 This cell visually communicates daily business operations and pet-specific events, providing owners with quick insights into their schedule and reminders.

 The component is designed for extensibility, allowing additional event types and adaptive layouts (e.g., two-pane views) to be integrated seamlessly.
 */
struct CalendarDayCell: View {
    /// The specific date this cell represents.
    let date: Date
    
    /// Appointments scheduled for this date (e.g., grooming, vet visits).
    let appointments: [Appointment]
    
    /// Birthdays of dogs on this date, serving as celebratory reminders.
    let birthdays: [Dog]
    
    /// Tasks or reminders associated with this date.
    let tasks: [Task]
    
    /// Indicates if this cell's date is currently selected by the user.
    let isSelected: Bool
    
    /// Indicates if this date belongs to the currently visible month.
    var isInCurrentMonth: Bool = true
    
    /// Action to perform when the cell is tapped.
    var onTap: (() -> Void)? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppSpacing.small) { // Replaced fixed spacing with AppSpacing.small token
            dayNumberView
            
            eventIndicatorsView
                .frame(height: AppSpacing.xSmall) // Replaced fixed height 12 with AppSpacing.xSmall
        }
        .padding(AppSpacing.xSmall) // Replaced fixed padding 2 with AppSpacing.xSmall
        .opacity(isInCurrentMonth ? 1.0 : 0.4)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.medium) // Use design token for corner radius
                .fill(isToday ? AppColors.backgroundHighlight : AppColors.background) // Replaced Color.accentColor.opacity(0.13) with AppColors.backgroundHighlight, Color.clear with AppColors.background
        )
        .contentShape(Rectangle()) // Expand tap target to entire cell
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
    }
    
    // MARK: - Subviews
    
    /// Displays the day number with appropriate styling and selection highlight.
    private var dayNumberView: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(AppFonts.headline.weight(isSelected ? .bold : .regular)) // Replaced .font(.headline) with AppFonts.headline
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isSelected ? AppColors.accent : AppColors.background) // Replaced Color.accentColor with AppColors.accent, Color.clear with AppColors.background
                    .shadow(color: isSelected ? AppColors.accent.opacity(AppShadows.mediumOpacity) : AppColors.background.opacity(0), radius: isSelected ? AppShadows.mediumRadius : 0) // Replaced shadow color and radius with tokens
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // Removed duplicate onTapGesture here to avoid double triggers
    }
    
    /// Displays badges/indicators for appointments, birthdays, and tasks.
    private var eventIndicatorsView: some View {
        HStack(spacing: AppSpacing.xSmall) { // Replaced fixed spacing 3 with AppSpacing.xSmall
            if !birthdays.isEmpty {
                Text("🎂")
                    .font(AppFonts.caption) // Replaced .font(.caption) with AppFonts.caption
                    .accessibilityLabel("\(birthdays.count) Birthday\(birthdays.count > 1 ? "s" : "")")
                    .help("\(birthdays.count) Birthday\(birthdays.count > 1 ? "s" : "")")
            }
            if !appointments.isEmpty {
                Circle()
                    .fill(AppColors.appointmentBadge) // Replaced Color.blue with AppColors.appointmentBadge
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("\(appointments.count) Appointment\(appointments.count > 1 ? "s" : "")")
                    .help("\(appointments.count) Appointment\(appointments.count > 1 ? "s" : "")")
            }
            if !tasks.isEmpty {
                Rectangle()
                    .fill(AppColors.taskBadge) // Replaced Color.orange with AppColors.taskBadge
                    .frame(width: 13, height: 3)
                    .cornerRadius(BorderRadius.small) // Replaced fixed cornerRadius 1.2 with BorderRadius.small
                    .accessibilityLabel("\(tasks.count) Task\(tasks.count > 1 ? "s" : "")")
                    .help("\(tasks.count) Task\(tasks.count > 1 ? "s" : "")")
            }
            // MARK: - Extensibility point:
            // Additional event types can be added here with corresponding badges/indicators.
        }
    }
    
    // MARK: - Accessibility
    
    /// Combined accessibility label describing the date and included events.
    private var accessibilityLabel: String {
        var components = [dateFormatted]
        
        if !birthdays.isEmpty {
            components.append("\(birthdays.count) birthday\(birthdays.count > 1 ? "s" : "")")
        }
        if !appointments.isEmpty {
            components.append("\(appointments.count) appointment\(appointments.count > 1 ? "s" : "")")
        }
        if !tasks.isEmpty {
            components.append("\(tasks.count) task\(tasks.count > 1 ? "s" : "")")
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Accessibility traits including selection and today state.
    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isSelected {
            traits.insert(.isSelected)
        }
        if isToday {
            traits.insert(.isSelected) // Consider .isSelected or custom trait for "today" if desired
        }
        return traits
    }
    
    // MARK: - Helpers
    
    /// Determines if the date is today.
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Date formatted as full string for accessibility.
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    /// Foreground color for the day number based on selection, month membership, and today state.
    private var foregroundColor: Color {
        if isSelected {
            return AppColors.selectedText // Replaced .white with AppColors.selectedText
        }
        if !isInCurrentMonth {
            return AppColors.inactiveText // Replaced .gray with AppColors.inactiveText
        }
        return isToday ? AppColors.accent : AppColors.textPrimary // Replaced .accentColor and .primary with tokens
    }
}

// MARK: - Preview

#if DEBUG
struct CalendarDayCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.medium) { // Replaced fixed spacing 14 with AppSpacing.medium
            CalendarDayCell(
                date: Date(),
                appointments: [.init(id: UUID(), date: Date(), serviceType: "Bath")],
                birthdays: [],
                tasks: [.init(id: UUID(), title: "Reminder", dueDate: Date())],
                isSelected: true
            )
            CalendarDayCell(
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                appointments: [],
                birthdays: [.init(id: UUID(), name: "Bella", birthDate: Date())],
                tasks: [],
                isSelected: false
            )
            CalendarDayCell(
                date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                appointments: [],
                birthdays: [],
                tasks: [],
                isSelected: false,
                isInCurrentMonth: false
            )
        }
        .padding()
        .background(AppColors.background) // Replaced Color(.systemGroupedBackground) with AppColors.background
        .previewLayout(.sizeThatFits)
    }
}
#endif
