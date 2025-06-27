//
//  DatabaseDiagnosticsView.swift
//  Furfolio
//
//  ENHANCED: Auditable, Tokenized, BI/Compliance-Ready Database Integrity Diagnostics UI (2025)
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DiagnosticsAuditEvent: Codable {
    let timestamp: Date
    let operation: String         // "view", "run"
    let issueCount: Int
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(issueCount) issues at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class DiagnosticsAudit {
    static private(set) var log: [DiagnosticsAuditEvent] = []

    static func record(
        operation: String,
        issueCount: Int,
        tags: [String] = [],
        actor: String? = "admin",
        context: String? = nil,
        detail: String? = nil
    ) {
        let event = DiagnosticsAuditEvent(
            timestamp: Date(),
            operation: operation,
            issueCount: issueCount,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
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
        log.last?.accessibilityLabel ?? "No diagnostics events recorded."
    }
}

// MARK: - DatabaseDiagnosticsView (Tokenized, Modular, Audit-Ready Diagnostics UI)

struct DatabaseDiagnosticsView: View {
    /// The list of integrity issues found by the checker.
    let issues: [IntegrityIssue]

    /// The action to re-run the diagnostic check.
    let onRunCheck: () -> Void

    @State private var showAuditSheet = false

    var body: some View {
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
                    DiagnosticsAudit.record(
                        operation: "run",
                        issueCount: issues.count,
                        tags: ["run", issues.isEmpty ? "noIssues" : "issuesFound"],
                        actor: "admin",
                        context: "DatabaseDiagnosticsView",
                        detail: issues.isEmpty ? "No issues" : "\(issues.count) issues"
                    )
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
            DiagnosticsAudit.record(
                operation: "view",
                issueCount: issues.count,
                tags: ["view", issues.isEmpty ? "noIssues" : "issuesFound"],
                actor: "admin",
                context: "DatabaseDiagnosticsView"
            )
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

    var body: some View {
        NavigationStack {
            List {
                if DiagnosticsAudit.log.isEmpty {
                    ContentUnavailableView("No Diagnostics Events", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(DiagnosticsAudit.log.suffix(40).reversed(), id: \.timestamp) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.accessibilityLabel)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let context = event.context, !context.isEmpty {
                                Text("Context: \(context)").font(.caption2).foregroundColor(.secondary)
                            }
                            if let detail = event.detail, !detail.isEmpty {
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
                    if let json = DiagnosticsAudit.exportLastJSON() {
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

// MARK: - Preview

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
