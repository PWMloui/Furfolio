//
//  ContentView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 6, 2025 — fixed Section initializers, Query definitions, replaced owner properties with ClientStats, and polished UI.

import SwiftUI
import SwiftData
import UserNotifications
import os

// TODO: Move authentication, filtering, and data-fetching logic into a dedicated ViewModel for cleaner views and easier testing.

@MainActor
/// Root view managing authentication state and presenting the main navigation for Furfolio.
struct ContentView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ContentView")
    @Environment(\.modelContext) private var modelContext

    // Provide sort descriptors with explicit root types
    @Query(sort: \DogOwner.ownerName, order: .forward) private var dogOwners: [DogOwner]
    @Query(sort: \DailyRevenue.date,   order: .reverse) private var dailyRevenues: [DailyRevenue]

    // Authentication states
    @State private var isAuthenticated = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var authenticationError: String? = nil

    // Search functionality
    @State private var searchText = ""

    // Sheet toggles
    @State private var isShowingAddOwnerSheet = false
    @State private var isShowingMetricsView = false

    // Selected detail
    @State private var selectedDogOwner: DogOwner? = nil

    // Filtering
    @State private var selectedFilter: String = "All"
    private let filterOptions = ["All", "Active", "Inactive", "New"]

    /// Shared date formatter for displaying appointment dates.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .short
      return fmt
    }()
    /// Shared calendar for date calculations.
    private static let calendar = Calendar.current

    var body: some View {
        Group {
            if isAuthenticated {
                authenticatedView
            } else {
                LoginView(isAuthenticated: $isAuthenticated, authenticationError: $authenticationError)
            }
        }
        .animation(.easeInOut, value: isAuthenticated)
        .onAppear {
            logger.log("ContentView appeared; isAuthenticated=\(isAuthenticated)")
        }
    }

    private var authenticatedView: some View {
      NavigationSplitView {
        List {
          businessInsightsSection()
          upcomingAppointmentsSection()
          dogOwnersSection()
        }
        .navigationTitle("Furfolio")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .onAppear {
            logger.log("Authenticated view loaded with \(dogOwners.count) owners and \(dailyRevenues.count) revenues")
        }
        .listStyle(.insetGrouped)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              logger.log("Add Dog Owner tapped")
              withAnimation { isShowingAddOwnerSheet = true }
            } label: {
              Label("Add Dog Owner", systemImage: "plus")
            }
          }
        }
        .sheet(isPresented: $isShowingAddOwnerSheet) {
          AddDogOwnerView { ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, birthdate in
            addDogOwner(
              ownerName: ownerName,
              dogName: dogName,
              breed: breed,
              contactInfo: contactInfo,
              address: address,
              notes: notes,
              selectedImageData: selectedImageData,
              birthdate: birthdate
            )
          }
        }
        .sheet(isPresented: $isShowingMetricsView) {
          MetricsDashboardView(
            dailyRevenues: dailyRevenues,
            appointments: dogOwners.flatMap { $0.appointments },
            charges: dogOwners.flatMap { $0.charges }
          )
        }
      } detail: {
        if let owner = selectedDogOwner {
          OwnerProfileView(dogOwner: owner)
        } else {
          emptyDetailView
        }
      }
    }

    // ... rest of your ContentView unchanged ...
}
    // MARK: – Sections
    
    @ViewBuilder
    private func businessInsightsSection() -> some View {
        Section {
            Button {
                logger.log("View Metrics Dashboard tapped")
                withAnimation { isShowingMetricsView = true }
            } label: {
                Label("View Metrics Dashboard", systemImage: "chart.bar.xaxis")
            }
        } header: {
            Text("Business Insights")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
        }
    }
    
    @ViewBuilder
    private func upcomingAppointmentsSection() -> some View {
        let upcoming = fetchUpcomingAppointments()
        Section {
            if upcoming.isEmpty {
                Text("No upcoming appointments.")
                    .foregroundColor(AppTheme.secondaryText)
                    .italic()
                    .font(AppTheme.body)
            } else {
                ForEach(upcoming) { appt in
                    logger.log("Navigating to appointment row for appointment id: \(appt.id)")
                    if let owner = findOwner(for: appt) {
                        NavigationLink(value: owner) {
                            appointmentRow(for: appt, owner: owner)
                        }
                    }
                }
            }
        } header: {
            Text("Upcoming Appointments")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
        }
    }
    
    @ViewBuilder
    private func dogOwnersSection() -> some View {
        Section {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(filterOptions, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedFilter) { new in
                logger.log("Dog owner filter changed to: \(new)")
            }

            let filtered = filterDogOwners()
            if filtered.isEmpty {
                EmptyStateView(
                    imageName: "person.3.fill",
                    title: "No Dog Owners",
                    message: "Tap + to add your first dog owner.",
                    actionTitle: "Add Owner",
                    action: { isShowingAddOwnerSheet = true }
                )
                .font(AppTheme.body)
                .foregroundColor(AppTheme.secondaryText)
            } else {
                ForEach(filtered) { owner in
                    NavigationLink(value: owner) {
                        DogOwnerRowView(selectedOwner: $selectedDogOwner, dogOwner: owner)
                    }
                }
                .onDelete(perform: deleteDogOwners)
            }
        } header: {
            Text("Dog Owners")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
        }
    }
    
    private var emptyDetailView: some View {
        VStack {
            Text("Select a dog owner to view details.")
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding()
                .font(AppTheme.body)
            Image(systemName: "person.crop.circle.badge.questionmark")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.gray.opacity(0.5))
        }
    }
    
    // MARK: – Data Fetching & Helpers
    
    /// Fetches appointments occurring within the next 7 days.
    private func fetchUpcomingAppointments() -> [Appointment] {
      let today = Date.now
      let endDate = Self.calendar.date(byAdding: .day, value: 7, to: today) ?? today
      return dogOwners
        .flatMap { $0.appointments }
        .filter { $0.date > today && $0.date <= endDate }
        .sorted { $0.date < $1.date }
    }

    /// Finds the DogOwner associated with the given appointment.
    private func findOwner(for appointment: Appointment) -> DogOwner? {
      dogOwners.first { $0.appointments.contains(appointment) }
    }

    /// Filters dog owners by search text and selected filter option.
    private func filterDogOwners() -> [DogOwner] {
      let text = searchText
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      let base = dogOwners.filter {
        text.isEmpty
        || $0.ownerName.lowercased().contains(text)
        || $0.dogName.lowercased().contains(text)
        || $0.breed.lowercased().contains(text)
        || $0.address.lowercased().contains(text)
        || $0.notes.lowercased().contains(text)
      }
      switch selectedFilter {
      case "Active":   return base.filter { $0.isActive }
      case "Inactive": return base.filter { $0.isInactive }
      case "New":      return base.filter { $0.appointments.isEmpty }
      default:         return base
      }
    }

    /// Creates and inserts a new DogOwner with the provided details.
    private func addDogOwner(
      ownerName: String,
      dogName: String,
      breed: String,
      contactInfo: String,
      address: String,
      notes: String,
      selectedImageData: Data?,
      birthdate: Date?
    ) {
      logger.log("Adding DogOwner: ownerName=\(ownerName), dogName=\(dogName)")
      withAnimation {
        let newOwner = DogOwner(
          ownerName: ownerName,
          dogName: dogName,
          breed: breed,
          contactInfo: contactInfo,
          address: address,
          notes: notes,
          birthdate: birthdate
        )
        modelContext.insert(newOwner)
      }
    }

    /// Deletes dog owners at the specified offsets, handling selection state.
    private func deleteDogOwners(offsets: IndexSet) {
      logger.log("Deleting DogOwners at offsets: \(offsets)")
      withAnimation {
        offsets.forEach { i in
          let owner = dogOwners[i]
          if selectedDogOwner == owner {
            selectedDogOwner = nil
          }
          modelContext.delete(owner)
        }
      }
    }
    
    // MARK: – Row View
    
    @ViewBuilder
    /// Renders a row representing an upcoming appointment for an owner, including name, date, service, and badges.
    private func appointmentRow(for appointment: Appointment, owner: DogOwner) -> some View {
      let stats = ClientStats(owner: owner)
      VStack(alignment: .leading, spacing: 4) {
        Text(owner.ownerName)
          .font(.headline)
        Text("Next: \(appointment.date.formatted(.dateTime.month().day().hour().minute()))")
          .font(.subheadline)
          .foregroundColor(.secondary)
        // ← Updated here
        Text("Service: \(appointment.serviceType.localized)")
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack(spacing: 8) {
          Text(stats.loyaltyProgressTag)
            .font(.caption2)
            .padding(4)
            .background(Color.green.opacity(0.15))
            .cornerRadius(6)
          if let badge = stats.recentBehaviorBadges.first {
            Text(badge)
              .font(.caption2)
              .padding(4)
              .background(Color.orange.opacity(0.15))
              .cornerRadius(6)
          }
        }
      }
      .padding(.vertical, 4)
    }
