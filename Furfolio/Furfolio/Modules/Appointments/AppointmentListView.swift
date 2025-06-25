//
// MARK: - AppointmentListView (Tokenized, Modular, Auditable Appointment List & Filter UI)
//
//  AppointmentListView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  This view presents a modular, tokenized, and auditable appointment list and filter UI.
//  It supports business analytics through structured state and filtering, accessibility via identifiers,
//  localization by using LocalizedStringKey, and integrates with the app's UI design system through tokens for colors, fonts, and spacing.
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentListAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "listLoad", "filterChange", "appointmentTap", "reset"
    let appointmentID: UUID?
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
        let appt = appointmentID?.uuidString.prefix(8) ?? ""
        return "[\(operation.capitalized)] appt:\(appt) \(service ?? "Any")/\(status ?? "Any")/\(range) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentListAudit {
    static private(set) var log: [AppointmentListAuditEvent] = []

    static func record(
        operation: String,
        appointmentID: UUID? = nil,
        service: String? = nil,
        status: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentListView",
        detail: String? = nil
    ) {
        let event = AppointmentListAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            service: service,
            status: status,
            dateRange: dateRange,
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
        log.last?.accessibilityLabel ?? "No appointment list actions recorded."
    }
}

private extension Date {
    var shortString: String {
        let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .none
        return fmt.string(from: self)
    }
}

// MARK: - AppointmentListView

struct AppointmentListView: View {
    // MARK: - Filter State
    @State private var selectedService: String? = nil
    @State private var selectedStatus: String? = nil
    @State private var dateRange: ClosedRange<Date>? = nil

    // MARK: - Data Source
    @State private var allAppointments: [Appointment] = Appointment.sampleData()

    // MARK: - Computed filtered appointments
    private var filteredAppointments: [Appointment] {
        allAppointments.filter { appointment in
            // Filter by service
            if let service = selectedService, service != appointment.serviceType {
                return false
            }
            // Filter by status
            if let status = selectedStatus, status != appointment.status {
                return false
            }
            // Filter by date range
            if let range = dateRange {
                if appointment.date < range.lowerBound || appointment.date > range.upperBound {
                    return false
                }
            }
            return true
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Extract filter options dynamically
    private var serviceTypes: [String] {
        Array(Set(allAppointments.map { $0.serviceType })).sorted()
    }

    private var statuses: [String] {
        Array(Set(allAppointments.map { $0.status })).sorted()
    }

    var body: some View {
        NavigationView {
            List {
                if filteredAppointments.isEmpty {
                    Text(LocalizedStringKey("No appointments found for selected filters."))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(AppSpacing.medium)
                } else {
                    ForEach(filteredAppointments) { appointment in
                        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
                            AppointmentRowView(appointment: appointment)
                                .accessibilityIdentifier("AppointmentRow_\(appointment.id.uuidString)")
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            AppointmentListAudit.record(
                                operation: "appointmentTap",
                                appointmentID: appointment.id,
                                service: appointment.serviceType,
                                status: appointment.status,
                                tags: ["appointmentTap"],
                                detail: "Tapped appointment row"
                            )
                        })
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Appointments"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AppointmentFilterMenu(
                        selectedService: $selectedService,
                        selectedStatus: $selectedStatus,
                        dateRange: $dateRange,
                        serviceTypes: serviceTypes,
                        statuses: statuses,
                        onReset: {
                            selectedService = nil
                            selectedStatus = nil
                            dateRange = nil
                            AppointmentListAudit.record(
                                operation: "reset",
                                tags: ["reset"],
                                detail: "Filters reset"
                            )
                        }
                    )
                    .accessibilityIdentifier("AppointmentFilterMenu")
                    // Audit filter changes
                    .onChange(of: selectedService) { newVal in
                        AppointmentListAudit.record(
                            operation: "filterChange",
                            service: newVal,
                            status: selectedStatus,
                            dateRange: dateRange,
                            tags: ["serviceType"],
                            detail: "Service filter changed"
                        )
                    }
                    .onChange(of: selectedStatus) { newVal in
                        AppointmentListAudit.record(
                            operation: "filterChange",
                            service: selectedService,
                            status: newVal,
                            dateRange: dateRange,
                            tags: ["status"],
                            detail: "Status filter changed"
                        )
                    }
                    .onChange(of: dateRange) { newVal in
                        AppointmentListAudit.record(
                            operation: "filterChange",
                            service: selectedService,
                            status: selectedStatus,
                            dateRange: newVal,
                            tags: ["dateRange"],
                            detail: "Date range filter changed"
                        )
                    }
                }
            }
            .onAppear {
                AppointmentListAudit.record(
                    operation: "listLoad",
                    tags: ["load"],
                    detail: "Appointment list loaded"
                )
            }
        }
    }
}

// MARK: - AppointmentRowView

struct AppointmentRowView: View {
    let appointment: Appointment

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(appointment.serviceType)
                .font(AppFonts.headline)
            Text(appointment.status)
                .font(AppFonts.subheadline)
                .foregroundColor(AppColors.secondaryText)
            Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(.vertical, AppSpacing.small)
    }
}

// MARK: - AppointmentDetailView

