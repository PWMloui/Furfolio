// DataExportView.swift


import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    var id: String { rawValue }
}

struct DataExportView: View {
    @State private var isExporting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportURL: URL?
    @State private var selectedFormat: ExportFormat = .csv
    @State private var showAuditLog = false
    @State private var animateBadge = false
    @State private var appearedOnce = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.13))
                        .frame(width: 90, height: 90)
                        .scaleEffect(animateBadge ? 1.09 : 1.0)
                        .animation(.spring(response: 0.33, dampingFraction: 0.55), value: animateBadge)
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.accent)
                        .accessibilityIdentifier("DataExportView-Icon")
                }
                .padding(.top, 30)

                Text("Export Data")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("DataExportView-Title")

                Text("Export your Furfolio data for backup, migration, or analysis. All exported files are private and only accessible by you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityIdentifier("DataExportView-Subtitle")

                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue)
                            .tag(format)
                            .accessibilityIdentifier("DataExportView-Format-\(format.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityIdentifier("DataExportView-FormatPicker")

                Button {
                    exportData()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView().progressViewStyle(.circular)
                                .accessibilityIdentifier("DataExportView-ExportSpinner")
                        }
                        Text("Export Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundStyle(.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isExporting)
                .accessibilityIdentifier("DataExportView-ExportButton")

                HStack {
                    Spacer()
                    Button {
                        showAuditLog = true
                    } label: {
                        Label("View Export Log", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("DataExportView-AuditLogButton")
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Data Export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data was exported successfully!")
                .accessibilityIdentifier("DataExportView-SuccessMessage")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
                .foregroundStyle(.red)
                .accessibilityIdentifier("DataExportView-ErrorMessage")
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(DataExportAuditAdmin.recentEvents(limit: 20), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Export Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = DataExportAuditAdmin.recentEvents(limit: 20).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("DataExportView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                DataExportAudit.record(action: "Appear", detail: "View loaded")
                appearedOnce = true
            }
        }
    }

    // MARK: - Export Logic (replace with your data export)
    private func exportData() {
        isExporting = true
        animateBadge = true
        DataExportAudit.record(action: "ExportStart", detail: selectedFormat.rawValue)
        DispatchQueue.global(qos: .userInitiated).async {
            let fileName: String
            let fileData: Data

            switch selectedFormat {
            case .csv:
                fileName = "FurfolioExport-\(Date().timeIntervalSince1970).csv"
                let sampleData = "Owner,Dog,Appointment,Amount\nJane Doe,Bella,2025-06-19,85.00"
                fileData = Data(sampleData.utf8)
            case .json:
                fileName = "FurfolioExport-\(Date().timeIntervalSince1970).json"
                let sampleDict: [[String: Any]] = [
                    ["owner": "Jane Doe", "dog": "Bella", "appointment": "2025-06-19", "amount": 85.0]
                ]
                do {
                    fileData = try JSONSerialization.data(withJSONObject: sampleDict, options: .prettyPrinted)
                } catch {
                    DispatchQueue.main.async {
                        errorMessage = "Failed to encode JSON: \(error.localizedDescription)"
                        showError = true
                        isExporting = false
                        animateBadge = false
                        DataExportAudit.record(action: "ExportError", detail: error.localizedDescription)
                    }
                    return
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try fileData.write(to: fileURL)
                DispatchQueue.main.async {
                    exportURL = fileURL
                    isExporting = false
                    showSuccess = true
                    animateBadge = false
                    DataExportAudit.record(action: "ExportSuccess", detail: fileName)
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to export: \(error.localizedDescription)"
                    showError = true
                    isExporting = false
                    animateBadge = false
                    DataExportAudit.record(action: "ExportError", detail: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Audit/Event Logging

fileprivate struct DataExportAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[DataExportView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class DataExportAudit {
    static private(set) var log: [DataExportAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = DataExportAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 12) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum DataExportAuditAdmin {
    public static func recentEvents(limit: Int = 12) -> [String] { DataExportAudit.recentSummaries(limit: limit) }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
