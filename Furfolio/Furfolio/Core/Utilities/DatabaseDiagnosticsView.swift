//
//  DatabaseDiagnosticsView.swift
//  Furfolio
//
//  ENHANCED: Auditable, Tokenized, BI/Compliance-Ready Database Integrity Diagnostics UI (2025)
//


import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol DatabaseDiagnosticsAnalyticsLogger {
    /// Log a diagnostics event asynchronously.
    func log(event: String, issueCount: Int, tags: [String]) async
}

public protocol DatabaseDiagnosticsAuditLogger {
    /// Record a diagnostics audit entry asynchronously.
    func record(event: String, issueCount: Int, tags: [String], detail: String?) async
}

public struct NullDatabaseDiagnosticsAnalyticsLogger: DatabaseDiagnosticsAnalyticsLogger {
    public init() {}
    public func log(event: String, issueCount: Int, tags: [String]) async {}
}

public struct NullDatabaseDiagnosticsAuditLogger: DatabaseDiagnosticsAuditLogger {
    public init() {}
    public func record(event: String, issueCount: Int, tags: [String], detail: String?) async {}
}

// MARK: - In-Memory Audit Actor

/// A record of a diagnostics audit event.
public struct DiagnosticsAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let issueCount: Int
    public let tags: [String]
    public let detail: String?
}

/// Actor for concurrency-safe diagnostics audit logging.
public actor DiagnosticsAuditManager {
    private var buffer: [DiagnosticsAuditEntry] = []
    private let maxEntries = 1000
    public static let shared = DiagnosticsAuditManager()

    public func add(_ entry: DiagnosticsAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 100) -> [DiagnosticsAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportLastJSON() -> String? {
        guard let last = buffer.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(last) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}


// MARK: - DatabaseDiagnosticsView (Tokenized, Modular, Audit-Ready Diagnostics UI)

public struct DatabaseDiagnosticsView: View {
    let issues: [IntegrityIssue]
    let onRunCheck: () -> Void
    let analytics: DatabaseDiagnosticsAnalyticsLogger
    let audit: DatabaseDiagnosticsAuditLogger

    @State private var showAuditSheet = false

    public init(
        issues: [IntegrityIssue],
        onRunCheck: @escaping () -> Void,
        analytics: DatabaseDiagnosticsAnalyticsLogger = NullDatabaseDiagnosticsAnalyticsLogger(),
        audit: DatabaseDiagnosticsAuditLogger = NullDatabaseDiagnosticsAuditLogger()
    ) {
        self.issues = issues
        self.onRunCheck = onRunCheck
        self.analytics = analytics
        self.audit = audit
    }

    public var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    Image(systemName: issues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(issues.isEmpty ? AppColors.success : AppColors.warning)
                    VStack(alignment: .leading) {
                        Text(issues.isEmpty ? "No Issues Found" : "\(issues.count) Issues Found")
                            .font(AppFonts.headline)
                        Text(issues.isEmpty ? "Your database integrity looks good." : "Review the issues below.")
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }

            // Issues List Section
            if !issues.isEmpty {
                Section(header: Text("Detected Issues")) {
                    ForEach(issues) { issue in
                        IntegrityIssueRow(issue: issue)
                    }
                }
            }
        }
        .navigationTitle("Database Diagnostics")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        let tags = ["run", issues.isEmpty ? "noIssues" : "issuesFound"]
                        await analytics.log(event: "run", issueCount: issues.count, tags: tags)
                        await audit.record(event: "run", issueCount: issues.count, tags: tags,
                                           detail: issues.isEmpty ? "No issues" : "\(issues.count) issues")
                        await DiagnosticsAuditManager.shared.add(
                            DiagnosticsAuditEntry(
                                id: UUID(), timestamp: Date(),
                                operation: "run", issueCount: issues.count,
                                tags: tags,
                                detail: issues.isEmpty ? "No issues" : "\(issues.count) issues"
                            )
                        )
                    }
                    onRunCheck()
                } label: {
                    Label("Run Again", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAuditSheet = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .accessibilityLabel("View Diagnostics Audit Events")
                }
            }
        }
        .onAppear {
            Task {
                let tags = ["view", issues.isEmpty ? "noIssues" : "issuesFound"]
                await analytics.log(event: "view", issueCount: issues.count, tags: tags)
                await audit.record(event: "view", issueCount: issues.count, tags: tags, detail: nil)
                await DiagnosticsAuditManager.shared.add(
                    DiagnosticsAuditEntry(
                        id: UUID(), timestamp: Date(),
                        operation: "view", issueCount: issues.count,
                        tags: tags, detail: nil
                    )
                )
            }
        }
        .sheet(isPresented: $showAuditSheet) {
            DiagnosticsAuditSheetView(isPresented: $showAuditSheet)
        }
    }
}

