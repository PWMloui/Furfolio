//
//  PopularServicesView.swift
//  Furfolio
//
//  Created by ChatGPT on 05/15/2025.
//  Shows most frequently booked service types in descending order.
//
import SwiftUI
import SwiftData
import os

@MainActor
/// Displays the service types most frequently booked, in descending order of count.
struct PopularServicesView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PopularServicesView")
    @StateObject private var viewModel = PopularServicesViewModel()
    @Query(
        predicate: nil,
        sort: [ SortDescriptor(\Appointment.date, order: .forward) ]
    )
    private var appointments: [Appointment]

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Popular Services")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ) {
                    ForEach(viewModel.serviceFrequency, id: \.type) { entry in
                        HStack {
                            Text(entry.type.localized)
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.primaryText)
                            Spacer()
                            Text("\(entry.count) bookings")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                        .cardStyle()
                    }
                }
                .onAppear {
                    logger.log("Rendering Popular Services list")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Popular Services")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.update(from: appointments) }
        .onChange(of: appointments) { newAppointments in
            viewModel.update(from: newAppointments)
        }
        .onAppear {
            logger.log("PopularServicesView appeared with \(viewModel.serviceFrequency.count) services and \(appointments.count) appointments")
        }
    }
}

#if DEBUG
struct PopularServicesView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        // In‐memory container for previews
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: Appointment.self, DogOwner.self,
            modelConfiguration: config
        )
    }()

    static var previews: some View {
        let ctx = container.mainContext

        // Create a sample owner
        let owner = DogOwner(
            ownerName: "Jane Doe",
            dogName: "Rex",
            breed: "Labrador",
            contactInfo: "jane@example.com",
            address: "123 Bark St."
        )
        ctx.insert(owner)

        // Insert three appointments
        ctx.insert(Appointment(
            date: Date.now,
            dogOwner: owner,
            serviceType: .basic
        ))
        ctx.insert(Appointment(
            date: Date.now.addingTimeInterval(3_600),
            dogOwner: owner,
            serviceType: .full
        ))
        ctx.insert(Appointment(
            date: Date.now.addingTimeInterval(7_200),
            dogOwner: owner,
            serviceType: .basic
        ))

        return PopularServicesView()
            .environment(\.modelContext, ctx)
    }
}
#endif
