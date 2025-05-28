//
//  CalendarMonthView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//


import SwiftUI

struct CalendarMonthView: View {
    @Binding var displayedMonth: Date
    let onSelectDate: ((Date) -> Void)?
    private let calendar = Calendar.current
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: 7)

    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekdayOffset = calendar.component(.weekday, from: firstWeekday) - calendar.firstWeekday
        let leadingEmptyDays = (weekdayOffset + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: displayedMonth) ?? 1...28
        var dates: [Date] = []

        // Add empty days for the first week
        for i in 0..<leadingEmptyDays {
            dates.append(calendar.date(byAdding: .day, value: i - leadingEmptyDays, to: firstWeekday)!)
        }
        // Add days of the month
        for day in days {
            if let date = calendar.date(bySetting: .day, value: day, of: displayedMonth) {
                dates.append(date)
            }
        }
        // Fill trailing days to complete the last week
        while dates.count % 7 != 0 {
            if let date = dates.last,
               let next = calendar.date(byAdding: .day, value: 1, to: date) {
                dates.append(next)
            }
        }
        return dates
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weekdayInitials: [String] {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        return formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    if let prevMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prevMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .padding(8)
                }
                Spacer()
                Text(monthYearString)
                    .font(.headline)
                Spacer()
                Button(action: {
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = nextMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .padding(8)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdayInitials.indices, id: \.self) { idx in
                    Text(weekdayInitials[(idx + calendar.firstWeekday - 1) % 7])
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }

            // Days grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    let isToday = calendar.isDateInToday(date)
                    Button(action: {
                        if isCurrentMonth {
                            onSelectDate?(date)
                        }
                    }) {
                        ZStack {
                            if isToday && isCurrentMonth {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 32, height: 32)
                            }
                            Text("\(calendar.component(.day, from: date))")
                                .font(.body)
                                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isCurrentMonth)
                }
            }
        }
        .padding()
    }
}

struct CalendarMonthView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var month = Date()
        var body: some View {
            CalendarMonthView(displayedMonth: $month, onSelectDate: { _ in })
        }
    }
    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
