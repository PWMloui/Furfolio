//  RecurringAppointmentsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 17, 2025 — added full SwiftUI implementation for listing and managing recurring appointments.
//

import SwiftUI
import SwiftData
import os

// TODO: Move recurrence-toggling and listing logic into a dedicated ViewModel for cleaner views and easier testing.

@MainActor
/// View showing all recurring appointments; allows toggling recurrence and launching an editor.
struct RecurringAppointmentsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "RecurringAppointmentsView")
    /// Shared formatter for displaying appointment dates.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    /// Shared calendar for date calculations.
    private static let calendar = Calendar.current

    @Environment(\.modelContext) private var modelContext

    /// Fetches all recurring appointments, sorted by next occurrence date.
    @Query(
        predicate: #Predicate { $0.isRecurring == true },
        sort: [ SortDescriptor(\.date, order: .forward) ]
    )
    private var recurringAppointments: [Appointment]

    @State private var editingAppointment: Appointment?

    /// Main content: a list of recurring appointments or a placeholder when none exist.
    var body: some View {
        NavigationStack {
            List {
                if recurringAppointments.isEmpty {
                    Text("No recurring appointments set up.")
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.secondaryText)
                } else {
                    ForEach(recurringAppointments) { appt in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(appt.formattedDate)
                                    .font(AppTheme.body)
                                    .foregroundColor(AppTheme.primaryText)
                                Text(appt.serviceType.localized)
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                                if let freq = appt.recurrenceFrequency {
                                    Text("Repeats: \(freq.rawValue)")
                                        .font(AppTheme.caption)
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appt.isRecurring },
                                set: { newValue in
                                    appt.isRecurring = newValue
                                    logger.log("Toggled isRecurring for appointment id: \(appt.id) to \(newValue)")
                                }
                            ))
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingAppointment = appt
                        }
                        .onAppear {
                            logger.log("Displaying recurring appointment id: \(appt.id), date: \(Self.dateFormatter.string(from: appt.date))")
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recurring Appointments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
            .sheet(item: $editingAppointment) { appt in
                RecurrenceEditor(appointment: appt)
                    .environment(\.modelContext, modelContext)
            }
        }
        .onAppear {
            logger.log("RecurringAppointmentsView appeared; recurringCount=\(recurringAppointments.count)")
        }
    }

    /// Deletes the selected recurring appointments from the model context.
    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(recurringAppointments[idx])
        }
    }
}

@MainActor
/// Sheet view for editing an appointment’s recurrence settings.
private struct RecurrenceEditor: View {
    @Bindable var appointment: Appointment
    @Environment(\.dismiss) private var dismiss

    /// Form for toggling recurrence and selecting frequency and next date.
    var body: some View {
        NavigationStack {
            Form {
                Section("Recurrence") {
                    Toggle("Is Recurring", isOn: $appointment.isRecurring)
                    if appointment.isRecurring {
                        Picker("Frequency", selection: $appointment.recurrenceFrequency) {
                            Text("Daily").tag(Appointment.RecurrenceFrequency.daily as Appointment.RecurrenceFrequency?)
                            Text("Weekly").tag(Appointment.RecurrenceFrequency.weekly as Appointment.RecurrenceFrequency?)
                            Text("Monthly").tag(Appointment.RecurrenceFrequency.monthly as Appointment.RecurrenceFrequency?)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("Next Date") {
                    DatePicker(
                        "Next Occurrence",
                        selection: Binding(
                            get: { appointment.date },
                            set: { appointment.date = $0 }
                        ),
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("Edit Recurrence")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct RecurringAppointmentsView_Previews: PreviewProvider {
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
        // sample recurring appointments
        Appointment.create(
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!,
            dogOwner: owner,
            serviceType: .basic,
            isRecurring: true,
            recurrenceFrequency: .weekly,
            in: ctx
        )
        Appointment.create(
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date.now)!,
            dogOwner: owner,
            serviceType: .full,
            isRecurring: true,
            recurrenceFrequency: .monthly,
            in: ctx
        )

        return RecurringAppointmentsView()
            .environment(\.modelContext, ctx)
    }
}
#endif
