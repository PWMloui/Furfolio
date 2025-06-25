//  AdminPanelView.swift
//  Furfolio
//
//  ENHANCED: Centralized, Auditable, Tokenized Admin/Developer Panel (2025)

import SwiftUI
import SwiftData

// MARK: - AdminPanel Audit/Event Logging

fileprivate struct AdminPanelAuditEvent: Codable {
    let timestamp: Date
    let operation: String       // "featureFlagChange", "wipeData", "populateDemo", "integrityCheck", "viewCrashLogs"
    let detail: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let result: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let tagStr = tags.joined(separator: ",")
        let res = result ?? ""
        return "[\(op)] (\(tagStr)) at \(dateStr)\(detail != nil ? ": \(detail!)" : "")\(res.isEmpty ? "" : " → \(res)")"
    }
}

fileprivate final class AdminPanelAudit {
    static private(set) var log: [AdminPanelAuditEvent] = []

    static func record(
        operation: String,
        detail: String? = nil,
        tags: [String] = [],
        actor: String? = "admin",
        context: String? = nil,
        result: String? = nil
    ) {
        let event = AdminPanelAuditEvent(
            timestamp: Date(),
            operation: operation,
            detail: detail,
            tags: tags,
            actor: actor,
            context: context,
            result: result
        )
        log.append(event)
        if log.count > 1000 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No admin events recorded."
    }
}

// MARK: - AdminPanelView (Modular, Tokenized, Auditable Admin/Developer Panel)

struct AdminPanelView: View {
    @Environment(\.modelContext) private var modelContext

    /// Shared feature flag manager instance.
    @StateObject private var featureManager = FeatureFlagManager.shared

    /// Stores results from the database integrity checks.
    @State private var integrityIssues: [IntegrityIssue] = []

    /// Holds crash report data fetched from persistent storage.
    @State private var crashReports: [CrashReport] = []

    /// Controls display of the confirmation alert before wiping all app data.
    @State private var showWipeDataAlert = false

    /// Controls display of the confirmation alert before populating demo data.
    @State private var showPopulateDataAlert = false

    /// Optional: Expose audit summary for Trust Center/dev/QA UI
    @State private var showAuditSheet = false

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

                // MARK: - Feature Flags Section
                Section(header: Text("Feature Flags").font(AppFonts.sectionHeader)) {
                    ForEach(FeatureFlagManager.Flag.allCases) { flag in
                        Toggle(flag.rawValue, isOn:
                            Binding(
                                get: { featureManager.isEnabled(flag) },
                                set: { enabled in
                                    featureManager.set(flag, enabled: enabled)
                                    AdminPanelAudit.record(
                                        operation: "featureFlagChange",
                                        detail: "\(flag.rawValue): \(enabled)",
                                        tags: ["featureFlag", flag.rawValue, enabled ? "enabled" : "disabled"],
                                        actor: "admin",
                                        context: "adminPanel"
                                    )
                                }
                            )
                        )
                        .font(AppFonts.body)
                    }
                }

