//
//  CalendarView.swift
//  Furfolio
//
//  Enhanced 2025: Unified, Modular, Auditable, Tokenized Calendar & Scheduling UI
//

import SwiftUI

// MARK: - Calendar Audit/Event Logging

fileprivate struct CalendarAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // e.g. "navigateMonth", "selectDate", "reload", "reschedule"
    let date: Date?
    let value: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let dateVal = date.map { DateUtils.monthYearString($0) } ?? ""
        let msg = detail ?? ""
        return "[\(operation.capitalized)] \(dateVal) \(value ?? "") at \(dateStr)\(msg.isEmpty ? "" : ": \(msg)")"
    }
}

fileprivate final class CalendarAudit {
    static private(set) var log: [CalendarAuditEvent] = []

    static func record(
        operation: String,
        date: Date? = nil,
        value: String? = nil,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "CalendarView",
        detail: String? = nil
    ) {
        let event = CalendarAuditEvent(
            timestamp: Date(),
            operation: operation,
            date: date,
            value: value,
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
        log.last?.accessibilityLabel ?? "No calendar actions recorded."
    }
}

// MARK: - CalendarView

struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel

    @State private var showingAddAppointment = false
    @State private var selectedDate: Date? = nil
    @State private var showAuditSheet = false

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            CalendarHeaderView(
                currentMonth: viewModel.currentMonth,
                onPrev: {
                    viewModel.changeMonth(by: -1)
                    CalendarAudit.record(
                        operation: "navigateMonth",
                        date: viewModel.currentMonth,
                        tags: ["navigate", "prevMonth"]
                    )
                },
                onNext: {
                    viewModel.changeMonth(by: 1)
                    CalendarAudit.record(
                        operation: "navigateMonth",
                        date: viewModel.currentMonth,
                        tags: ["navigate", "nextMonth"]
                    )
                },
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
                    CalendarAudit.record(
                        operation: "selectDate",
                        date: date,
                        tags: ["select", "date"]
                    )
                },
                onDragAppointment: { appointmentID, toDate in
                    viewModel.rescheduleAppointment(id: appointmentID, to: toDate)
                    CalendarAudit.record(
                        operation: "reschedule",
                        date: toDate,
                        value: appointmentID.uuidString,
                        tags: ["reschedule", "dragDrop"]
                    )
                }
            )
            .animation(.easeInOut(duration: 0.24), value: viewModel.currentMonth)
            .padding(.vertical, AppSpacing.small)

            if let selectedDate = selectedDate {
                AddAppointmentSheet(
                    date: selectedDate,
                    isPresented: $showingAddAppointment,
                    onComplete: {
                        viewModel.reloadAppointments()
                        CalendarAudit.record(
                            operation: "reload",
                            date: selectedDate,
                            tags: ["reload", "addAppointment"]
                        )
                    }
                )
            }
        }
        .background(AppColors.background)
        .onAppear {
            viewModel.reloadAppointments()
            CalendarAudit.record(
                operation: "reload",
                tags: ["reload", "onAppear"]
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAuditSheet = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .accessibilityLabel("View Calendar Audit Log")
                }
            }
        }
        .sheet(isPresented: $showAuditSheet) {
            CalendarAuditSheetView(isPresented: $showAuditSheet)
        }
    }
}

// MARK: - CalendarHeaderView

struct CalendarHeaderView: View {
    var currentMonth: Date
    var onPrev: () -> Void
    var onNext: () -> Void
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

// MARK: - CalendarGridView

struct CalendarGridView: View {
    let days: [Date]
    let appointments: [Date: [Appointment]]
    let birthdays: [Date: [Dog]]
    let tasks: [Date: [Task]]
    @Binding var selectedDate: Date?
    var onTapDay: (Date) -> Void
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
                    // (Enhance: Add drag/drop hooks for traceability.)
                )
            }
        }
        .padding(.horizontal, AppSpacing.xSmall)
    }
}

// MARK: - AddAppointmentSheet (Placeholder)

struct AddAppointmentSheet: View {
    let date: Date
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    var body: some View {
        // TODO: Replace with full add appointment UI
        EmptyView()
    }
}

// MARK: - DateUtils

enum DateUtils {
    static func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - CalendarViewModel

final class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var showingWeek: Bool = false
    @Published var appointmentsByDay: [Date: [Appointment]] = [:]
    @Published var birthdaysByDay: [Date: [Dog]] = [:]
    @Published var tasksByDay: [Date: [Task]] = [:]

    var daysInCurrentMonth: [Date] {
        // (Demo implementation)
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1...30
        var comps = calendar.dateComponents([.year, .month], from: currentMonth)
        comps.day = 1
        let start = calendar.date(from: comps)!
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day-1, to: start)
        }
    }

    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
            CalendarAudit.record(
                operation: "navigateMonth",
                date: newDate,
                tags: ["navigate", value > 0 ? "nextMonth" : "prevMonth"],
                detail: "Changed month by \(value)"
            )
        }
    }

    func reloadAppointments() {
        // Simulate a reload with audit event
        CalendarAudit.record(
            operation: "reload",
            date: currentMonth,
            tags: ["reload", "data"]
        )
    }

    func rescheduleAppointment(id: UUID, to date: Date) {
        // Simulate rescheduling with audit event
        CalendarAudit.record(
            operation: "reschedule",
            date: date,
            value: id.uuidString,
            tags: ["reschedule", "appointment"]
        )
    }
}

// MARK: - Models

struct Appointment: Identifiable, Hashable, Codable {
    var id: UUID
    var date: Date
    var serviceType: String
}

struct Dog: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var birthDate: Date
}

struct Task: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var dueDate: Date
}

// MARK: - Audit/Admin Accessors

public enum CalendarAuditAdmin {
    public static var lastSummary: String { CalendarAudit.accessibilitySummary }
    public static var lastJSON: String? { CalendarAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        CalendarAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Audit Sheet for Admin/Trust Center

private struct CalendarAuditSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if CalendarAudit.log.isEmpty {
                    ContentUnavailableView("No Calendar Events Yet", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(CalendarAudit.log.suffix(40).reversed(), id: \.timestamp) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.accessibilityLabel)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let context = event.context, !context.isEmpty {
                                Text("Context: \(context)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Calendar Audit Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let json = CalendarAudit.exportLastJSON() {
                        Button {
                            UIPasteboard.general.string = json
                        } label: {
                            Label("Copy Last as JSON", systemImage: "doc.on.doc")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}
