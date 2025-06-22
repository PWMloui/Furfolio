//
//  AppointmentFilterMenu.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - AppointmentFilterMenu (Tokenized, Modular, Auditable Appointment Filter UI)

/**
 AppointmentFilterMenu is a modular, tokenized, and auditable filter UI component for appointments.
 It provides a comprehensive filtering interface for business analytics, supporting accessibility, localization, and seamless integration with UI design systems.
 The menu allows users to refine appointments by service type, status, and date range.
 */
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
                Picker("Service Type", selection: $selectedService) {
                    Text("All Services").tag(String?.none)
                    ForEach(serviceTypes, id: \.self) { service in
                        Text(service).tag(Optional(service))
                    }
                }
            }

            // MARK: Status Picker
            Section("Status") {
                Picker("Status", selection: $selectedStatus) {
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
                } label: {
                    Label("Select Date Range", systemImage: "calendar")
                }
            }

            // MARK: Reset Filters Button
            if hasActiveFilters {
                Section {
                    // Use a tokenized destructive color if available; TODO: Replace with actual design token if needed
                    Button("Reset Filters", role: .destructive) {
                        resetFilters()
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(IconOnlyLabelStyle())
                .font(AppFonts.title3) // Tokenized font for maintainability and design consistency
                .accessibilityLabel("Filter Appointments")
                .accessibilityAddTraits(.isButton)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            DateRangePickerView(dateRange: $dateRange)
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

// MARK: - Preview

#if DEBUG
struct AppointmentFilterMenu_Previews: PreviewProvider {
    @State static var serviceFilter: String? = nil
    @State static var statusFilter: String? = nil
    @State static var dateRangeFilter: ClosedRange<Date>? = nil

    static var previews: some View {
        // Demo/business/tokenized preview of AppointmentFilterMenu
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
