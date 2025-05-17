
//  MissedAppointmentsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 16, 2025 — added SwiftUI view to list and manage missed appointments.
//

import SwiftUI
import SwiftData

// TODO: Move missed-appointments retrieval and grouping logic into a dedicated ViewModel for cleaner views and testing.

@MainActor
/// Displays a list of past appointments that were not completed, grouped by owner.
struct MissedAppointmentsView: View {
    @Environment(\.modelContext) private var modelContext
    /// Shared date formatter for appointment display.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .short
      return fmt
    }()
    /// Shared calendar for date calculations.
    private static let calendar = Calendar.current
    
    /// Fetch appointments that were scheduled in the past but never completed.
    @Query(
        predicate: #Predicate {
            $0.date < Date.now && $0.status != .completed
        },
        sort: [ SortDescriptor(\.date, order: .reverse) ]
    )
    private var missedAppointments: [Appointment]
    
    /// Groups missed appointments by their associated DogOwner.
    /// Group missed appointments by owner for sectioned display
    private var groupedByOwner: [DogOwner: [Appointment]] {
        Dictionary(grouping: missedAppointments, by: \.dogOwner)
    }
    
    var body: some View {
      NavigationStack {
        List {
          if missedAppointments.isEmpty {
            Text("No missed appointments!")
              .foregroundColor(.secondary)
              .italic()
          } else {
            ForEach(Array(groupedByOwner.keys), id: \.id) { owner in
              Section(header: Text(owner.ownerName)) {
                ForEach(groupedByOwner[owner] ?? []) { appt in
                  MissedAppointmentRow(appointment: appt)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Missed Appointments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          Button("Refresh") {
            // simply triggers Query to re-fetch
          }
        }
      }
    }
}

@MainActor
/// A row representing a single missed appointment, showing details and a reschedule action.
private struct MissedAppointmentRow: View {
    @Bindable var appointment: Appointment
    @Environment(\.modelContext) private var modelContext
    @State private var showRescheduleSheet = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(appointment.formattedDate)
                    .font(.headline)
                    .accessibilityLabel("Date: \(appointment.formattedDate)")
                Text(appointment.serviceType.localized)
                    .font(.subheadline)
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Reschedule") {
                showRescheduleSheet = true
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showRescheduleSheet) {
                RescheduleView(appointment: $appointment)
                    .presentationDetents([.medium])
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
/// View for selecting a new date/time to reschedule a missed appointment.
struct RescheduleView: View {
    @Binding var appointment: Appointment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var newDate: Date
    
    init(appointment: Binding<Appointment>) {
        _appointment = appointment
        // default to one week later or now
        _newDate = State(initialValue: max(Date.now, appointment.wrappedValue.date))
    }
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker(
                    "New Date & Time",
                    selection: $newDate,
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .navigationTitle("Reschedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appointment.date = newDate
                        appointment.status = .confirmed
                        dismiss()
                    }
                    .disabled(newDate <= Date.now)
                }
            }
        }
    }
}

#if DEBUG
struct MissedAppointmentsView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [DogOwner.self, Appointment.self],
            modelConfiguration: config
        )
    }()
    
    static var previews: some View {
        let ctx = container.mainContext
        // Insert sample owners & appointments
        let owner1 = DogOwner.sample
        ctx.insert(owner1)
        Appointment.create(
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date.now)!,
            dogOwner: owner1,
            serviceType: .basic,
            in: ctx
        )
        Appointment.create(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!,
            dogOwner: owner1,
            serviceType: .full,
            status: .cancelled,
            in: ctx
        )
        
        return MissedAppointmentsView()
            .environment(\.modelContext, ctx)
    }
}
#endif
