//  QuickAddMenuView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 16, 2025 — added full SwiftUI quick-add menu with sheets for core actions.
//

import SwiftUI
import SwiftData
import QuickAddMenuViewModel
import os

@MainActor
/// View presenting a grid of quick-add actions (owner, appointment, charge, behavior log).
struct QuickAddMenuView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "QuickAddMenuView")
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: QuickAddMenuViewModel

    /// Pass in your existing owners so you can choose one for appointment/charge.
    let dogOwners: [DogOwner]

    private static let gridColumns = [GridItem(.adaptive(minimum: 100), spacing: 20)]

    init(dogOwners: [DogOwner], modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: QuickAddMenuViewModel(dogOwners: dogOwners, modelContext: modelContext))
        self.dogOwners = dogOwners
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 24) {
          Text("Quick Actions")
            .font(AppTheme.header)
            .foregroundColor(AppTheme.primaryText)
            .padding(.top)

          LazyVGrid(columns: Self.gridColumns, spacing: 20) {
            /// Quick-add a new dog owner.
            Button {
              logger.log("QuickAdd: New Owner tapped")
              viewModel.showOwner()
            } label: {
              VStack {
                Image(systemName: "person.crop.circle.badge.plus")
                  .font(.largeTitle)
                Text("New Owner")
                  .font(.caption)
              }
            }
            .buttonStyle(FurfolioButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Quick-add a new appointment.
            Button {
              logger.log("QuickAdd: Appointment tapped")
              viewModel.showAppointment()
            } label: {
              VStack {
                Image(systemName: "calendar.badge.plus")
                  .font(.largeTitle)
                Text("Appointment")
                  .font(.caption)
              }
            }
            .buttonStyle(FurfolioButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Quick-add a new charge.
            Button {
              logger.log("QuickAdd: Charge tapped")
              viewModel.showCharge()
            } label: {
              VStack {
                Image(systemName: "creditcard.fill")
                  .font(.largeTitle)
                Text("Charge")
                  .font(.caption)
              }
            }
            .buttonStyle(FurfolioButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)

            /// Log a new behavior.
            Button {
              logger.log("QuickAdd: Log Behavior tapped")
              viewModel.showBehavior()
            } label: {
              VStack {
                Image(systemName: "exclamationmark.bubble.fill")
                  .font(.largeTitle)
                Text("Log Behavior")
                  .font(.caption)
              }
            }
            .buttonStyle(FurfolioButtonStyle())
            .cardStyle()
            .accessibilityElement(children: .combine)
          }
          Spacer()
        }
        .padding()
        .navigationTitle("Quick Add")
        .onAppear {
          logger.log("QuickAddMenuView appeared with \(dogOwners.count) owners")
        }
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
              dismiss()
            }
          }
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
          switch sheet {
          case .addOwner:
            AddDogOwnerView()
              .environment(\.modelContext, modelContext)
          case .addAppointment:
            if let owner = dogOwners.first {
              AddAppointmentView(dogOwner: owner)
                .environment(\.modelContext, modelContext)
            } else {
              Text("No owner selected")
            }
          case .addCharge:
            if let owner = dogOwners.first {
              AddChargeView(dogOwner: owner)
                .environment(\.modelContext, modelContext)
            } else {
              Text("No owner selected")
            }
          case .logBehavior:
            if let owner = dogOwners.first {
              BehaviorBadgeEditorView(dogOwner: owner)
                .environment(\.modelContext, modelContext)
            } else {
              Text("No owner selected")
            }
          }
        }
        .animation(.easeInOut, value: viewModel.activeSheet)
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

        return QuickAddMenuView(dogOwners: [owner], modelContext: ctx)
            .environment(\.modelContext, ctx)
    }
}
#endif
