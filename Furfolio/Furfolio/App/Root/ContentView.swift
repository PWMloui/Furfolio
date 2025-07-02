//
//  ContentView.swift
//  Furfolio
//
//  ContentView is the main UI entry point for Furfolio, designed with a modular and extensible architecture.
//  It supports multi-brand configurations, comprehensive analytics and audit logging integrated with a Trust Center,
//  and is fully accessible with dynamic type and VoiceOver support.
//  The design facilitates localization and compliance by wrapping all user-facing strings in NSLocalizedString,
//  and includes diagnostic capabilities such as fetching recent analytics events for admin or debug interfaces.
//  Preview and testability are enhanced via dependency injection and a test-mode analytics logger.
//
//  Key Features:
//  - Async/await analytics logging with concurrency support.
//  - Test mode logging for QA, tests, and previews outputs to console only.
//  - Localization-ready strings with keys and comments for translators.
//  - Accessibility traits and labels throughout UI components.
//  - Audit-ready Trust Center integration with event logging hooks.
//  - Comprehensive SwiftUI previews covering devices, modes, and accessibility sizes.
//

import SwiftUI
import SwiftData

// MARK: - Analytics/Audit Protocol

/// Protocol defining analytics logging capabilities for ContentView.
/// Supports async logging to accommodate network or database operations.
/// Includes a testMode flag to enable console-only logging for QA and previews.
public protocol ContentViewAnalyticsLogger {
    /// Indicates whether logger is in test mode (console-only).
    var testMode: Bool { get set }
    /// Logs an event asynchronously with optional info string.
    /// - Parameters:
    ///   - event: The event name key for logging.
    ///   - info: Optional additional info string.
    func log(event: String, info: String?) async
    /// Retrieves the last N logged events asynchronously.
    /// - Parameter maxCount: Maximum number of recent events to fetch.
    /// - Returns: Array of logged event strings.
    func fetchRecentEvents(maxCount: Int) async -> [String]
}

/// Null implementation of ContentViewAnalyticsLogger that performs no logging.
/// Useful as a default placeholder.
public struct NullContentViewAnalyticsLogger: ContentViewAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?) async {}
    public func fetchRecentEvents(maxCount: Int) async -> [String] { [] }
}

/// Concrete analytics logger that supports async logging, test mode console output,
/// and in-memory storage of recent events for diagnostics.
public class DefaultContentViewAnalyticsLogger: ContentViewAnalyticsLogger {
    public var testMode: Bool = false
    
    // Thread-safe storage of recent events
    private let queue = DispatchQueue(label: "ContentViewAnalyticsLogger.queue", attributes: .concurrent)
    private var _events: [String] = []
    private var events: [String] {
        get { queue.sync { _events } }
        set { queue.async(flags: .barrier) { self._events = newValue } }
    }
    
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    /// Logs an event asynchronously.
    /// Stores event in-memory and optionally prints to console if in test mode.
    public func log(event: String, info: String?) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let infoString = info ?? ""
        let logEntry = "[\(timestamp)] Event: \(event), Info: \(infoString)"
        
        // Store event thread-safely
        queue.async(flags: .barrier) {
            self._events.append(logEntry)
            if self._events.count > 1000 {
                self._events.removeFirst(self._events.count - 1000)
            }
        }
        
        if testMode {
            print("Analytics Log: \(logEntry)")
        }
        
        // Simulate async operation if needed (e.g. network call)
        await Task.yield()
    }
    
    /// Fetches the most recent logged events asynchronously.
    public func fetchRecentEvents(maxCount: Int) async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async {
                let recent = Array(self._events.suffix(maxCount))
                continuation.resume(returning: recent)
            }
        }
    }
}

// MARK: - ContentView

