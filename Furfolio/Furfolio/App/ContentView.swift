//
//  ContentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import SwiftData

/**
 ContentView is the canonical root view and main shell of the Furfolio app.
 It provides a unified, multi-platform interface for managing dog owners, appointments, and metrics.
 Designed for scalability, accessibility, and modularity, it leverages SwiftData and design tokens for consistency.
 
 Features:
 - Adaptive navigation split view for iOS, iPadOS, and macOS.
 - Unified searchable list of owners and appointments.
 - Modular sections with clear accessibility traits.
 - Platform-specific presentation styles and placeholders for drag-and-drop.
 - Integration points for analytics, Trust Center, and onboarding flows.
 - Consistent styling using AppColors, AppFonts, BorderRadius, AppShadows, and AppSpacing.
 */

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
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
                    .listRowBackground(AppColors.card)
                AppointmentsSection
                    .listRowBackground(AppColors.card)
                // Placeholder for future ChargesSection and RouteOptimizationSection
                
                // Placeholder for Mac/iPad drag-and-drop support for owner/appointment reordering or multi-select
                // TODO: Implement drag-and-drop reordering and multi-select for macOS/iPadOS
            }
            .listStyle(.insetGrouped)
            .background(AppColors.background)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: LocalizedStringKey("Search Owners and Appointments"))
            .accessibilityElement(children: .contain)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // Role-based access control placeholder for adding appointments
                        showAddAppointment = true
                    } label: {
                        Label("Add Appointment", systemImage: "calendar.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add Appointment")
                    
                    Button {
                        // Role-based access control placeholder for adding owners
                        showAddOwner = true
                    } label: {
                        Label("Add Owner", systemImage: "person.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add Owner")
                    
                    Button {
                        showMetrics = true
                    } label: {
                        Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Dashboard")
                    
                    Button {
                        showTrustCenter = true
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
        // Platform-specific modal presentation styles
        .sheet(isPresented: $showAddOwner) {
            AddDogOwnerView { newOwner in
                selectedOwner = newOwner
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #elseif os(iPadOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #elseif os(macOS)
            // Future: Use formSheet style for macOS when available
            #endif
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { newAppt in
                selectedAppointment = newAppt
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #elseif os(iPadOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #elseif os(macOS)
            // Future: Use formSheet style for macOS when available
            #endif
        }
        .sheet(isPresented: $showMetrics) {
            MetricsDashboardView()
                .background(AppColors.background)
        }
        .sheet(isPresented: $showTrustCenter) {
            TrustCenterView()
                .background(AppColors.background)
        }
        .fullScreenCover(isPresented: $shouldShowOnboarding) {
            OnboardingView()
                .background(AppColors.background)
        }
        .onAppear {
            logAnalyticsEvent()
            prefetchData()
            // Hook for Trust Center audit logging can be added here
        }
        // Mac-specific padding for better layout
        #if os(macOS)
        .padding(AppSpacing.medium)
        #endif
    }
    
    // MARK: - Owners Section
    
    /// Section displaying the list of dog owners with navigation links.
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
                        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y),
                    tag: owner,
                    selection: $selectedOwner
                ) {
                    DogOwnerRowView(owner: owner)
                        .padding(AppSpacing.small)
                        .background(AppColors.card)
                        .cornerRadius(BorderRadius.medium)
                        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
                }
            }
            .onDelete(perform: deleteOwners)
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Owners Section")
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Appointments Section
    
    /// Section displaying upcoming appointments with navigation links.
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
                        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y),
                    tag: appt,
                    selection: $selectedAppointment
                ) {
                    AppointmentRowView(appointment: appt)
                        .padding(AppSpacing.small)
                        .background(AppColors.card)
                        .cornerRadius(BorderRadius.medium)
                        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
                }
            }
            .onDelete(perform: deleteAppointments)
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Upcoming Appointments Section")
        .accessibilityElement(children: .contain)
    }
    
    /*
    // Future Charges Section placeholder - token usage to be added when implemented
    private var ChargesSection: some View {
        Section(header:
                    Text(LocalizedStringKey("Charges"))
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primary)
                    .padding(.bottom, AppSpacing.small)
                    .accessibilityAddTraits(.isHeader)
        ) {
            // Implementation for charges goes here
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Charges Section")
        .accessibilityElement(children: .contain)
    }
    */
    
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
            }
        }
    }
    
    private func deleteAppointments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let appt = filteredAppointments[index]
                modelContext.delete(appt)
            }
        }
    }
    
    // MARK: - Analytics & Prefetch
    
    /// Logs analytics events on view appearance.
    private func logAnalyticsEvent() {
        // Integration point for analytics logging.
        // Example: Analytics.logEvent("ContentView_Appear")
        // Trust Center audit hooks can be added here.
    }
    
    /// Prefetches data to optimize performance.
    private func prefetchData() {
        // Prefetch data for owners, appointments, and related images.
        // Improves responsiveness and reduces latency.
    }
}

// MARK: - Trust Center View

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
        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
        .padding(AppSpacing.medium)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Onboarding View

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
        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
        .padding(AppSpacing.medium)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

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
        
        // Dark Mode Preview
        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        
        // Accessibility Large Text Preview
        ContentView()
            .modelContainer(for: DogOwner.self, inMemory: true)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
    }
}
