
//  QuickAddMenuView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 16, 2025 — added full SwiftUI quick-add menu with sheets for core actions.
//


import SwiftUI
import SwiftData

// TODO: Move presentation state and quick-add action logic into QuickAddMenuViewModel for better separation of concerns.

@MainActor
/// View presenting a grid of quick-add actions (owner, appointment, charge, behavior log).
struct QuickAddMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Sheet presentation states
    @State private var showingAddOwner = false
    @State private var showingAddAppointment = false
    @State private var showingAddCharge = false
    @State private var showingLogBehavior = false

    /// Pass in your existing owners so you can choose one for appointment/charge.
    let dogOwners: [DogOwner]

    var body: some View {
      NavigationStack {
        /// Defines adaptive grid layout for quick-action buttons.
        private static let gridColumns = [GridItem(.adaptive(minimum: 100), spacing: 20)]
        VStack(spacing: 24) {
          Text("Quick Actions")
            .font(.title2)
            .bold()
            .padding(.top)

          LazyVGrid(columns: Self.gridColumns, spacing: 20) {
            /// Quick-add a new dog owner.
            Button {
              showingAddOwner = true
            } label: {
              VStack {
                Image(systemName: "person.crop.circle.badge.plus")
                  .font(.largeTitle)
                Text("New Owner")
                  .font(.caption)
              }
            }
            .sheet(isPresented: $showingAddOwner) {
              AddDogOwnerView()
                .environment(\.modelContext, modelContext)
            }
            .buttonStyle(PlainButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Quick-add a new appointment.
            Button {
              showingAddAppointment = true
            } label: {
              VStack {
                Image(systemName: "calendar.badge.plus")
                  .font(.largeTitle)
                Text("Appointment")
                  .font(.caption)
              }
            }
            .sheet(isPresented: $showingAddAppointment) {
              if let owner = dogOwners.first {
                AddAppointmentView(dogOwner: owner)
                  .environment(\.modelContext, modelContext)
              } else {
                Text("No owner selected")
              }
            }
            .buttonStyle(PlainButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Quick-add a new charge.
            Button {
              showingAddCharge = true
            } label: {
              VStack {
                Image(systemName: "creditcard.fill")
                  .font(.largeTitle)
                Text("Charge")
                  .font(.caption)
              }
            }
            .sheet(isPresented: $showingAddCharge) {
              if let owner = dogOwners.first {
                AddChargeView(dogOwner: owner)
                  .environment(\.modelContext, modelContext)
              } else {
                Text("No owner selected")
              }
            }
            .buttonStyle(PlainButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Log a new behavior.
            Button {
              showingLogBehavior = true
            } label: {
              VStack {
                Image(systemName: "exclamationmark.bubble.fill")
                  .font(.largeTitle)
                Text("Log Behavior")
                  .font(.caption)
              }
            }
            .sheet(isPresented: $showingLogBehavior) {
              if let owner = dogOwners.first {
                BehaviorBadgeEditorView(dogOwner: owner)
                  .environment(\.modelContext, modelContext)
              } else {
                Text("No owner selected")
              }
            }
            .buttonStyle(PlainButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)
          }
          Spacer()
        }
        .padding()
        .navigationTitle("Quick Add")
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
              dismiss()
            }
          }
        }
        .animation(.easeInOut, value: showingAddOwner)
        .animation(.easeInOut, value: showingAddAppointment)
        .animation(.easeInOut, value: showingAddCharge)
        .animation(.easeInOut, value: showingLogBehavior)
      }
    }
}

#if DEBUG
struct QuickAddMenuView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [DogOwner.self, Appointment.self, Charge.self],
            modelConfiguration: config
        )
    }()
    static var previews: some View {
        let ctx = container.mainContext
        // create a sample owner
        let owner = DogOwner.sample
        ctx.insert(owner)

        return QuickAddMenuView(dogOwners: [owner])
            .environment(\.modelContext, ctx)
    }
}
#endif
