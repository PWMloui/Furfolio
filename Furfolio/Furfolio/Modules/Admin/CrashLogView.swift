//
//  CrashLogView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A view within the Admin Panel to display and manage
//  logged crash and error reports from the CrashReporter service.
//

import SwiftUI
import SwiftData

// MARK: - CrashLogView (Modular, Tokenized, Auditable Crash/Error Log UI)

/// A modular, tokenized, auditable crash and error log UI component for the Admin Panel.
/// This view supports analytics, compliance, diagnostics, business reporting,
/// UI badge/integration, and audit/event trails. It is designed for owner-focused dashboards,
/// error forensics, and compliance dashboards, providing a comprehensive interface to
/// view, manage, and analyze crash reports collected by the `CrashReporter`.
struct CrashLogView: View {
    @Environment(\.modelContext) private var modelContext
    
    // The reports are fetched once and passed into this view.
    @State private var reports: [CrashReport]
    
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
            } else {
                ForEach(reports) { report in
                    NavigationLink(destination: CrashLogDetailView(report: report)) {
                        CrashLog_RowView(report: report)
                    }
                }
                .onDelete(perform: deleteReport)
            }
        }
        .navigationTitle("Crash & Error Logs")
        .toolbar {
            if !reports.isEmpty {
                EditButton()
            }
        }
    }
    
    private func deleteReport(at offsets: IndexSet) {
        let reportsToDelete = offsets.map { reports[$0] }
        for report in reportsToDelete {
            CrashReporter.shared.delete(report: report, context: modelContext)
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
                    // TODO: Create a secondary/subtle text color token for opacity 0.7 effect
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
                            // TODO: Create AppFonts.captionMonospaced token for monospaced caption font
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


// MARK: - Preview
#Preview {
    // Demo/business/tokenized preview intent: showcasing CrashLogView with token-based fonts, colors, and spacing.
    let container = try! ModelContainer(for: CrashReport.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    
    // Create sample logs
    let resolvedReport = CrashReport(type: "Data Corruption", message: "Owner record was missing a dog link.", resolved: true)
    let unresolvedReport = CrashReport(type: "Fatal Error", message: "Failed to save appointment due to network timeout simulation.", stackTrace: "Thread 0 crashed with exception an.. \n0x10... main + 23\n0x1f... start + 43", deviceInfo: "iPhone 15 Pro, iOS 18.0")
    
    context.insert(resolvedReport)
    context.insert(unresolvedReport)
    
    return NavigationStack {
        CrashLogView(reports: [resolvedReport, unresolvedReport])
    }
    .modelContainer(container)
}
