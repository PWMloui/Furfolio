//
//  AppointmentFilterMenu.swift
//  Furfolio
//
//  ENHANCED: Tokenized, Modular, Auditable Appointment Filter UI (2025)
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentFilterAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "menuOpen", "filterChange", "datePicker", "reset"
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

    var body: some View {
        Menu {
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
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(IconOnlyLabelStyle())
                .font(AppFonts.title3)
                .accessibilityLabel("Filter Appointments")
                .accessibilityAddTraits(.isButton)
        }
        .onAppear {
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

    private var hasActiveFilters: Bool {
        selectedService != nil || selectedStatus != nil || dateRange != nil
    }

    private func resetFilters() {
        selectedService = nil
        selectedStatus = nil
        dateRange = nil
        onReset?()
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
