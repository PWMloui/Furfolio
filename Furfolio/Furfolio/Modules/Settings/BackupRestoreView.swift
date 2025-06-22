//
//  BackupRestoreView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct BackupRestoreView: View {
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var lastBackupDate: Date? = nil

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.accent)
                .padding(.top, 30)

            Text("Backup & Restore")
                .font(.largeTitle.bold())

            if let lastBackup = lastBackupDate {
                Text("Last backup: \(lastBackup, style: .date) \(lastBackup, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No backups yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Button {
                    backupData()
                } label: {
                    HStack {
                        if isBackingUp { ProgressView().progressViewStyle(.circular) }
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

                Button {
                    restoreData()
                } label: {
                    HStack {
                        if isRestoring { ProgressView().progressViewStyle(.circular) }
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
            }
            .padding(.top)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(isBackingUp ? "Backup completed successfully." : "Restore completed successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Backup Logic (stubbed, replace with actual file/database backup)
    private func backupData() {
        isBackingUp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isBackingUp = false
            lastBackupDate = Date()
            showSuccessAlert = true
        }
    }

    // MARK: - Restore Logic (stubbed, replace with actual restore logic)
    private func restoreData() {
        isRestoring = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRestoring = false
            // On error, set showErrorAlert = true and errorMessage = "Restore failed."
            showSuccessAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}
