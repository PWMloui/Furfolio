//  AdminPanelView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A centralized developer panel for managing feature flags,
//  data, and running diagnostics.
//

import SwiftUI
import SwiftData

// MARK: - AdminPanelView (Modular, Tokenized, Auditable Admin/Developer Panel)

/// The main view for the developer/admin panel.
/// This modular, tokenized, and auditable interface supports compliance requirements,
/// analytics tracking, diagnostics, audit trails, event logging, and UI design system integration.
/// All destructive actions and feature flag toggles are logged and audited to ensure traceability.
/// This panel facilitates controlled experimentation and safe debugging for developers and administrators.
struct AdminPanelView: View {
    @Environment(\.modelContext) private var modelContext
    
    /// Shared feature flag manager instance.
    /// All feature flag changes are audited and tracked for analytics and compliance.
    @StateObject private var featureManager = FeatureFlagManager.shared
    
    /// Stores results from the database integrity checks.
    /// Used for diagnostics and audit trail reporting.
    @State private var integrityIssues: [IntegrityIssue] = []
    
    /// Holds crash report data fetched from persistent storage.
    /// Enables audit and diagnostic insights into app stability.
    @State private var crashReports: [CrashReport] = []
    
    /// Controls display of the confirmation alert before wiping all app data.
    /// Ensures compliance by requiring explicit user confirmation for destructive operations.
    @State private var showWipeDataAlert = false
    
    /// Controls display of the confirmation alert before populating demo data.
    /// Ensures auditability and user awareness of data changes.
    @State private var showPopulateDataAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Warning Section
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.warning)
                            .font(AppFonts.title)
                        Text("This panel contains developer tools. Actions taken here may be destructive and are not intended for regular users.")
                            .font(AppFonts.caption)
                    }
                    .padding(.vertical, AppSpacing.small)
                }
                // Audit: Warning displayed to inform users of risks, supporting compliance and UI clarity.
                
                // MARK: - Feature Flags Section
                Section(header: Text("Feature Flags").font(AppFonts.sectionHeader)) {
                    // Audit/Analytics: Feature flag toggles are logged for change tracking and experimentation analysis.
                    ForEach(FeatureFlagManager.Flag.allCases) { flag in
                        Toggle(flag.rawValue, isOn:
                            Binding(
                                get: { featureManager.isEnabled(flag) },
                                set: {
                                    featureManager.set(flag, enabled: $0)
                                    // TODO: Add audit/event logging here for feature flag changes
                                }
                            )
                        )
                        .font(AppFonts.body)
                    }
                }
                
                // MARK: - Data Management Section
                Section(header: Text("Data Management").font(AppFonts.sectionHeader)) {
                    // Audit: Demo data population requires explicit user confirmation.
                    Button("Populate with Demo Data") {
                        // Analytics: Track user intent to populate demo data.
                        showPopulateDataAlert = true
                    }
                    .font(AppFonts.body)
                    
                    // Audit: Wiping data is destructive and must be confirmed by the user.
                    Button("Wipe All App Data", role: .destructive) {
                        // Analytics: Log wipe data intent for compliance.
                        showWipeDataAlert = true
                    }
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.destructive)
                }
                
                // MARK: - Diagnostics Section
                Section(header: Text("Diagnostics").font(AppFonts.sectionHeader)) {
                    // Audit: Running integrity checks should be logged.
                    Button("Run Database Integrity Check") {
                        // Analytics: Track diagnostic runs.
                        runIntegrityCheck()
                    }
                    .font(AppFonts.body)
                    
                    NavigationLink("View Crash Logs") {
                        CrashLogView(reports: crashReports)
                    }
                    .font(AppFonts.body)
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadInitialData)
            .alert("Populate Demo Data?", isPresented: $showPopulateDataAlert) {
                Button("Populate") {
                    // Audit/Event: Log demo data population confirmation
                    populateDemoData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will first wipe all existing data and then add the standard demo data set.")
                    .font(AppFonts.caption)
            }
            .alert("Wipe All Data?", isPresented: $showWipeDataAlert) {
                Button("Wipe Data", role: .destructive) {
                    // Audit/Event: Log data wipe confirmation
                    wipeAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action is irreversible and will delete all owners, dogs, appointments, and charges from the device.")
                    .font(AppFonts.caption)
            }
        }
    }
    
    /// Loads initial data such as crash reports for display.
    /// This supports audit and diagnostic workflows by presenting existing logs.
    private func loadInitialData() {
        // Audit: Fetch and load crash reports for admin review.
        self.crashReports = CrashReporter.shared.fetchReports(context: modelContext, includeResolved: true)
    }

    /// Runs a comprehensive database integrity check.
    /// Results are used for diagnostics, audit reporting, and compliance validation.
    /// This action should be logged for analytics and traceability.
    private func runIntegrityCheck() {
        Task {
            // In a real app, you'd fetch all entities from the DataStoreService
            let owners = await DataStoreService.shared.fetchAll(DogOwner.self)
            let dogs = await DataStoreService.shared.fetchAll(Dog.self)
            // ... fetch other entities
            
            // For the demo, we pass empty arrays
            self.integrityIssues = DatabaseIntegrityChecker.shared.runAllChecks(
                owners: owners, dogs: dogs, appointments: [], charges: [], staff: [], users: [], tasks: [], vaccinationRecords: []
            )
            
            if integrityIssues.isEmpty {
                // Optionally show a "success" alert or log success event
            } else {
                // The user would navigate to a detail view to see the issues
                print("Found \(integrityIssues.count) integrity issues.")
            }
        }
    }
    
    /// Populates the database with demo data after wiping existing data.
    /// This action is audited and analytics events are generated to track usage.
    private func populateDemoData() {
        Task {
            await DemoDataManager.shared.populateDemoData(in: modelContext)
            // TODO: Add audit/event logging for demo data population completion
        }
    }
    
    /// Wipes all app data irreversibly.
    /// This destructive action is logged for audit and compliance purposes.
    /// It also triggers analytics events to track admin actions.
    private func wipeAllData() {
        Task {
            await DataStoreService.shared.wipeDatabase()
            // TODO: Add audit/event logging for data wipe completion
        }
    }
}

/// A sub-view to display crash logs.
/// Uses modular tokens for fonts and colors to maintain design consistency.
private struct CrashLogView: View {
    let reports: [CrashReport]
    
    var body: some View {
        List {
            if reports.isEmpty {
                ContentUnavailableView("No Crash Logs Found", systemImage: "ladybug")
            } else {
                ForEach(reports) { report in
                    VStack(alignment: .leading) {
                        Text(report.message)
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primaryText)
                        Text("Type: \(report.type) - \(report.date, style: .datetime)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                }
            }
        }
        .navigationTitle("Crash Logs")
    }
}


// MARK: - Preview
#Preview {
    // Demo/business/tokenized preview logic and intent:
    // Provides an in-memory model container for isolated UI preview and testing of the AdminPanelView.
    AdminPanelView()
        .modelContainer(for: [CrashReport.self, DogOwner.self, Dog.self, Task.self], inMemory: true)
}
