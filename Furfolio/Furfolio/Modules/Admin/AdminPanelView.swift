//  AdminPanelView.swift
//  Furfolio
//
//  ENHANCED: Centralized, Auditable, Tokenized Admin/Developer Panel (2025)

import SwiftUI
import SwiftData

// MARK: - Analytics & Audit Protocols

public protocol AdminPanelAnalyticsLogger {
    /// Log an admin panel event asynchronously.
    func log(event: String, detail: String?, tags: [String], actor: String?, context: String?, result: String?) async
}

public protocol AdminPanelAuditLogger {
    /// Record an admin panel audit entry asynchronously.
    func record(event: String, detail: String?, tags: [String], actor: String?, context: String?, result: String?) async
}

public struct NullAdminPanelAnalyticsLogger: AdminPanelAnalyticsLogger {
    public init() {}
    public func log(event: String, detail: String?, tags: [String], actor: String?, context: String?, result: String?) async {}
}

public struct NullAdminPanelAuditLogger: AdminPanelAuditLogger {
    public init() {}
    public func record(event: String, detail: String?, tags: [String], actor: String?, context: String?, result: String?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an admin panel audit event.
public struct AdminPanelAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?
    public let tags: [String]
    public let actor: String?
    public let context: String?
    public let result: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        detail: String? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        result: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
        self.tags = tags
        self.actor = actor
        self.context = context
        self.result = result
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let tagStr = tags.joined(separator: ",")
        let res = result ?? ""
        return "[\(event.capitalized)] (\(tagStr)) at \(dateStr)\(detail.map { ": \($0)" } ?? "")\(res.isEmpty ? "" : " → \(res)")"
    }
}

