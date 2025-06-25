//
//  CalendarDayCell.swift
//  Furfolio
//
//  Enhanced 2025: Tokenized, Modular, Auditable Calendar Day Cell
//

import SwiftUI

// MARK: - CalendarDayCell Audit/Event Logging

fileprivate struct CalendarDayCellAuditEvent: Codable {
    let timestamp: Date
    let operation: String    // "tap"
    let date: Date
    let appointments: Int
    let birthdays: Int
    let tasks: Int
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let day = DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none)
        return "[CalendarCell \(operation)] \(day) (\(appointments) appt, \(birthdays) bday, \(tasks) task) at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class CalendarDayCellAudit {
    static private(set) var log: [CalendarDayCellAuditEvent] = []

    static func record(
        operation: String,
        date: Date,
        appointments: Int,
        birthdays: Int,
        tasks: Int,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "CalendarDayCell",
        detail: String? = nil
    ) {
        let event = CalendarDayCellAuditEvent(
            timestamp: Date(),
            operation: operation,
            date: date,
            appointments: appointments,
            birthdays: birthdays,
            tasks: tasks,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No CalendarDayCell actions recorded."
    }
}

// MARK: - CalendarDayCell (Tokenized, Modular, Auditable)

struct CalendarDayCell: View {
    let date: Date
    let appointments: [Appointment]
    let birthdays: [Dog]
    let tasks: [Task]
    let isSelected: Bool
    var isInCurrentMonth: Bool = true
    var onTap: (() -> Void)? = nil
    var actor: String? = "user"
    var context: String? = "CalendarDayCell"

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            dayNumberView
            eventIndicatorsView
                .frame(height: AppSpacing.xSmall)
        }
        .padding(AppSpacing.xSmall)
        .opacity(isInCurrentMonth ? 1.0 : 0.4)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.medium)
                .fill(isToday ? AppColors.backgroundHighlight : AppColors.background)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            CalendarDayCellAudit.record(
                operation: "tap",
                date: date,
                appointments: appointments.count,
                birthdays: birthdays.count,
                tasks: tasks.count,
                tags: buildTags(),
                actor: actor,
                context: context
            )
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
    }

    // MARK: - Subviews

    private var dayNumberView: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(AppFonts.headline.weight(isSelected ? .bold : .regular))
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isSelected ? AppColors.accent : AppColors.background)
                    .shadow(
                        color: isSelected ? AppColors.accent.opacity(AppShadows.mediumOpacity) : AppColors.background.opacity(0),
                        radius: isSelected ? AppShadows.mediumRadius : 0
                    )
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var eventIndicatorsView: some View {
        HStack(spacing: AppSpacing.xSmall) {
            if !birthdays.isEmpty {
                Text("🎂")
                    .font(AppFonts.caption)
                    .accessibilityLabel("\(birthdays.count) Birthday\(birthdays.count > 1 ? "s" : "")")
                    .help("\(birthdays.count) Birthday\(birthdays.count > 1 ? "s" : "")")
            }
            if !appointments.isEmpty {
                Circle()
                    .fill(AppColors.appointmentBadge)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("\(appointments.count) Appointment\(appointments.count > 1 ? "s" : "")")
                    .help("\(appointments.count) Appointment\(appointments.count > 1 ? "s" : "")")
            }
            if !tasks.isEmpty {
                Rectangle()
                    .fill(AppColors.taskBadge)
                    .frame(width: 13, height: 3)
                    .cornerRadius(BorderRadius.small)
                    .accessibilityLabel("\(tasks.count) Task\(tasks.count > 1 ? "s" : "")")
                    .help("\(tasks.count) Task\(tasks.count > 1 ? "s" : "")")
            }
            // Extensibility point: add more event badges here and audit in onTap if needed
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var components = [dateFormatted]
        if !birthdays.isEmpty { components.append("\(birthdays.count) birthday\(birthdays.count > 1 ? "s" : "")") }
        if !appointments.isEmpty { components.append("\(appointments.count) appointment\(appointments.count > 1 ? "s" : "")") }
        if !tasks.isEmpty { components.append("\(tasks.count) task\(tasks.count > 1 ? "s" : "")") }
        return components.joined(separator: ", ")
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isSelected { traits.insert(.isSelected) }
        if isToday { traits.insert(.isSelected) }
        return traits
    }

    // MARK: - Helpers

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var foregroundColor: Color {
        if isSelected { return AppColors.selectedText }
        if !isInCurrentMonth { return AppColors.inactiveText }
        return isToday ? AppColors.accent : AppColors.textPrimary
    }

    private func buildTags() -> [String] {
        var tags = [String]()
        if isSelected { tags.append("selected") }
        if isToday { tags.append("today") }
        if !birthdays.isEmpty { tags.append("birthday") }
        if !appointments.isEmpty { tags.append("appointment") }
        if !tasks.isEmpty { tags.append("task") }
        if !isInCurrentMonth { tags.append("notCurrentMonth") }
        return tags
    }
}

// MARK: - Audit/Admin Accessors

public enum CalendarDayCellAuditAdmin {
    public static var lastSummary: String { CalendarDayCellAudit.accessibilitySummary }
    public static var lastJSON: String? { CalendarDayCellAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        CalendarDayCellAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct CalendarDayCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.medium) {
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
        .background(AppColors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
