//
//  ContentView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import SwiftData

/**
 ContentView serves as the main entry point of the Furfolio app, designed with a multi-platform architecture in mind (iOS, iPadOS, macOS).
 It focuses on business needs by unifying owners, appointments, and metrics in a single, cohesive interface.
 The design emphasizes performance and scalability, leveraging SwiftData and modular UI components.
 
 Architectural goals:
 - Multi-platform support with adaptive UI and backgrounds.
 - Unified search experience for owners and appointments via a single SearchBar component.
 - Modular sections for maintainability and extensibility.
 - Prepared for future features like charges and route optimization.
 - Accessibility and localization-ready.
 - Role-based access control placeholders for secure data management.
 - Analytics and data prefetching on view appearance.
 - Inclusion of a Trust Center for data security and audit logs.
 - Onboarding flow integration.
 
 Usage Note:
 ContentView now fully uses modular design tokens (AppColors, AppFonts, BorderRadius, AppShadows, AppSpacing) for all styling to ensure consistency and maintainability.
 */

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Owners and Appointments from your models
    @Query(sort: \DogOwner.ownerName) private var owners: [DogOwner]
    @Query(sort: \Appointment.date, order: .reverse) private var appointments: [Appointment]
    
    // State for sheet presentations
    @State private var showAddOwner = false
    @State private var showAddAppointment = false
    @State private var showMetrics = false
    @State private var showTrustCenter = false
    
    // Selection for detail pane
    @State private var selectedOwner: DogOwner?
    @State private var selectedAppointment: Appointment?
    
    // Unified Search State
    @State private var searchQuery = ""
    
    // Onboarding state
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        NavigationSplitView {
            List {
                OwnersSection
                    .listRowBackground(AppColors.card)
                AppointmentsSection
                    .listRowBackground(AppColors.card)
                // TODO: ChargesSection for future charge management
                // ChargesSection
                
                // Placeholder for future TSP route optimization button or map for mobile groomers
                // RouteOptimizationSection
            }
            .listStyle(.insetGrouped)
            .background(AppColors.background)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: LocalizedStringKey("Search Owners and Appointments"))
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Implement role-based access control for adding appointments
                        showAddAppointment = true
                    } label: {
                        Label("Add Appointment", systemImage: "calendar.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add Appointment")
                    
                    Button {
                        // TODO: Implement role-based access control for adding owners
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
        }
        .sheet(isPresented: $showAddOwner) {
            // TODO: Role-based access control check here
            AddDogOwnerView { newOwner in
                selectedOwner = newOwner
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
        }
        .sheet(isPresented: $showAddAppointment) {
            // TODO: Role-based access control check here
            AddAppointmentView { newAppt in
                selectedAppointment = newAppt
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
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
        }
    }
    
    // MARK: - ContentView (Main App Entry, Modular Token Styling)
    
    private var OwnersSection: some View {
        Section(header: Text(LocalizedStringKey("Owners"))
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primary)
            .padding(.bottom, AppSpacing.small)
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
    }
    
    private var AppointmentsSection: some View {
        Section(header: Text(LocalizedStringKey("Upcoming Appointments"))
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primary)
            .padding(.bottom, AppSpacing.small)
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
    }
    
    /*
    // TODO: Future Charges Section
    private var ChargesSection: some View {
        Section(header: Text(LocalizedStringKey("Charges"))
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primary)
            .padding(.bottom, AppSpacing.small)
        ) {
            // Implementation for charges goes here
        }
        .listRowBackground(AppColors.background)
        .accessibilityLabel("Charges Section")
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
    
    private func logAnalyticsEvent() {
        // TODO: Integrate analytics logging here
        // Example: Analytics.logEvent("ContentView_Appear")
    }
    
    private func prefetchData() {
        // TODO: Prefetch data for performance optimization
        // Batch fetch appointments, owners, and images here
    }
}

// MARK: - Placeholder Views for Trust Center and Onboarding

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
    }
}

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
    }
}

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
    }
}
