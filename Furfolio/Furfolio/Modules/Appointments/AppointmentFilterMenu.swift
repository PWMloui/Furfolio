//
//  AppointmentFilterMenu.swift
//  Furfolio
//
//  ENHANCED: Tokenized, Modular, Auditable Appointment Filter UI (2025)
//

import SwiftUI
import UIKit

// MARK: - Audit/Event Logging

fileprivate struct AppointmentFilterAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "menuOpen", "filterChange", "datePicker", "reset", "preset"
    let service: String?
    let status: String?
    let dateRange: ClosedRange<Date>?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let range = dateRange.map { "\($0.lowerBound.shortString) - \($0.upperBound.shortString)" } ?? ""
        return "[\(operation.capitalized)] \(service ?? "Any")/\(status ?? "Any")/\(range) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentFilterAudit {
    static private(set) var log: [AppointmentFilterAuditEvent] = []

    static func record(
        operation: String,
        service: String?,
        status: String?,
        dateRange: ClosedRange<Date>?,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentFilterMenu",
        detail: String? = nil
    ) {
        let event = AppointmentFilterAuditEvent(
            timestamp: Date(),
            operation: operation,
            service: service,
            status: status,
            dateRange: dateRange,
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
    
    /// Exports all audit events as a CSV string with headers.
    static func exportAllCSV() -> String {
        var csv = "timestamp,operation,service,status,dateRange,tags,actor,context,detail\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = dateFormatter.string(from: event.timestamp)
            let operation = event.operation
            let service = event.service ?? ""
            let status = event.status ?? ""
            let dateRange = event.dateRange.map { "\($0.lowerBound.timeIntervalSince1970)-\($0.upperBound.timeIntervalSince1970)" } ?? ""
            let tags = event.tags.joined(separator: "|")
            let actor = event.actor ?? ""
            let context = event.context ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let detailEscaped = "\"\(detail)\""
            csv += "\(timestamp),\(operation),\(service),\(status),\(dateRange),\(tags),\(actor),\(context),\(detailEscaped)\n"
        }
        return csv
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No filter events recorded."
    }
}

private extension Date {
    var shortString: String {
        let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .none
        return fmt.string(from: self)
    }
}

// MARK: - AppointmentFilterMenu

struct AppointmentFilterMenu: View {
    @Binding var selectedService: String?
    @Binding var selectedStatus: String?
    @Binding var dateRange: ClosedRange<Date>?

    let serviceTypes: [String]
    let statuses: [String]

    var onReset: (() -> Void)? = nil

    @State private var isDatePickerPresented = false

    // MARK: - Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Menu {
            // MARK: Quick Presets Section
            Section("Quick Presets") {
                // "Today's Appointments" preset button
                Button("Today's Appointments") {
                    applyPresetToday()
                }
                // "This Week" preset button
                Button("This Week") {
                    applyPresetThisWeek()
                }
                // "Uncompleted Only" preset button
                Button("Uncompleted Only") {
                    applyPresetUncompleted()
                }
            }

            // MARK: Service Type Picker
            Section("Service Type") {
                Picker("Service Type", selection: Binding(
                    get: { selectedService },
                    set: { newVal in
                        selectedService = newVal
                        AppointmentFilterAudit.record(
                            operation: "filterChange",
                            service: newVal,
                            status: selectedStatus,
                            dateRange: dateRange,
                            tags: ["serviceType"],
                            detail: "Service changed"
                        )
                    }
                )) {
                    Text("All Services").tag(String?.none)
                    ForEach(serviceTypes, id: \.self) { service in
                        Text(service).tag(Optional(service))
                    }
                }
                // Clear button to quickly unset the service filter if set
                if selectedService != nil {
                    Button("Clear Service Filter") {
                        selectedService = nil
                        AppointmentFilterAudit.record(
                            operation: "filterChange",
                            service: nil,
                            status: selectedStatus,
                            dateRange: dateRange,
                            tags: ["serviceType", "clear"],
                            detail: "Service filter cleared"
                        )
                    }
                }
            }

            // MARK: Status Picker
            Section("Status") {
                Picker("Status", selection: Binding(
                    get: { selectedStatus },
                    set: { newVal in
                        selectedStatus = newVal
                        AppointmentFilterAudit.record(
                            operation: "filterChange",
                            service: selectedService,
                            status: newVal,
                            dateRange: dateRange,
                            tags: ["status"],
                            detail: "Status changed"
                        )
                    }
                )) {
                    Text("All Statuses").tag(String?.none)
                    ForEach(statuses, id: \.self) { status in
                        Text(status).tag(Optional(status))
                    }
                }
                // Clear button to quickly unset the status filter if set
                if selectedStatus != nil {
                    Button("Clear Status Filter") {
                        selectedStatus = nil
                        AppointmentFilterAudit.record(
                            operation: "filterChange",
                            service: selectedService,
                            status: nil,
                            dateRange: dateRange,
                            tags: ["status", "clear"],
                            detail: "Status filter cleared"
                        )
                    }
                }
            }

