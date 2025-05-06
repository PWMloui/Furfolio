//
//  ContentView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhanced authentication, improved navigation split view, dynamic sheet presentation for adding dog owners and metrics, and refined search functionality.

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogOwners: [DogOwner]
    @Query private var dailyRevenues: [DailyRevenue]
    
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
    
    // State for selected dog owner
    @State private var selectedDogOwner: DogOwner?
    
    var body: some View {
        if isAuthenticated {
            NavigationSplitView {
                // Sidebar Content
                List {
                    businessInsightsSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                    upcomingAppointmentsSection
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    dogOwnersSection
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .navigationTitle("Furfolio")
                .searchable(text: $searchText)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            withAnimation { isShowingAddOwnerSheet = true }
                        }) {
                            Label("Add Dog Owner", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isShowingAddOwnerSheet) {
                    AddDogOwnerView { ownerName, dogName, breed, contactInfo, address, notes, selectedImageData, birthdate in
                        addDogOwner(ownerName: ownerName,
                                    dogName: dogName,
                                    breed: breed,
                                    contactInfo: contactInfo,
                                    address: address,
                                    notes: notes,
                                    selectedImageData: selectedImageData,
                                    birthdate: birthdate)
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
                if let selectedDogOwner = selectedDogOwner {
                    OwnerProfileView(dogOwner: selectedDogOwner)
                        .transition(.opacity)
                } else {
                    emptyDetailView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: searchText)
        } else {
            // Show Login View if not authenticated
            LoginView(isAuthenticated: $isAuthenticated, authenticationError: $authenticationError)
                .transition(.opacity)
        }
    }
    
    // MARK: - Login View
    struct LoginView: View {
        @Binding var isAuthenticated: Bool
        @Binding var authenticationError: String?
        
        @State private var username: String = ""
        @State private var password: String = ""
        
        var body: some View {
            VStack(spacing: 16) {
                Text("Welcome to Furfolio")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                    .transition(.opacity)
                
                TextField("Username", text: $username)
                    .padding()
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .transition(.move(edge: .leading))
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .transition(.move(edge: .trailing))
                
                Button(action: authenticateUser) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .transition(.scale)
                
                if let error = authenticationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
                
                if isAuthenticated {
                    Text("Successfully Authenticated!")
                        .foregroundColor(.green)
                        .font(.headline)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
            .padding()
        }
        
        private func authenticateUser() {
            let storedCredentials: [String: String] = ["lvconcepcion": "jesus2024"]
            if let storedPassword = storedCredentials[username], storedPassword == password {
                isAuthenticated = true
                authenticationError = nil
            } else {
                isAuthenticated = false
                authenticationError = "Invalid username or password. Please try again."
            }
        }
    }
    
    // MARK: - Helper Views
    private var businessInsightsSection: some View {
        Section(header: Text("Business Insights")) {
            Button(action: { withAnimation { isShowingMetricsView = true } }) {
                Label("View Metrics Dashboard", systemImage: "chart.bar.xaxis")
            }
        }
    }
    
    private var upcomingAppointmentsSection: some View {
        Section(header: Text("Upcoming Appointments")) {
            let upcomingAppointments = fetchUpcomingAppointments()
            if upcomingAppointments.isEmpty {
                Text("No upcoming appointments.")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(upcomingAppointments) { appointment in
                    if let owner = findOwner(for: appointment) {
                        NavigationLink {
                            OwnerProfileView(dogOwner: owner)
                                .transition(.opacity)
                        } label: {
                            appointmentRow(for: appointment, owner: owner)
                        }
                    }
                }
            }
        }
    }
    
    private var dogOwnersSection: some View {
        Section(header: Text("Dog Owners")) {
            let filteredDogOwners = filterDogOwners()
            if filteredDogOwners.isEmpty {
                Text("No dog owners found.")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(filteredDogOwners) { dogOwner in
                    NavigationLink {
                        OwnerProfileView(dogOwner: dogOwner)
                            .transition(.opacity)
                    } label: {
                        DogOwnerRowView(dogOwner: dogOwner)
                    }
                }
                .onDelete(perform: deleteDogOwners)
            }
        }
    }
    
    private var emptyDetailView: some View {
        VStack {
            Text("Select a dog owner to view details.")
                .foregroundColor(.secondary)
                .padding()
                .multilineTextAlignment(.center)
            Image(systemName: "person.crop.circle.badge.questionmark")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.gray.opacity(0.5))
        }
    }
    
    // MARK: - Data Fetching
    private func fetchUpcomingAppointments() -> [Appointment] {
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        return dogOwners.flatMap { $0.appointments }
            .filter { $0.date > today && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }
    
    private func findOwner(for appointment: Appointment) -> DogOwner? {
        dogOwners.first { $0.appointments.contains(appointment) }
    }
    
    private func filterDogOwners() -> [DogOwner] {
        let lowercasedSearchText = searchText.lowercased()
        return dogOwners.filter { owner in
            searchText.isEmpty ||
            owner.ownerName.lowercased().contains(lowercasedSearchText) ||
            owner.dogName.lowercased().contains(lowercasedSearchText) ||
            owner.breed.lowercased().contains(lowercasedSearchText) ||
            owner.address.lowercased().contains(lowercasedSearchText) ||
            owner.notes.lowercased().contains(lowercasedSearchText)
        }
    }
    
    // MARK: - Data Management
    private func addDogOwner(ownerName: String, dogName: String, breed: String, contactInfo: String, address: String, notes: String, selectedImageData: Data?, birthdate: Date?) {
        withAnimation {
            let newOwner = DogOwner(
                ownerName: ownerName,
                dogName: dogName,
                breed: breed,
                contactInfo: contactInfo,
                address: address,
                dogImage: selectedImageData,
                notes: notes,
                birthdate: birthdate
            )
            modelContext.insert(newOwner)
        }
    }
    
    private func deleteDogOwners(offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                modelContext.delete(dogOwners[index])
            }
        }
    }
    
    // MARK: - Helper Views for Appointments
    @ViewBuilder
    private func appointmentRow(for appointment: Appointment, owner: DogOwner) -> some View {
        VStack(alignment: .leading) {
            Text(owner.ownerName)
                .font(.headline)
            Text("Next Appointment: \(appointment.date.formatted(.dateTime.month().day().hour().minute()))")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Service Type: \(appointment.serviceType.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            if let notes = appointment.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
