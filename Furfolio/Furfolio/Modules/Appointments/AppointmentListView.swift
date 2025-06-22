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
                        // Use tokenized secondary text color for accessibility and design consistency
                        .foregroundColor(AppColors.secondaryText)
                        // Use tokenized spacing for padding
                        .padding(AppSpacing.medium)
                } else {
                    ForEach(filteredAppointments) { appointment in
                        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
                            AppointmentRowView(appointment: appointment)
                                // Accessibility identifier for testing and analytics
                                .accessibilityIdentifier("AppointmentRow_\(appointment.id.uuidString)")
                        }
                    }
                }
            }
            // Use localized string key for navigation title to support localization
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
                        }
                    )
                    // Accessibility identifier for filter menu
                    .accessibilityIdentifier("AppointmentFilterMenu")
                }
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
                // Tokenized font for headline
                .font(AppFonts.headline)
            Text(appointment.status)
                // Tokenized font and secondary text color for subheadline
                .font(AppFonts.subheadline)
                .foregroundColor(AppColors.secondaryText)
            Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                // Tokenized font and tertiary text color for caption
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        // Tokenized vertical padding for consistent spacing
        .padding(.vertical, AppSpacing.small)
    }
}

// MARK: - AppointmentDetailView
struct AppointmentDetailView: View {
    let appointment: Appointment

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(LocalizedStringKey("Service: \(appointment.serviceType)"))
                // Tokenized font and bold style for title2
                .font(AppFonts.title2)
                .bold()
            Text(LocalizedStringKey("Status: \(appointment.status)"))
                // Tokenized font for headline
                .font(AppFonts.headline)
            Text(LocalizedStringKey("Date: \(appointment.date.formatted(date: .long, time: .shortened))"))
                // Tokenized font for subheadline
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
            // Example of token usage in preview for consistent design
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