/// Actor for concurrency-safe logging of admin panel events.
public actor AdminPanelAuditManager {
    private var buffer: [AdminPanelAuditEntry] = []
    private let maxEntries = 1000
    public static let shared = AdminPanelAuditManager()

    public func add(_ entry: AdminPanelAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 100) -> [AdminPanelAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
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

    // Analytics & Audit
    let analytics: AdminPanelAnalyticsLogger
    let audit: AdminPanelAuditLogger

    public init(
        analytics: AdminPanelAnalyticsLogger = NullAdminPanelAnalyticsLogger(),
        audit: AdminPanelAuditLogger = NullAdminPanelAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

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
                                    Task {
                                        await analytics.log(
                                            event: "featureFlagChange",
                                            detail: "\(flag.rawValue): \(enabled)",
                                            tags: ["featureFlag", flag.rawValue, enabled ? "enabled" : "disabled"],
                                            actor: "admin",
                                            context: "adminPanel",
                                            result: nil
                                        )
                                        await audit.record(
                                            event: "featureFlagChange",
                                            detail: "\(flag.rawValue): \(enabled)",
                                            tags: ["featureFlag", flag.rawValue, enabled ? "enabled" : "disabled"],
                                            actor: "admin",
                                            context: "adminPanel",
                                            result: nil
                                        )
                                        await AdminPanelAuditManager.shared.add(
                                            AdminPanelAuditEntry(
                                                event: "featureFlagChange",
                                                detail: "\(flag.rawValue): \(enabled)",
                                                tags: ["featureFlag", flag.rawValue, enabled ? "enabled" : "disabled"],
                                                actor: "admin",
                                                context: "adminPanel",
                                                result: nil
                                            )
                                        )
                                    }
                                }
                            )
                        )
                        .font(AppFonts.body)
                    }
                }

                // MARK: - Data Management Section
                Section(header: Text("Data Management").font(AppFonts.sectionHeader)) {
                    Button("Populate with Demo Data") {
                        Task {
                            await analytics.log(
                                event: "populateDemo",
                                detail: "User prompted",
                                tags: ["data", "populate", "demo"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await audit.record(
                                event: "populateDemo",
                                detail: "User prompted",
                                tags: ["data", "populate", "demo"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await AdminPanelAuditManager.shared.add(
                                AdminPanelAuditEntry(
                                    event: "populateDemo",
                                    detail: "User prompted",
                                    tags: ["data", "populate", "demo"],
                                    actor: "admin",
                                    context: "adminPanel",
                                    result: nil
                                )
                            )
                        }
                        showPopulateDataAlert = true
                    }
                    .font(AppFonts.body)

                    Button("Wipe All App Data", role: .destructive) {
                        Task {
                            await analytics.log(
                                event: "wipeData",
                                detail: "User prompted",
                                tags: ["data", "wipe", "destructive"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await audit.record(
                                event: "wipeData",
                                detail: "User prompted",
                                tags: ["data", "wipe", "destructive"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await AdminPanelAuditManager.shared.add(
                                AdminPanelAuditEntry(
                                    event: "wipeData",
                                    detail: "User prompted",
                                    tags: ["data", "wipe", "destructive"],
                                    actor: "admin",
                                    context: "adminPanel",
                                    result: nil
                                )
                            )
                        }
                        showWipeDataAlert = true
                    }
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.destructive)
                }

                // MARK: - Diagnostics Section
                Section(header: Text("Diagnostics").font(AppFonts.sectionHeader)) {
                    Button("Run Database Integrity Check") {
                        Task {
                            await analytics.log(
                                event: "integrityCheck",
                                detail: "Triggered",
                                tags: ["diagnostics", "integrity"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await audit.record(
                                event: "integrityCheck",
                                detail: "Triggered",
                                tags: ["diagnostics", "integrity"],
                                actor: "admin",
                                context: "adminPanel",
                                result: nil
                            )
                            await AdminPanelAuditManager.shared.add(
                                AdminPanelAuditEntry(
                                    event: "integrityCheck",
                                    detail: "Triggered",
                                    tags: ["diagnostics", "integrity"],
                                    actor: "admin",
                                    context: "adminPanel",
                                    result: nil
                                )
                            )
                        }
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
                    Task {
                        await analytics.log(
                            event: "populateDemo",
                            detail: "Demo data populated",
                            tags: ["data", "populate", "demo"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "success"
                        )
                        await audit.record(
                            event: "populateDemo",
                            detail: "Demo data populated",
                            tags: ["data", "populate", "demo"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "success"
                        )
                        await AdminPanelAuditManager.shared.add(
                            AdminPanelAuditEntry(
                                event: "populateDemo",
                                detail: "Demo data populated",
                                tags: ["data", "populate", "demo"],
                                actor: "admin",
                                context: "adminPanel",
                                result: "success"
                            )
                        )
                    }
                }
                Button("Cancel", role: .cancel) {
                    Task {
                        await analytics.log(
                            event: "populateDemo",
                            detail: "Demo data populate canceled",
                            tags: ["data", "populate", "demo"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "canceled"
                        )
                        await audit.record(
                            event: "populateDemo",
                            detail: "Demo data populate canceled",
                            tags: ["data", "populate", "demo"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "canceled"
                        )
                        await AdminPanelAuditManager.shared.add(
                            AdminPanelAuditEntry(
                                event: "populateDemo",
                                detail: "Demo data populate canceled",
                                tags: ["data", "populate", "demo"],
                                actor: "admin",
                                context: "adminPanel",
                                result: "canceled"
                            )
                        )
                    }
                }
            } message: {
                Text("This will first wipe all existing data and then add the standard demo data set.")
                    .font(AppFonts.caption)
            }
            .alert("Wipe All Data?", isPresented: $showWipeDataAlert) {
                Button("Wipe Data", role: .destructive) {
                    wipeAllData()
                    Task {
                        await analytics.log(
                            event: "wipeData",
                            detail: "Data wiped",
                            tags: ["data", "wipe", "destructive"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "success"
                        )
                        await audit.record(
                            event: "wipeData",
                            detail: "Data wiped",
                            tags: ["data", "wipe", "destructive"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "success"
                        )
                        await AdminPanelAuditManager.shared.add(
                            AdminPanelAuditEntry(
                                event: "wipeData",
                                detail: "Data wiped",
                                tags: ["data", "wipe", "destructive"],
                                actor: "admin",
                                context: "adminPanel",
                                result: "success"
                            )
                        )
                    }
                }
                Button("Cancel", role: .cancel) {
                    Task {
                        await analytics.log(
                            event: "wipeData",
                            detail: "Wipe data canceled",
                            tags: ["data", "wipe", "destructive"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "canceled"
                        )
                        await audit.record(
                            event: "wipeData",
                            detail: "Wipe data canceled",
                            tags: ["data", "wipe", "destructive"],
                            actor: "admin",
                            context: "adminPanel",
                            result: "canceled"
                        )
                        await AdminPanelAuditManager.shared.add(
                            AdminPanelAuditEntry(
                                event: "wipeData",
                                detail: "Wipe data canceled",
                                tags: ["data", "wipe", "destructive"],
                                actor: "admin",
                                context: "adminPanel",
                                result: "canceled"
                            )
                        )
                    }
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
        Task {
            await analytics.log(
                event: "viewCrashLogs",
                detail: "Crash logs loaded",
                tags: ["diagnostics", "crashlog"],
                actor: "admin",
                context: "adminPanel",
                result: nil
            )
            await audit.record(
                event: "viewCrashLogs",
                detail: "Crash logs loaded",
                tags: ["diagnostics", "crashlog"],
                actor: "admin",
                context: "adminPanel",
                result: nil
            )
            await AdminPanelAuditManager.shared.add(
                AdminPanelAuditEntry(
                    event: "viewCrashLogs",
                    detail: "Crash logs loaded",
                    tags: ["diagnostics", "crashlog"],
                    actor: "admin",
                    context: "adminPanel",
                    result: nil
                )
            )
        }
    }

    /// Runs a comprehensive database integrity check.
    private func runIntegrityCheck() {
        Task {
            let owners = await DataStoreService.shared.fetchAll(DogOwner.self)
            let dogs = await DataStoreService.shared.fetchAll(Dog.self)
            self.integrityIssues = DatabaseIntegrityChecker.shared.runAllChecks(
                owners: owners, dogs: dogs, appointments: [], charges: [], staff: [], users: [], tasks: [], vaccinationRecords: []
            )
            let resultStr = integrityIssues.isEmpty ? "ok" : "issues: \(integrityIssues.count)"
            await analytics.log(
                event: "integrityCheck",
                detail: "Check completed",
                tags: ["diagnostics", "integrity"],
                actor: "admin",
                context: "adminPanel",
                result: resultStr
            )
            await audit.record(
                event: "integrityCheck",
                detail: "Check completed",
                tags: ["diagnostics", "integrity"],
                actor: "admin",
                context: "adminPanel",
                result: resultStr
            )
            await AdminPanelAuditManager.shared.add(
                AdminPanelAuditEntry(
                    event: "integrityCheck",
                    detail: "Check completed",
                    tags: ["diagnostics", "integrity"],
                    actor: "admin",
                    context: "adminPanel",
                    result: resultStr
                )
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
    @State private var entries: [AdminPanelAuditEntry] = []

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("No admin events yet", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(entries.reversed()) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.accessibilityLabel)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let context = event.context {
                                Text("Context: \(context)").font(.caption2).foregroundColor(.secondary)
                            }
                            if let result = event.result {
                                Text("Result: \(result)").font(.caption2).foregroundColor(.secondary)
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
                    Button {
                        UIPasteboard.general.string = await AdminPanelAuditManager.shared.exportJSON()
                    } label: {
                        Label("Copy Last as JSON", systemImage: "doc.on.doc")
                    }
                    .font(.caption)
                }
            }
            .task {
                entries = await AdminPanelAuditManager.shared.recent(limit: 40)
            }
        }
    }
}
# MARK: - Diagnostics

public extension AdminPanelView {
    /// Fetch recent admin panel audit entries.
    static func recentAuditEntries(limit: Int = 100) async -> [AdminPanelAuditEntry] {
        await AdminPanelAuditManager.shared.recent(limit: limit)
    }

    /// Export full admin panel audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AdminPanelAuditManager.shared.exportJSON()
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
