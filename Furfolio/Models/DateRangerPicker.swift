//
//  DateRangePicker.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//  Updated on 07/09/2025 — sync non-custom ranges, show active interval.
//

import SwiftUI



private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        let start = Calendar.current.startOfDay(for: self)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
    }
}

@MainActor
/// A picker allowing selection of predefined or custom date ranges, syncing custom dates with the chosen range.
struct DateRangePicker: View {
    /// Shared short‐date formatter to avoid repeated allocations.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        return fmt
    }()

    /// The currently selected date range.
    @Binding var selectedDateRange: DateRange
    /// Whether custom date pickers should be shown.
    @Binding var isCustomDateRangeActive: Bool
    /// Start date for the custom range.
    @Binding var customStartDate: Date
    /// End date for the custom range.
    @Binding var customEndDate: Date

    /// Text displaying the currently active interval (start – end) for non-custom ranges.
    private var activeIntervalText: String {
        guard let interval = selectedDateRange.interval else { return "" }
        let fmt = Self.dateFormatter
        return "\(fmt.string(from: interval.start.startOfDay)) – \(fmt.string(from: interval.end.endOfDay))"
    }

    /// The view body containing a segmented picker and conditional date pickers or interval display.
    var body: some View {
        Section(header: Text("Date Range")) {
            Picker("Range", selection: $selectedDateRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedDateRange) { new in
                // Activate custom pickers only for .custom
                isCustomDateRangeActive = (new == .custom)

                // Seed custom dates when switching to a predefined range
                if let interval = new.interval {
                    customStartDate = interval.start.startOfDay
                    customEndDate   = interval.end.endOfDay
                }
            }

            if isCustomDateRangeActive {
                Group {
                    DatePicker(
                        "Start Date",
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )
                    .accessibilityLabel("Start Date Picker")
                    DatePicker(
                        "End Date",
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityLabel("End Date Picker")
                }
                .labelsHidden()
                .animation(.default, value: isCustomDateRangeActive)
            } else {
                // Show the currently active interval
                HStack {
                    Text("Active:")
                    Spacer()
                    Text(activeIntervalText)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Active interval from \(activeIntervalText)")
            }
        }
    }
}
