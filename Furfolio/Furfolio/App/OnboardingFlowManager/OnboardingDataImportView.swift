//
//  OnboardingDataImportView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import SwiftUI

/// Onboarding step for importing demo/sample data or user files.
struct OnboardingDataImportView: View {
    enum ImportState {
        case idle
        case loading
        case success
        case failed(String)
    }

    @State private var importState: ImportState = .idle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            header

            description

            statusIndicator

            importButtons
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .foregroundColor(.accentColor)
                .accessibilityLabel("Import Icon")

            Text("Import Sample Data")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Get started faster by importing demo clients, appointments, and charge history. Or skip and add your own data later!")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top, 24)
        .padding(.horizontal)
    }

    private var statusIndicator: some View {
        VStack(spacing: 8) {
            switch importState {
            case .loading:
                ProgressView("Importing…")
                    .progressViewStyle(CircularProgressViewStyle())
            case .success:
                Label("Demo data imported!", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            case .failed(let message):
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal)
    }

    private var importButtons: some View {
        VStack(spacing: 12) {
            Button {
                importDemoData()
            } label: {
                Label("Import Demo Data", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(importState == .loading || importState == .success)

            Button {
                // Future: File picker logic
            } label: {
                Label("Import from File (CSV, JSON)", systemImage: "doc.fill.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(true) // Coming soon

            Button("Skip") {
                dismiss()
            }
            .foregroundColor(.accentColor)
            .padding(.top, 12)
        }
    }

    // MARK: - Logic

    private func importDemoData() {
        importState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate loading

            do {
                await DemoDataManager.shared.populateDemoData(in: modelContext)
                importState = .success
            } catch {
                importState = .failed("Could not import demo data. Please try again.")
            }
        }
    }
}

#Preview {
    OnboardingDataImportView()
        .environment(\.modelContext, .init(DemoDataManager.shared))
}