// MARK: - IntegrityIssueRow (Tokenized Issue Row View)

private struct IntegrityIssueRow: View {
    let issue: IntegrityIssue

    private var icon: (name: String, color: Color) {
        switch issue.type {
        case .orphanedDog, .orphanedAppointment, .orphanedCharge:
            return ("link.badge.plus", AppColors.warning)
        case .duplicateID:
            return ("doc.on.doc.fill", AppColors.critical)
        case .dogNoAppointments, .ownerNoDogs:
            return ("questionmark.circle.fill", AppColors.info)
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: icon.name)
                .font(AppFonts.title2)
                .foregroundColor(icon.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(issue.type.rawValue)
                    .font(AppFonts.headline)
                Text(issue.message)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                Text("Entity ID: \(issue.entityID)")
                    .font(AppFonts.caption2Monospaced)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(.vertical, AppSpacing.small)
    }
}

// MARK: - Audit Sheet for Admin/Trust Center

private struct DiagnosticsAuditSheetView: View {
    @Binding var isPresented: Bool
    @State private var entries: [DiagnosticsAuditEntry] = []
    @State private var lastJSON: String? = nil

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("No Diagnostics Events", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            let dateStr = DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .short)
                            Text("[\(entry.operation.capitalized)] \(entry.issueCount) issues at \(dateStr)\(entry.detail != nil ? ": \(entry.detail!)" : "")")
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text("Detail: \(detail)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Diagnostics Audit Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let json = lastJSON {
                        Button {
                            UIPasteboard.general.string = json
                        } label: {
                            Label("Copy Last as JSON", systemImage: "doc.on.doc")
                        }
                        .font(.caption)
                    }
                }
            }
            .onAppear {
                Task {
                    self.entries = await DiagnosticsAuditManager.shared.recent(limit: 40)
                    self.lastJSON = await DiagnosticsAuditManager.shared.exportLastJSON()
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#if DEBUG
struct DatabaseDiagnosticsView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var issues: [IntegrityIssue] = [
            .init(type: .orphanedDog, message: "Dog 'Bella' is not linked to any owner.", entityID: UUID().uuidString),
            .init(type: .duplicateID, message: "Duplicate ID found in: DogOwner, Appointment.", entityID: UUID().uuidString),
            .init(type: .ownerNoDogs, message: "Owner 'John Smith' has no dogs.", entityID: UUID().uuidString)
        ]

        var body: some View {
            NavigationStack {
                DatabaseDiagnosticsView(issues: issues) {
                    // Simulate re-running the check and finding no issues
                    if issues.isEmpty {
                        issues = [
                            .init(type: .orphanedDog, message: "Dog 'Bella' is not linked to any owner.", entityID: UUID().uuidString)
                        ]
                    } else {
                        issues.removeAll()
                    }
                }
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

// MARK: - Diagnostics Helpers

public extension DatabaseDiagnosticsView {
    /// Fetch recent audit entries.
    static func recentAuditEntries(limit: Int = 100) async -> [DiagnosticsAuditEntry] {
        await DiagnosticsAuditManager.shared.recent(limit: limit)
    }

    /// Export last audit entry as JSON.
    static func exportLastAuditJSON() async -> String? {
        await DiagnosticsAuditManager.shared.exportLastJSON()
    }
}
