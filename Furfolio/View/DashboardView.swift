//  DashboardView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 5, 2025 — implemented summary cards, upcoming appointments, recent charges, quick actions, and previews.
//

import SwiftUI
import SwiftData
import os

// TODO: Move dashboard summary and filtering logic into a dedicated ViewModel; cache formatters to improve performance.

@MainActor
/// Root dashboard presenting summary cards, upcoming appointments, recent charges, and quick actions for all clients.
struct DashboardView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DashboardView")
    @Environment(\.modelContext) private var context

    /// Shared currency formatter for summary values.
    private static let currencyFormatter: NumberFormatter = {
      let fmt = NumberFormatter()
      fmt.numberStyle = .currency
      fmt.locale = .current
      return fmt
    }()

    /// Shared date formatter for appointment display.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .short
      return fmt
    }()

    // MARK: — All Owners
    @Query(nil, [SortDescriptor(\.ownerName)], nil) private var owners: [DogOwner]

    /// Allows injecting owners for previews or custom instantiation.
    init(owners: [DogOwner]) {
        _owners = .init(wrappedValue: owners)
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 16) {
            // MARK: — Summary Cards
            summaryCards()

            // MARK: — Upcoming Appointments
            upcomingAppointmentsSection()

            // MARK: — Recent Charges
            recentChargesSection()

            // MARK: — Quick Actions
            quickActionsSection()
          }
          .padding()
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger.log("DashboardView appeared: totalOwners=\(owners.count)")
        }
      }
    }

    // MARK: — Summary Cards

    /// Builds a horizontal scrollable set of summary cards aggregating client metrics.
    @ViewBuilder
    private func summaryCards() -> some View {
        // aggregate across all owners
        let allApps = owners.flatMap(\.appointments)
        let upcoming = allApps.filter { $0.date > .now }.count
        let totalCharges = owners.flatMap(\.charges).reduce(0) { $0 + $1.amount }
        let avgCharge = owners.flatMap(\.charges).map(Int(\.amount))
            .reduce(0, +) / max(1, owners.flatMap(\.charges).count)
        let totalClients = owners.count

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                summaryCard(title: "Clients", value: "\(totalClients)", color: .blue)
                summaryCard(title: "Upcoming Appts", value: "\(upcoming)", color: .green)
                summaryCard(title: "Total Revenue", value: formatCurrency(totalCharges), color: .purple)
                summaryCard(title: "Avg Charge", value: formatCurrency(avgCharge), color: .orange)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            logger.log("Summary cards displayed: Clients=\(totalClients), Upcoming=\(upcoming), Revenue=\(totalCharges), AvgCharge=\(avgCharge)")
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.caption)
                .foregroundColor(AppTheme.secondaryText)
            Text(value)
                .font(AppTheme.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.background)
                        .shadow(color: Color.black.opacity(0.2), radius: AppTheme.cornerRadius))
    }

    // MARK: — Upcoming Appointments

    /// Displays the next up to five upcoming appointments across all clients.
    @ViewBuilder
    private func upcomingAppointmentsSection() -> some View {
        let upcoming = owners
            .flatMap { owner in owner.appointments.map { ($0, owner) } }
            .filter { $0.0.date > .now }
            .sorted { $0.0.date < $1.0.date }
            .prefix(5)

        SectionBox(header: "Upcoming Appointments")
            .onAppear { logger.log("UpcomingAppointmentsSection displayed with count: \(upcoming.count)") } {
            if upcoming.isEmpty {
                EmptyStateView(
                  imageName: "calendar.badge.plus",
                  title: "No Upcoming Appointments",
                  message: "Tap below to add your first appointment.",
                  actionTitle: "Add Appointment"
                ) {
                  // Present add appointment for first owner
                  // Fallback if no owners: do nothing
                  if let first = owners.first {
                    // assuming AppState.activeSheet or similar; fallback to NavigationLink?
                    // For now, open via NavigationLink hack: navigate by pushing view (could use coordinator)
                  }
                }
            } else {
                ForEach(Array(upcoming), id: \.0.id) { appt, owner in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(owner.ownerName)
                                .font(AppTheme.body)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.primaryText)
                            Text(appt.formattedDate)
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text(appt.serviceType.localized)
                            .font(AppTheme.caption)
                            .padding(4)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: — Recent Charges

    /// Displays the most recent five charges across all clients.
    @ViewBuilder
    private func recentChargesSection() -> some View {
        let charges = owners.flatMap { owner in owner.charges.map { ($0, owner) } }
            .sorted { $0.0.date > $1.0.date }
            .prefix(5)

        SectionBox(header: "Recent Charges")
            .onAppear { logger.log("RecentChargesSection displayed with count: \(charges.count)") } {
            if charges.isEmpty {
                EmptyStateView(
                  imageName: "dollarsign.circle",
                  title: "No Charges Yet",
                  message: "Record a charge to track your revenue.",
                  actionTitle: "New Charge"
                ) {
                  if let first = owners.first {
                    // present AddChargeView
                  }
                }
            } else {
                ForEach(Array(charges), id: \.0.id) { charge, owner in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(owner.ownerName)
                                .font(AppTheme.body)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.primaryText)
                            Text(charge.formattedDate)
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text(charge.formattedAmount)
                            .font(AppTheme.caption)
                            .padding(4)
                            .background(AppTheme.info.opacity(0.1))
                            .cornerRadius(AppTheme.cornerRadius)
                            .foregroundColor(AppTheme.info)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: — Quick Actions

    /// Provides quick navigation buttons for common actions like adding appointments or charges.
    @ViewBuilder
    private func quickActionsSection() -> some View {
        SectionBox(header: "Quick Actions")
            .onAppear { logger.log("QuickActionsSection displayed") } {
            HStack(spacing: 12) {
                NavigationLink {
                    AddAppointmentView(dogOwner: owners.first!)
                } label: {
                    QuickActionButton(icon: "plus.circle", label: "New Appt")
                }
                NavigationLink {
                    AddChargeView(dogOwner: owners.first!)
                } label: {
                    QuickActionButton(icon: "dollarsign.circle", label: "New Charge")
                }
                NavigationLink {
                    ClientTimelineView(owner: owners.first!)
                } label: {
                    QuickActionButton(icon: "clock", label: "Timeline")
                }
            }
            .onAppear { logger.log("Displayed quick action buttons") }
        }
    }

    // MARK: — Helpers

    /// Formats a monetary value using the shared currencyFormatter.
    private func formatCurrency(_ value: Double) -> String {
      return Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: — SectionBox & QuickActionButton

@MainActor
/// A styled container with a header and content, used for dashboard sections.
private struct SectionBox<Content: View>: View {
    let header: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 1))
    }
}

@MainActor
/// A small button with an icon and label used for quick navigation actions.
private struct QuickActionButton: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTheme.header)
            Text(label)
                .font(AppTheme.caption)
                .foregroundColor(AppTheme.primaryText)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.disabled))
    }
}