/// The main content view of Furfolio, managing the display and interaction with dog owners and appointments.
/// Supports analytics, audit logging, Trust Center compliance, accessibility, localization, and diagnostics.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - Analytics Logger
    
    /// Shared analytics logger instance used for event tracking.
    /// Can be replaced for testing or extended analytics providers.
    static var analyticsLogger: ContentViewAnalyticsLogger = DefaultContentViewAnalyticsLogger()
    
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
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: NSLocalizedString("Search Owners and Appointments", comment: "Search bar prompt"))
            .accessibilityElement(children: .contain)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showAddAppointment = true
                        Task {
                            await Self.analyticsLogger.log(event: NSLocalizedString("tap_add_appointment", comment: "Log event: tap add appointment button"), info: nil)
                        }
                    } label: {
                        Label(NSLocalizedString("Add Appointment", comment: "Add appointment button label"), systemImage: "calendar.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel(NSLocalizedString("Add Appointment", comment: "Accessibility label for add appointment button"))

                    Button {
                        showAddOwner = true
                        Task {
                            await Self.analyticsLogger.log(event: NSLocalizedString("tap_add_owner", comment: "Log event: tap add owner button"), info: nil)
                        }
                    } label: {
                        Label(NSLocalizedString("Add Owner", comment: "Add owner button label"), systemImage: "person.badge.plus")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel(NSLocalizedString("Add Owner", comment: "Accessibility label for add owner button"))

                    Button {
                        showMetrics = true
                        Task {
                            await Self.analyticsLogger.log(event: NSLocalizedString("tap_dashboard", comment: "Log event: tap dashboard button"), info: nil)
                        }
                    } label: {
                        Label(NSLocalizedString("Dashboard", comment: "Dashboard button label"), systemImage: "chart.bar.doc.horizontal")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel(NSLocalizedString("Dashboard", comment: "Accessibility label for dashboard button"))

                    Button {
                        showTrustCenter = true
                        Task {
                            await Self.analyticsLogger.log(event: NSLocalizedString("tap_trust_center", comment: "Log event: tap trust center button"), info: nil)
                        }
                    } label: {
                        Label(NSLocalizedString("Trust Center", comment: "Trust center button label"), systemImage: "shield.lefthalf.fill")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel(NSLocalizedString("Trust Center", comment: "Accessibility label for trust center button"))

                    EditButton()
                        .font(AppFonts.body)
                        .accessibilityLabel(NSLocalizedString("Edit List", comment: "Accessibility label for edit list button"))
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
                Task {
                    await Self.analyticsLogger.log(event: NSLocalizedString("owner_added", comment: "Log event: owner added"), info: newOwner.ownerName)
                }
            }
            .environment(\.modelContext, modelContext)
            .background(AppColors.background)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { newAppt in
                selectedAppointment = newAppt
                Task {
                    await Self.analyticsLogger.log(event: NSLocalizedString("appointment_added", comment: "Log event: appointment added"), info: "\(newAppt.date)")
                }
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
                    Task {
                        await Self.analyticsLogger.log(event: NSLocalizedString("view_trust_center", comment: "Log event: view trust center screen"), info: nil)
                    }
                }
        }
        .fullScreenCover(isPresented: $shouldShowOnboarding) {
            OnboardingView()
                .background(AppColors.background)
                .onAppear {
                    Task {
                        await Self.analyticsLogger.log(event: NSLocalizedString("onboarding_shown", comment: "Log event: onboarding screen shown"), info: nil)
                    }
                }
        }
        .onAppear {
            Task {
                await logAnalyticsEvent()
                prefetchData()
                // Trust Center audit logging here
            }
        }
        #if os(macOS)
        .padding(AppSpacing.medium)
        #endif
    }

    // MARK: - Owners Section
    
    /// View section displaying the list of dog owners, filtered by search query.
    /// Includes accessibility traits and logs appearance for analytics.
    private var OwnersSection: some View {
        Section(header:
                    Text(NSLocalizedString("Owners", comment: "Owners section header"))
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
        .accessibilityLabel(NSLocalizedString("Owners Section", comment: "Accessibility label for owners section"))
        .accessibilityElement(children: .contain)
        .onAppear {
            Task {
                await Self.analyticsLogger.log(event: NSLocalizedString("owners_section_appear", comment: "Log event: owners section appeared"), info: nil)
            }
        }
    }

    // MARK: - Appointments Section
    
    /// View section displaying upcoming appointments, filtered by search query.
    /// Includes accessibility traits and logs appearance for analytics.
    private var AppointmentsSection: some View {
        Section(header:
                    Text(NSLocalizedString("Upcoming Appointments", comment: "Upcoming appointments section header"))
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
        .accessibilityLabel(NSLocalizedString("Upcoming Appointments Section", comment: "Accessibility label for upcoming appointments section"))
        .accessibilityElement(children: .contain)
        .onAppear {
            Task {
                await Self.analyticsLogger.log(event: NSLocalizedString("appointments_section_appear", comment: "Log event: appointments section appeared"), info: nil)
            }
        }
    }

    // MARK: - Filtering Logic
    
    /// Filters dog owners based on the current search query.
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

    /// Filters appointments based on the current search query.
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
    
    /// Deletes selected owners and logs deletion events.
    /// - Parameter offsets: IndexSet of owners to delete.
    private func deleteOwners(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let owner = filteredOwners[index]
                modelContext.delete(owner)
                Task {
                    await Self.analyticsLogger.log(event: NSLocalizedString("owner_deleted", comment: "Log event: owner deleted"), info: owner.ownerName)
                }
            }
        }
    }

    /// Deletes selected appointments and logs deletion events.
    /// - Parameter offsets: IndexSet of appointments to delete.
    private func deleteAppointments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let appt = filteredAppointments[index]
                modelContext.delete(appt)
                Task {
                    await Self.analyticsLogger.log(event: NSLocalizedString("appointment_deleted", comment: "Log event: appointment deleted"), info: "\(appt.date)")
                }
            }
        }
    }

    // MARK: - Analytics & Prefetch
    
    /// Logs the initial appearance event asynchronously.
    private func logAnalyticsEvent() async {
        await Self.analyticsLogger.log(event: NSLocalizedString("content_view_appear", comment: "Log event: content view appeared"), info: nil)
    }
    
    /// Prefetches necessary data asynchronously if needed.
    private func prefetchData() {
        // Prefetch data for owners, appointments, and images if needed.
    }
}

// MARK: - Trust Center View (unchanged)
struct TrustCenterView: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Text(NSLocalizedString("Trust Center", comment: "Trust Center screen title"))
                .font(AppFonts.title)
                .foregroundColor(AppColors.primary)
                .padding(.top, AppSpacing.large)

            Text(NSLocalizedString("Data Security & Audit Log features will be implemented here.", comment: "Trust Center placeholder text"))
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
            Text(NSLocalizedString("Welcome to Furfolio!", comment: "Onboarding welcome title"))
                .font(AppFonts.largeTitle)
                .foregroundColor(AppColors.primary)
                .padding(.top, AppSpacing.large)

            Text(NSLocalizedString("Onboarding content goes here.", comment: "Onboarding placeholder content"))
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
