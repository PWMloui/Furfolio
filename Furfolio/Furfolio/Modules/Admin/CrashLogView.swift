//
//  CrashLogView.swift
//  Furfolio
//
//  ENHANCED: Auditable, Tokenized, BI/Compliance-Ready Crash/Error Log UI (2025)
//

import SwiftUI
import SwiftData

// MARK: - CrashLog Audit/Event Logging

fileprivate struct CrashLogAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "view", "delete", "inspect"
    let reportType: String?
    let resolved: Bool?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let status = resolved == nil ? "" : (resolved! ? "✅" : "❌")
        let type = reportType ?? ""
        let desc = detail.map { ": \($0)" } ?? ""
        return "[\(operation.capitalized)] \(type) \(status) at \(dateStr)\(desc)"
    }
}

fileprivate final class CrashLogAudit {
    static private(set) var log: [CrashLogAuditEvent] = []

    static func record(
        operation: String,
        report: CrashReport? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        detail: String? = nil
    ) {
        let event = CrashLogAuditEvent(
            timestamp: Date(),
            operation: operation,
            reportType: report?.type,
            resolved: report?.resolved,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No crash log actions recorded."
    }
}

// MARK: - CrashLogView (Tokenized, Modular, Auditable Crash/Error Log UI)

struct CrashLogView: View {
    @Environment(\.modelContext) private var modelContext

    // The reports are fetched once and passed into this view.
    @State private var reports: [CrashReport]

    @State private var showAuditSheet = false

    init(reports: [CrashReport]) {
        _reports = State(initialValue: reports)
    }

    var body: some View {
        List {
            if reports.isEmpty {
                ContentUnavailableView(
                    "No Crash Logs",
                    systemImage: "ladybug.fill",
                    description: Text("No crashes or fatal errors have been logged.")
                )
                .onAppear {
                    CrashLogAudit.record(
                        operation: "view",
                        tags: ["empty", "list"],
                        actor: "admin",
                        context: "CrashLogView",
                        detail: "No crash logs"
                    )
                }
            } else {
                ForEach(reports) { report in
                    NavigationLink(destination: {
                        CrashLogDetailView(report: report)
                            .onAppear {
                                CrashLogAudit.record(
                                    operation: "inspect",
                                    report: report,
                                    tags: ["detail", report.resolved ? "resolved" : "unresolved"],
                                    actor: "admin",
                                    context: "CrashLogDetailView",
                                    detail: report.message
                                )
                            }
                    }) {
                        CrashLog_RowView(report: report)
                    }
                }
                .onDelete(perform: deleteReport)
            }
        }
        .navigationTitle("Crash & Error Logs")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !reports.isEmpty { EditButton() }
                Button {
                    showAuditSheet = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .accessibilityLabel("View Crash Log Audit Events")
                }
            }
        }
        .sheet(isPresented: $showAuditSheet) {
            CrashLogAuditSheetView(isPresented: $showAuditSheet)
        }
        .onAppear {
            CrashLogAudit.record(
                operation: "view",
                tags: ["list"],
                actor: "admin",
                context: "CrashLogView",
                detail: "\(reports.count) logs"
            )
        }
    }

    private func deleteReport(at offsets: IndexSet) {
        let reportsToDelete = offsets.map { reports[$0] }
        for report in reportsToDelete {
            CrashReporter.shared.delete(report: report, context: modelContext)
            CrashLogAudit.record(
                operation: "delete",
                report: report,
                tags: ["delete", report.resolved ? "resolved" : "unresolved"],
                actor: "admin",
                context: "CrashLogView",
                detail: report.message
            )
        }
        reports.remove(atOffsets: offsets)
    }
}

/// A private helper view for displaying a single crash log row.
private struct CrashLog_RowView: View {
    let report: CrashReport

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(report.type)
                    .font(AppFonts.headline)
                    .foregroundColor(report.resolved ? AppColors.textSecondary : AppColors.danger)

                Text(report.message)
                    .font(AppFonts.caption)
                    .lineLimit(2)
                    .foregroundColor(AppColors.textSecondary)

                Text(report.date, style: .date)
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.secondaryText)
            }
            Spacer()
            if report.resolved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                    .accessibilityLabel("Resolved")
            }
        }
        .padding(.vertical, AppSpacing.small)
    }
}

/// A detail view to show the full information for a single crash report.
struct CrashLogDetailView: View {
    let report: CrashReport

    var body: some View {
        Form {
            Section("Error Details") {
                LabeledContent("Type", value: report.type)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                LabeledContent("Date", value: report.date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Section("Message") {
                Text(report.message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            if let deviceInfo = report.deviceInfo {
                Section("Device Info") {
                    Text(deviceInfo)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            if let stackTrace = report.stackTrace {
                Section("Stack Trace") {
                    ScrollView {
                        Text(stackTrace)
                            .font(AppFonts.captionMonospaced)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 200)
                }
            }
        }
        .navigationTitle("Log Details")
    }
}

// MARK: - CrashLog Audit Sheet for Admin/QA/Trust Center

private struct CrashLogAuditSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if CrashLogAudit.log.isEmpty {
                    ContentUnavailableView("No Crash Log Events Yet", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(CrashLogAudit.log.suffix(40).reversed(), id: \.timestamp) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.accessibilityLabel)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            if let context = event.context, !context.isEmpty {
                                Text("Context: \(context)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Crash Log Audit Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let json = CrashLogAudit.exportLastJSON() {
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
#Preview {
    let container = try! ModelContainer(for: CrashReport.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let resolvedReport = CrashReport(type: "Data Corruption", message: "Owner record was missing a dog link.", resolved: true)
    let unresolvedReport = CrashReport(type: "Fatal Error", message: "Failed to save appointment due to network timeout simulation.", stackTrace: "Thread 0 crashed with exception an.. \n0x10... main + 23\n0x1f... start + 43", deviceInfo: "iPhone 15 Pro, iOS 18.0")

    context.insert(resolvedReport)
    context.insert(unresolvedReport)

    return NavigationStack {
        CrashLogView(reports: [resolvedReport, unresolvedReport])
    }
    .modelContainer(container)
}
