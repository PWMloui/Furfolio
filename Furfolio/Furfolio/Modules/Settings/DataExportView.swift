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

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "square.and.arrow.up")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.accent)
                .padding(.top, 30)

            Text("Export Data")
                .font(.largeTitle.bold())

            Text("Export your Furfolio data for backup, migration, or analysis. All exported files are private and only accessible by you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue)
                        .tag(format)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                exportData()
            } label: {
                HStack {
                    if isExporting { ProgressView().progressViewStyle(.circular) }
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

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Data Export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data was exported successfully!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
    }

    // MARK: - Export Logic (replace with your data export)
    private func exportData() {
        isExporting = true
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
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to export: \(error.localizedDescription)"
                    showError = true
                    isExporting = false
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

#Preview {
    NavigationStack {
        DataExportView()
    }
}
