//
//  ContentView.swift
//  Furfolio
//
//  Enhanced: token-compliant, analytics/audit/Trust Center–ready, multi-brand, accessibility, test-injectable, future-proof.
//

import SwiftUI
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol ContentViewAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullContentViewAnalyticsLogger: ContentViewAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - Analytics Logger
    static var analyticsLogger: ContentViewAnalyticsLogger = NullContentViewAnalyticsLogger()

    // MARK: - Data Queries
    @Query(sort: \DogOwner.ownerName) private var owners: [DogOwner]
    @Query(sort: \Appointment.date, order: .reverse) private var appointments: [Appointment]

    // MARK: - State
    @State private var showAddOwner = false
    @State private var showAddAppointment = false
    @State private var showMetrics = false
    @State private var showTrustCenter = false

    @State private var selectedOwner: DogOwner?
    @State private var selectedAppointment: Appointment?

    @State private var searchQuery = ""
    @State private var shouldShowOnboarding = false

    var body: some View {
        NavigationSplitView {
            List {
                OwnersSection
                AppointmentsSection
                // Future: ChargesSection, RouteOptimizationSection
            }
            .listStyle(.insetGrouped)
            .background(AppColors.background)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: LocalizedStringKey("Search Owners and Appointments"))
            .accessibilityElement(children: .contain)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showAddAppointment = true
                        Self.analyticsLogger.log(event: "tap_add_appointment", info: nil)
                    } label: {
                        Label("Add Appointment", systemImage: "calendar.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add Appointment")

                    Button {
                        showAddOwner = true
                        Self.analyticsLogger.log(event: "tap_add_owner", info: nil)
                    } label: {
                        Label("Add Owner", systemImage: "person.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add Owner")

                    Button {
                        showMetrics = true
                        Self.analyticsLogger.log(event: "tap_dashboard", info: nil)
                    } label: {
                        Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Dashboard")

                    Button {
                        showTrustCenter = true
                        Self.analyticsLogger.log(event: "tap_trust_center", info: nil)
                    } label: {
                        Label("Trust Center", systemImage: "shield.lefthalf.fill")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Trust Center")

                    EditButton()
                        .font(AppFonts.body)
                        .accessibilityLabel("Edit List")
                }
            }
        } detail: {
            Group {
                if let owner = selectedOwner {
                    OwnerProfileView(owner: owner)
                        .background(AppColors.background)
                } else if let appt = selectedAppointment {
                    AppointmentDetailView(appointment: appt)
                        .background(AppColors.background)
                } else {
                    MetricsDashboardView()
                        .background(AppColors.background)
                }
            }
            .accessibilityElement(children: .contain)
        }
        .sheet(isPresented: $showAddOwner) {
            AddDogOwnerView { newOwner in
                selectedOwner = newOwner
                Self.analyticsLogger.log(event: "owner_added", info: newOwner.ownerName)
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { newAppt in
                selectedAppointment = newAppt
                Self.analyticsLogger.log(event: "appointment_added", info: "\(newAppt.date)")
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMetrics) {
            MetricsDashboardView()
                .background(AppColors.background)
        }
        .sheet(isPresented: $showTrustCenter) {
            TrustCenterView()
                .background(AppColors.background)
                .onAppear {
                    Self.analyticsLogger.log(event: "view_trust_center", info: nil)
                }
        }
        .fullScreenCover(isPresented: $shouldShowOnboarding) {
            OnboardingView()
                .background(AppColors.background)
                .onAppear {
                    Self.analyticsLogger.log(event: "onboarding_shown", info: nil)
                }
        }
        .onAppear {
            logAnalyticsEvent()
            prefetchData()
            // Trust Center audit logging here
        }
        #if os(macOS)
        .padding(AppSpacing.medium)
        #endif
    }

    // MARK: - Owners Section
    private var OwnersSection: some View {
        Section(header:
                    Text(LocalizedStringKey("Owners"))
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primary)
                        .padding(.bottom, AppSpacing.small)
                        .accessibilityAddTraits(.isHeader)
        ) {
            ForEach(filteredOwners) { owner in
                NavigationLink(
                    destination: OwnerProfileView(owner: owner)
                        .background(AppColors.background)
                        .cornerRadius(BorderRadius.medium)
                        .appShadow(AppShadows.card),
                    tag: owner,
                    selection: $selectedOwner
                ) {
                    DogOwnerRowView(owner: owner)
                        .padding(AppSpacing.small)
                        .background(AppColors.card)
                        .cornerRadius(BorderRadius.medium)
                        .appShadow(AppShadows.card)
                }
            }
            .onDelete(perform: deleteOwners)
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Owners Section")
        .accessibilityElement(children: .contain)
        .onAppear { Self.analyticsLogger.log(event: "owners_section_appear", info: nil) }
    }

    // MARK: - Appointments Section
    private var AppointmentsSection: some View {
        Section(header:
                    Text(LocalizedStringKey("Upcoming Appointments"))
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primary)
                        .padding(.bottom, AppSpacing.small)
                        .accessibilityAddTraits(.isHeader)
        ) {
            ForEach(filteredAppointments) { appt in
                NavigationLink(
                    destination: AppointmentDetailView(appointment: appt)
                        .background(AppColors.background)
                        .cornerRadius(BorderRadius.medium)
                        .appShadow(AppShadows.card),
                    tag: appt,
                    selection: $selectedAppointment
                ) {
                    AppointmentRowView(appointment: appt)
                        .padding(AppSpacing.small)
                        .background(AppColors.card)
                        .cornerRadius(BorderRadius.medium)
                        .appShadow(AppShadows.card)
                }
            }
            .onDelete(perform: deleteAppointments)
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Upcoming Appointments Section")
        .accessibilityElement(children: .contain)
        .onAppear { Self.analyticsLogger.log(event: "appointments_section_appear", info: nil) }
    }

    // MARK: - Filtering Logic
    private var filteredOwners: [DogOwner] {
        if searchQuery.isEmpty {
            return owners
        }
        let query = searchQuery.lowercased()
        return owners.filter {
            $0.ownerName.lowercased().contains(query) ||
            ($0.contactInfo?.phone ?? "").contains(query) ||
            ($0.dogs.first?.name.lowercased() ?? "").contains(query)
        }
    }

    private var filteredAppointments: [Appointment] {
        if searchQuery.isEmpty {
            return appointments
        }
        let query = searchQuery.lowercased()
        return appointments.filter {
            $0.owner?.ownerName.lowercased().contains(query) == true ||
            $0.dog?.name.lowercased().contains(query) == true
        }
    }

    // MARK: - Deletion Logic
    private func deleteOwners(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let owner = filteredOwners[index]
                modelContext.delete(owner)
                Self.analyticsLogger.log(event: "owner_deleted", info: owner.ownerName)
            }
        }
    }

    private func deleteAppointments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let appt = filteredAppointments[index]
                modelContext.delete(appt)
                Self.analyticsLogger.log(event: "appointment_deleted", info: "\(appt.date)")
            }
        }
    }

    // MARK: - Analytics & Prefetch
    private func logAnalyticsEvent() {
        Self.analyticsLogger.log(event: "content_view_appear", info: nil)
    }
    private func prefetchData() {
        // Prefetch data for owners, appointments, and images if needed.
    }
}

// MARK: - Trust Center View (unchanged)
struct TrustCenterView: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("Trust Center")
                .font(AppFonts.title)
                .foregroundColor(AppColors.primary)
                .padding(.top, AppSpacing.large)

            Text("Data Security & Audit Log features will be implemented here.")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondary)
                .padding(.horizontal, AppSpacing.medium)

            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.large)
        .appShadow(AppShadows.card)
        .padding(AppSpacing.medium)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Onboarding View (unchanged)
struct OnboardingView: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("Welcome to Furfolio!")
                .font(AppFonts.largeTitle)
                .foregroundColor(AppColors.primary)
                .padding(.top, AppSpacing.large)

            Text("Onboarding content goes here.")
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondary)
                .padding(.horizontal, AppSpacing.medium)

            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.large)
        .appShadow(AppShadows.card)
        .padding(AppSpacing.medium)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews (unchanged)
#Preview {
    Group {
        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .previewDevice("iPhone 14 Pro")
            .previewDisplayName("iPhone 14 Pro")

        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .previewDevice("iPad Pro (12.9-inch) (6th generation)")
            .previewDisplayName("iPad Pro")

        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .frame(minWidth: 800, minHeight: 600)
            .previewDisplayName("Mac")

        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
    }
}