struct AppointmentDetailView: View {
    let appointment: Appointment

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(LocalizedStringKey("Service: \(appointment.serviceType)"))
                .font(AppFonts.title2)
                .bold()
            Text(LocalizedStringKey("Status: \(appointment.status)"))
                .font(AppFonts.headline)
            Text(LocalizedStringKey("Date: \(appointment.date.formatted(date: .long, time: .shortened))"))
                .font(AppFonts.subheadline)

            Spacer()
        }
        .padding()
        .navigationTitle(LocalizedStringKey("Appointment Details"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appointment Model

struct Appointment: Identifiable {
    let id = UUID()
    let date: Date
    let serviceType: String
    let status: String

    static func sampleData() -> [Appointment] {
        let now = Date()
        return [
            Appointment(date: now.addingTimeInterval(3600), serviceType: "Full Groom", status: "Scheduled"),
            Appointment(date: now.addingTimeInterval(7200), serviceType: "Bath Only", status: "Completed"),
            Appointment(date: now.addingTimeInterval(-3600), serviceType: "Nail Trim", status: "Cancelled"),
            Appointment(date: now.addingTimeInterval(86400), serviceType: "Full Groom", status: "Scheduled"),
            Appointment(date: now.addingTimeInterval(172800), serviceType: "Bath Only", status: "Scheduled"),
        ]
    }
}

// MARK: - Demo / Business / Tokenized Preview

struct AppointmentListView_Previews: PreviewProvider {
    static var previews: some View {
        AppointmentListView()
            .accentColor(AppColors.accent)
    }
}

// MARK: - AppointmentFilterMenu
struct AppointmentFilterMenu: View {
    @Binding var selectedService: String?
    @Binding var selectedStatus: String?
    @Binding var dateRange: ClosedRange<Date>?

    let serviceTypes: [String]
    let statuses: [String]
    let onReset: () -> Void

    @State private var tempDateRange: ClosedRange<Date>? = nil

    var body: some View {
        Menu {
            // Service Filter Picker with tokenized text and accessibility
            Picker(selection: $selectedService) {
                Text(LocalizedStringKey("All Services")).tag(String?.none)
                ForEach(serviceTypes, id: \.self) { service in
                    Text(LocalizedStringKey(service)).tag(String?(service))
                }
            } label: {
                Text(LocalizedStringKey("Service"))
                    // Tokenized font for consistency
                    .font(AppFonts.subheadline)
                    // Tokenized color for text
                    .foregroundColor(AppColors.primaryText)
            }

            // Status Filter Picker with tokenized text and accessibility
            Picker(selection: $selectedStatus) {
                Text(LocalizedStringKey("All Statuses")).tag(String?.none)
                ForEach(statuses, id: \.self) { status in
                    Text(LocalizedStringKey(status)).tag(String?(status))
                }
            } label: {
                Text(LocalizedStringKey("Status"))
                    // Tokenized font and color for consistency
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.primaryText)
            }

            // Date Range Filter with tokenized text and accessibility
            DateRangePickerView(dateRange: $tempDateRange)
                // Synchronize tempDateRange changes to parent dateRange binding
                .onChange(of: tempDateRange) { newRange in
                    dateRange = newRange
                }

            Divider()

            // Reset Filters button with localized string
            Button(action: onReset) {
                Text(LocalizedStringKey("Reset Filters"))
                    // Tokenized font and color for button text
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.accent)
            }
        } label: {
            Label {
                Text(LocalizedStringKey("Filter"))
                    // Tokenized font and color for label text
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.primaryText)
            } icon: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(AppColors.accent)
            }
        }
        // Accessibility identifier for filter menu
        .accessibilityIdentifier("AppointmentFilterMenu")
        // Initialize tempDateRange on appear for consistent state management
        .onAppear {
            tempDateRange = dateRange
        }
    }
}

// MARK: - DateRangePickerView
struct DateRangePickerView: View {
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()

    var body: some View {
        VStack {
            DatePicker(
                selection: $startDate,
                displayedComponents: .date,
                label: { Text(LocalizedStringKey("Start Date"))
                    // Tokenized font and color for label
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.primaryText)
                }
            )
            // Accessibility identifier for start date picker
            .accessibilityIdentifier("StartDatePicker")
            .onChange(of: startDate) { _ in updateRange() }

            DatePicker(
                selection: $endDate,
                displayedComponents: .date,
                label: { Text(LocalizedStringKey("End Date"))
                    // Tokenized font and color for label
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.primaryText)
                }
            )
            // Accessibility identifier for end date picker
            .accessibilityIdentifier("EndDatePicker")
            .onChange(of: endDate) { _ in updateRange() }
        }
        // Tokenized vertical padding for spacing
        .padding(.vertical, AppSpacing.small)
        .onAppear {
            if let range = dateRange {
                startDate = range.lowerBound
                endDate = range.upperBound
            }
        }
    }

    private func updateRange() {
        // Only update if startDate is before or equal to endDate
        guard startDate <= endDate else { return }
        dateRange = startDate...endDate
    }
}

public enum AppointmentListAuditAdmin {
    public static var lastSummary: String { AppointmentListAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentListAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentListAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}