            // MARK: Date Range Selector
            Section {
                Button {
                    isDatePickerPresented.toggle()
                    AppointmentFilterAudit.record(
                        operation: "datePicker",
                        service: selectedService,
                        status: selectedStatus,
                        dateRange: dateRange,
                        tags: ["datePicker"],
                        detail: "Date range picker opened"
                    )
                } label: {
                    Label("Select Date Range", systemImage: "calendar")
                }
            }

            // MARK: Reset Filters Button
            if hasActiveFilters {
                Section {
                    Button("Reset Filters", role: .destructive) {
                        resetFilters()
                        AppointmentFilterAudit.record(
                            operation: "reset",
                            service: nil,
                            status: nil,
                            dateRange: nil,
                            tags: ["reset"],
                            detail: "Filters reset"
                        )
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .labelStyle(IconOnlyLabelStyle())
                    .font(AppFonts.title3)
                    .accessibilityLabel("Filter Appointments")
                    .accessibilityAddTraits(.isButton)
                // MARK: Dynamic badge if any filters are active
                if hasActiveFilters {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -4)
                        .accessibilityLabel("Filters active")
                }
            }
        }
        .onAppear {
            // Play haptic feedback when filter menu opens
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
            AppointmentFilterAudit.record(
                operation: "menuOpen",
                service: selectedService,
                status: selectedStatus,
                dateRange: dateRange,
                tags: ["open"],
                detail: "Filter menu opened"
            )
        }
        .sheet(isPresented: $isDatePickerPresented) {
            DateRangePickerView(dateRange: $dateRange)
                .onDisappear {
                    AppointmentFilterAudit.record(
                        operation: "filterChange",
                        service: selectedService,
                        status: selectedStatus,
                        dateRange: dateRange,
                        tags: ["dateRange"],
                        detail: "Date range changed"
                    )
                }
        }
    }

    /// Indicates if any filters are currently active.
    private var hasActiveFilters: Bool {
        selectedService != nil || selectedStatus != nil || dateRange != nil
    }

    /// Resets all filters to nil and calls onReset closure if provided.
    private func resetFilters() {
        selectedService = nil
        selectedStatus = nil
        dateRange = nil
        onReset?()
    }

    // MARK: - Quick Preset Actions

    /// Applies the "Today's Appointments" preset: sets date range to today and clears status.
    private func applyPresetToday() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? Date()
        dateRange = start...end
        selectedStatus = nil
        AppointmentFilterAudit.record(
            operation: "preset",
            service: selectedService,
            status: selectedStatus,
            dateRange: dateRange,
            tags: ["preset", "today"],
            detail: "Applied 'Today's Appointments' preset"
        )
        closeMenuIfPossible()
    }

    /// Applies the "This Week" preset: sets date range to the current week and clears status.
    private func applyPresetThisWeek() {
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let start = weekInterval.start
        let end = weekInterval.end.addingTimeInterval(-1)
        dateRange = start...end
        selectedStatus = nil
        AppointmentFilterAudit.record(
            operation: "preset",
            service: selectedService,
            status: selectedStatus,
            dateRange: dateRange,
            tags: ["preset", "thisWeek"],
            detail: "Applied 'This Week' preset"
        )
        closeMenuIfPossible()
    }

    /// Applies the "Uncompleted Only" preset: clears date range and sets status to uncompleted statuses.
    private func applyPresetUncompleted() {
        // Assuming "Scheduled" and "In Progress" are uncompleted statuses; adjust as needed.
        // Here we set status filter to "Scheduled" only for simplicity.
        dateRange = nil
        selectedStatus = "Scheduled"
        AppointmentFilterAudit.record(
            operation: "preset",
            service: selectedService,
            status: selectedStatus,
            dateRange: dateRange,
            tags: ["preset", "uncompleted"],
            detail: "Applied 'Uncompleted Only' preset"
        )
        closeMenuIfPossible()
    }

    /// Attempts to close the menu if possible by toggling isDatePickerPresented false.
    /// Since SwiftUI Menu does not provide a direct way to close programmatically,
    /// this is a best-effort placeholder.
    private func closeMenuIfPossible() {
        // No direct API to close Menu programmatically in SwiftUI.
        // This function is a placeholder for future improvements or UIKit bridging if needed.
    }
}

// MARK: Date Range Picker Sheet

struct DateRangePickerView: View {
    @Binding var dateRange: ClosedRange<Date>?
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section("Start Date") {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
                Section("End Date") {
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dateRange = startDate...endDate
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentFilterAuditAdmin {
    public static var lastSummary: String { AppointmentFilterAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentFilterAudit.exportLastJSON() }
    /// Export all audit events as CSV string.
    public static func exportCSV() -> String { AppointmentFilterAudit.exportAllCSV() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentFilterAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct AppointmentFilterMenu_Previews: PreviewProvider {
    @State static var serviceFilter: String? = nil
    @State static var statusFilter: String? = nil
    @State static var dateRangeFilter: ClosedRange<Date>? = nil

    static var previews: some View {
        AppointmentFilterMenu(
            selectedService: $serviceFilter,
            selectedStatus: $statusFilter,
            dateRange: $dateRangeFilter,
            serviceTypes: ["Full Groom", "Bath Only", "Nail Trim"],
            statuses: ["Scheduled", "Completed", "Cancelled"]
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
