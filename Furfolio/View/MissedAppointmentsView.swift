//  MissedAppointmentsView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on May 16, 2025 — added SwiftUI view to list and manage missed appointments.
//

import SwiftUI
import SwiftData
import os

// TODO: Move missed-appointments retrieval and grouping logic into a dedicated ViewModel for cleaner views and testing.

@MainActor
/// Displays a list of past appointments that were not completed, grouped by owner.
struct MissedAppointmentsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MissedAppointmentsView")
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
              .foregroundColor(AppTheme.secondaryText)
              .font(AppTheme.body)
              .italic()
          } else {
            ForEach(Array(groupedByOwner.keys), id: \.id) { owner in
              Section(header:
                        Text(owner.ownerName)
                          .font(AppTheme.title)
                          .foregroundColor(AppTheme.primaryText)
              ) {
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
      .onAppear {
        logger.log("MissedAppointmentsView appeared; total missed=\(missedAppointments.count)")
      }
    }
}

@MainActor
/// A row representing a single missed appointment, showing details and a reschedule action.
import os
private struct MissedAppointmentRow: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MissedAppointmentRowView")
    @Bindable var appointment: Appointment
    @Environment(\.modelContext) private var modelContext
    @State private var showRescheduleSheet = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(appointment.formattedDate)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                    .accessibilityLabel("Date: \(appointment.formattedDate)")
                Text(appointment.serviceType.localized)
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.secondaryText)
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            Spacer()
            Button("Reschedule") {
                logger.log("Reschedule tapped for appointment id: \(appointment.id)")
                showRescheduleSheet = true
            }
            .buttonStyle(FurfolioButtonStyle())
            .sheet(isPresented: $showRescheduleSheet) {
                RescheduleView(appointment: $appointment)
                    .presentationDetents([.medium])
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            logger.log("Displaying missed appointment row for id: \(appointment.id)")
        }
    }
}

@MainActor
/// View for selecting a new date/time to reschedule a missed appointment.
struct RescheduleView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "RescheduleView")
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
            .onAppear {
                logger.log("RescheduleView appeared for appointment id: \(appointment.id)")
            }
            .navigationTitle("Reschedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        logger.log("Reschedule Cancel tapped")
                        dismiss()
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        logger.log("Reschedule Save tapped: newDate=\(newDate)")
                        appointment.date = newDate
                        appointment.status = .confirmed
                        dismiss()
                    }
                    .disabled(newDate <= Date.now)
                    .buttonStyle(FurfolioButtonStyle())
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
