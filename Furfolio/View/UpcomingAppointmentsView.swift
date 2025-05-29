//
//  UpcomingAppointmentsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 18, 2025 — added fetch, grouping by day, and full SwiftUI implementation.
//

import SwiftUI
import SwiftData
import os

// TODO: Move upcoming appointments fetching and grouping logic into a dedicated ViewModel for cleaner views and easier testing.

@MainActor
class UpcomingAppointmentsViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "UpcomingAppointmentsViewModel")
    @Published var groupedByDay: [(day: Date, appts: [Appointment])] = []

    private static let calendar = Calendar.current

    init(appointments: [Appointment]) {
        updateGroupings(with: appointments)
        logger.log("Initialized with \(appointments.count) appointments")
    }

    func updateGroupings(with upcoming: [Appointment]) {
        logger.log("updateGroupings called with \(upcoming.count) upcoming appointments")
        let dict = Dictionary(grouping: upcoming) { appt in
            Self.calendar.startOfDay(for: appt.date)
        }
        self.groupedByDay = dict
            .map { (day: $0.key, appts: $0.value) }
            .sorted { $0.day < $1.day }
        logger.log("Grouped into \(groupedByDay.count) days")
    }
}

@MainActor
/// View displaying upcoming (future) appointments grouped by calendar day.
struct UpcomingAppointmentsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "UpcomingAppointmentsView")
    @Environment(\.modelContext) private var modelContext

    /// Fetch appointments with date ≥ now, excluding cancelled, sorted ascending
    @Query(
        predicate: #Predicate {
            $0.date >= Date.now && $0.status != .cancelled
        },
        sort: [ SortDescriptor(\Appointment.date, order: .forward) ]
    )
    private var upcoming: [Appointment]

    @StateObject private var viewModel: UpcomingAppointmentsViewModel

    init() {
        let initialAppointments: [Appointment] = []
        _viewModel = StateObject(wrappedValue: UpcomingAppointmentsViewModel(appointments: initialAppointments))
    }

    /// Shared calendar and section header formatter.
    private static let calendar = Calendar.current
    private static let headerDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        return fmt
    }()

    var body: some View {
        NavigationStack {
            List {
                if upcoming.isEmpty {
                    Text("No upcoming appointments.")
                        .foregroundColor(AppTheme.secondaryText)
                        .font(AppTheme.body)
                        .italic()
                } else {
                    ForEach(viewModel.groupedByDay, id: \.day) { group in
                        Section(header: Text(headerText(for: group.day))) {
                            ForEach(group.appts) { appt in
                                AppointmentRow(appointment: appt)
                            }
                            .onDelete { offsets in
                                for idx in offsets {
                                    modelContext.delete(group.appts[idx])
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Upcoming Appointments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
        }
        .onAppear {
            logger.log("UpcomingAppointmentsView appeared with \(upcoming.count) appointments fetched")
        }
        .onAppear {
            viewModel.updateGroupings(with: upcoming)
            logger.log("View onAppear updated groupings")
        }
        .onChange(of: upcoming) { newValue in
            viewModel.updateGroupings(with: newValue)
            logger.log("Upcoming change detected: \(newValue.count) appointments")
        }
    }

    /// Formats a Date as a section header, e.g. "May 20, 2025"
    private func headerText(for day: Date) -> String {
        return Self.headerDateFormatter.string(from: day)
    }
}

@MainActor
/// Row showing basic details of a single appointment, with status toggle.
private struct AppointmentRow: View {
    private let rowLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentRow")
    @Bindable var appointment: Appointment

    var body: some View {
        rowLogger.log("Rendering AppointmentRow for id: \(appointment.id), status: \(appointment.status.rawValue)")
        HStack {
            VStack(alignment: .leading) {
                Text(appointment.formattedDate)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                Text(appointment.serviceType.localized)
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.secondaryText)
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                        .italic()
                }
            }
            Spacer()
            if appointment.status == .confirmed {
                Button {
                    rowLogger.log("Marking appointment \(appointment.id) as completed")
                    appointment.status = .completed
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(FurfolioButtonStyle())
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct UpcomingAppointmentsView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [DogOwner.self, Appointment.self],
            modelConfiguration: config
        )
    }()
    static var previews: some View {
        let ctx = container.mainContext
        let owner = DogOwner.sample
        ctx.insert(owner)
        // sample future appointments
        let now = Date.now
        Appointment.create(date: Calendar.current.date(byAdding: .hour, value: 2, to: now)!, dogOwner: owner, serviceType: .basic, in: ctx)
        Appointment.create(date: Calendar.current.date(byAdding: .day, value: 1, to: now)!, dogOwner: owner, serviceType: .full, in: ctx)
        Appointment.create(date: Calendar.current.date(byAdding: .day, value: 1, to: now)!, dogOwner: owner, serviceType: .custom, in: ctx)
        return UpcomingAppointmentsView()
            .environment(\.modelContext, ctx)
    }
}
#endif
