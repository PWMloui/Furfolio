//  RecurringAppointmentsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 17, 2025 — added full SwiftUI implementation for listing and managing recurring appointments.
//

import SwiftUI
import SwiftData

// TODO: Move recurrence-toggling and listing logic into a dedicated ViewModel for cleaner views and easier testing.

@MainActor
/// View showing all recurring appointments; allows toggling recurrence and launching an editor.
struct RecurringAppointmentsView: View {
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
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recurringAppointments) { appt in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(appt.formattedDate)
                                    .font(.headline)
                                Text(appt.serviceType.localized)
                                    .font(.subheadline)
                                if let freq = appt.recurrenceFrequency {
                                    Text("Repeats: \(freq.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appt.isRecurring },
                                set: { new in
                                    appt.isRecurring = new
                                }
                            ))
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingAppointment = appt
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