                // MARK: - Data Management Section
                Section(header: Text("Data Management").font(AppFonts.sectionHeader)) {
                    Button("Populate with Demo Data") {
                        AdminPanelAudit.record(
                            operation: "populateDemo",
                            detail: "User prompted",
                            tags: ["data", "populate", "demo"],
                            actor: "admin",
                            context: "adminPanel"
                        )
                        showPopulateDataAlert = true
                    }
                    .font(AppFonts.body)

                    Button("Wipe All App Data", role: .destructive) {
                        AdminPanelAudit.record(
                            operation: "wipeData",
                            detail: "User prompted",
                            tags: ["data", "wipe", "destructive"],
                            actor: "admin",
                            context: "adminPanel"
                        )
                        showWipeDataAlert = true
                    }
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.destructive)
                }

                // MARK: - Diagnostics Section
                Section(header: Text("Diagnostics").font(AppFonts.sectionHeader)) {
                    Button("Run Database Integrity Check") {
                        AdminPanelAudit.record(
                            operation: "integrityCheck",
                            detail: "Triggered",
                            tags: ["diagnostics", "integrity"],
                            actor: "admin",
                            context: "adminPanel"
                        )
                        runIntegrityCheck()
                    }
                    .font(AppFonts.body)

                    NavigationLink("View Crash Logs") {
                        CrashLogView(reports: crashReports)
                    }
                    .font(AppFonts.body)

                    // Optional: Show audit log for admin/trust center/devs
                    Button("View Admin Audit Log") {
                        showAuditSheet = true
                    }
                    .font(AppFonts.body)
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadInitialData)
            .alert("Populate Demo Data?", isPresented: $showPopulateDataAlert) {
                Button("Populate") {
                    populateDemoData()
                    AdminPanelAudit.record(
                        operation: "populateDemo",
                        detail: "Demo data populated",
                        tags: ["data", "populate", "demo"],
                        actor: "admin",
                        context: "adminPanel",
                        result: "success"
                    )
                }
                Button("Cancel", role: .cancel) {
                    AdminPanelAudit.record(
                        operation: "populateDemo",
                        detail: "Demo data populate canceled",
                        tags: ["data", "populate", "demo"],
                        actor: "admin",
                        context: "adminPanel",
                        result: "canceled"
                    )
                }
            } message: {
                Text("This will first wipe all existing data and then add the standard demo data set.")
                    .font(AppFonts.caption)
            }
            .alert("Wipe All Data?", isPresented: $showWipeDataAlert) {
                Button("Wipe Data", role: .destructive) {
                    wipeAllData()
                    AdminPanelAudit.record(
                        operation: "wipeData",
                        detail: "Data wiped",
                        tags: ["data", "wipe", "destructive"],
                        actor: "admin",
                        context: "adminPanel",
                        result: "success"
                    )
                }
                Button("Cancel", role: .cancel) {
                    AdminPanelAudit.record(
                        operation: "wipeData",
                        detail: "Wipe data canceled",
                        tags: ["data", "wipe", "destructive"],
                        actor: "admin",
                        context: "adminPanel",
                        result: "canceled"
                    )
                }
            } message: {
                Text("This action is irreversible and will delete all owners, dogs, appointments, and charges from the device.")
                    .font(AppFonts.caption)
            }
            .sheet(isPresented: $showAuditSheet) {
                AdminAuditSheetView(isPresented: $showAuditSheet)
            }
        }
    }

    /// Loads initial data such as crash reports for display.
    private func loadInitialData() {
        self.crashReports = CrashReporter.shared.fetchReports(context: modelContext, includeResolved: true)
        AdminPanelAudit.record(
            operation: "viewCrashLogs",
            detail: "Crash logs loaded",
            tags: ["diagnostics", "crashlog"],
            actor: "admin",
            context: "adminPanel"
        )
    }

    /// Runs a comprehensive database integrity check.
    private func runIntegrityCheck() {
        Task {
            let owners = await DataStoreService.shared.fetchAll(DogOwner.self)
            let dogs = await DataStoreService.shared.fetchAll(Dog.self)
            self.integrityIssues = DatabaseIntegrityChecker.shared.runAllChecks(
                owners: owners, dogs: dogs, appointments: [], charges: [], staff: [], users: [], tasks: [], vaccinationRecords: []
            )

            AdminPanelAudit.record(
                operation: "integrityCheck",
                detail: "Check completed",
                tags: ["diagnostics", "integrity"],
                actor: "admin",
                context: "adminPanel",
                result: integrityIssues.isEmpty ? "ok" : "issues: \(integrityIssues.count)"
            )
        }
    }

    /// Populates the database with demo data after wiping existing data.
    private func populateDemoData() {
        Task {
            await DemoDataManager.shared.populateDemoData(in: modelContext)
        }
    }

    /// Wipes all app data irreversibly.
    private func wipeAllData() {
        Task {
            await DataStoreService.shared.wipeDatabase()
        }
    }
}

// MARK: - Audit Sheet for Admin/Trust Center

private struct AdminAuditSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if AdminPanelAudit.log.isEmpty {
                    ContentUnavailableView("No admin events yet", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(AdminPanelAudit.log.suffix(40).reversed(), id: \.timestamp) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.accessibilityLabel)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let context = event.context, !context.isEmpty {
                                Text("Context: \(context)").font(.caption2).foregroundColor(.secondary)
                            }
                            if let res = event.result, !res.isEmpty {
                                Text("Result: \(res)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Admin Audit Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let json = AdminPanelAudit.exportLastJSON() {
                        Button {
                            UIPasteboard.general.string = json
                        } label: {
                            Label("Copy Last as JSON", systemImage: "doc.on.doc")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Crash Log View

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
    AdminPanelView()
        .modelContainer(for: [CrashReport.self, DogOwner.self, Dog.self, Task.self], inMemory: true)
}
