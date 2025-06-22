//
//  DatabaseDiagnosticsView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A view within the Admin Panel to run database integrity checks
//  and display any found issues, using the DatabaseIntegrityChecker service.
//

import SwiftUI

// MARK: - DatabaseDiagnosticsView (Tokenized, Modular, Audit-Ready Diagnostics UI)

/// A modular, tokenized, and audit-ready view that displays the results of a database integrity check.
/// This view follows Furfolio's design conventions using AppColors, AppFonts, and AppSpacing tokens
/// to ensure consistent theming, accessibility, and maintainability within the Admin Panel.
struct DatabaseDiagnosticsView: View {
    
    /// The list of integrity issues found by the checker.
    let issues: [IntegrityIssue]
    
    /// The action to re-run the diagnostic check.
    let onRunCheck: () -> Void

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
                Button("Run Again", systemImage: "arrow.clockwise", action: onRunCheck)
            }
        }
    }
}

// MARK: - IntegrityIssueRow (Tokenized Issue Row View)

/// A private, tokenized, and modular helper view to display a single integrity issue row.
/// This view utilizes Furfolio's design tokens for colors, fonts, and spacing to maintain
/// consistency and audit-readiness across the diagnostics UI.
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


// MARK: - Preview

#if DEBUG
struct DatabaseDiagnosticsView_Previews: PreviewProvider {
    
    // Wrapper view to manage state for the preview
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
