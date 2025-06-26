//
//  BackupRestoreView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Backup/Restore
//

import SwiftUI

struct BackupRestoreView: View {
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var lastBackupDate: Date? = nil
    @State private var showAuditLog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.accent)
                    .padding(.top, 30)
                    .accessibilityIdentifier("BackupRestoreView-Icon")

                Text("Backup & Restore")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("BackupRestoreView-Title")

                SectionCard {
                    if let lastBackup = lastBackupDate {
                        Text("Last backup: \(lastBackup, style: .date) \(lastBackup, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("BackupRestoreView-LastBackup")
                    } else {
                        Text("No backups yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("BackupRestoreView-NoBackup")
                    }
                }

                SectionCard {
                    VStack(spacing: 16) {
                        Button {
                            backupData()
                        } label: {
                            HStack {
                                if isBackingUp {
                                    ProgressView().progressViewStyle(.circular)
                                        .accessibilityIdentifier("BackupRestoreView-BackupSpinner")
                                }
                                Text("Backup Now")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundStyle(.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isBackingUp || isRestoring)
                        .accessibilityIdentifier("BackupRestoreView-BackupButton")

                        Button {
                            restoreData()
                        } label: {
                            HStack {
                                if isRestoring {
                                    ProgressView().progressViewStyle(.circular)
                                        .accessibilityIdentifier("BackupRestoreView-RestoreSpinner")
                                }
                                Text("Restore Backup")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isBackingUp || isRestoring)
                        .accessibilityIdentifier("BackupRestoreView-RestoreButton")
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        showAuditLog = true
                    } label: {
                        Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("BackupRestoreView-AuditLogButton")
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(isBackingUp ? "Backup completed successfully." : "Restore completed successfully.")
                .accessibilityIdentifier("BackupRestoreView-SuccessMessage")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
                .foregroundStyle(.red)
                .accessibilityIdentifier("BackupRestoreView-ErrorMessage")
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(BackupRestoreAuditAdmin.recentEvents(limit: 20), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = BackupRestoreAuditAdmin.recentEvents(limit: 20).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("BackupRestoreView-CopyAuditLogButton")
                    }
                }
            }
        }
    }

    // MARK: - Backup Logic (stub, replace with actual file/database backup)
    private func backupData() {
        isBackingUp = true
        BackupRestoreAudit.record(action: "StartBackup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isBackingUp = false
            lastBackupDate = Date()
            showSuccessAlert = true
            BackupRestoreAudit.record(action: "BackupSuccess")
        }
    }

    // MARK: - Restore Logic (stub, replace with actual restore logic)
    private func restoreData() {
        isRestoring = true
        BackupRestoreAudit.record(action: "StartRestore")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRestoring = false
            // On error, set showErrorAlert = true and errorMessage = "Restore failed."
            showSuccessAlert = true
            BackupRestoreAudit.record(action: "RestoreSuccess")
        }
    }
}

// MARK: - Card Section Helper

fileprivate struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color(.black).opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .padding(.vertical, 2)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct BackupRestoreAuditEvent: Codable {
    let timestamp: Date
    let action: String
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[BackupRestoreView] \(action) at \(df.string(from: timestamp))"
    }
}
fileprivate final class BackupRestoreAudit {
    static private(set) var log: [BackupRestoreAuditEvent] = []
    static func record(action: String) {
        let event = BackupRestoreAuditEvent(timestamp: Date(), action: action)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum BackupRestoreAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { BackupRestoreAudit.recentSummaries(limit: limit) }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}
