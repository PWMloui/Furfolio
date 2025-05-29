//
//  ExportProfile.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import os

enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    var id: String { rawValue }
}

struct ExportProfileView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ExportProfileView")
    let dogOwner: DogOwner
    @State private var isSharing = false
    @State private var exportURL: URL?
    @State private var selectedFormat: ExportFormat = .json

    var body: some View {
        Menu {
            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            Button("Export") {
                logger.log("Export button tapped for format: \(selectedFormat.rawValue)")
                exportProfile(format: selectedFormat)
            }
        } label: {
            Label("Export Profile", systemImage: "square.and.arrow.up")
                .font(.headline)
        }
        .sheet(isPresented: $isSharing, onDismiss: {
            // Clean up temp file after sharing
            if let url = exportURL {
                try? FileManager.default.removeItem(at: url)
                exportURL = nil
            }
        }) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
            }
        }
    }

    private func exportProfile(format: ExportFormat) {
        logger.log("Starting exportProfile with format: \(format.rawValue) for owner id: \(dogOwner.id)")
        let data: Data?
        let fileExtension: String
        switch format {
        case .json:
            data = profileJSON()
            fileExtension = "json"
        case .csv:
            data = profileCSV()
            fileExtension = "csv"
        case .pdf:
            data = profilePDF()
            fileExtension = "pdf"
        }
        guard let data = data else { return }
        logger.log("Generated data of length: \(data.count) bytes")
        guard let url = saveToTempFile(data: data, fileExtension: fileExtension)
        else { return }
        exportURL = url
        isSharing = true
    }

    private func profileJSON() -> Data? {
        logger.log("Generating JSON profile")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(dogOwner)
    }

    private func profileCSV() -> Data? {
        logger.log("Generating CSV profile")
        let headers = ["Name","Contact","Address"]
        let values = [dogOwner.name, dogOwner.phone, dogOwner.address]
        let csvString = ([headers, values].map { $0.joined(separator: ",") }).joined(separator: "\n")
        return csvString.data(using: .utf8)
    }

    private func profilePDF() -> Data? {
        logger.log("Generating PDF profile")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let text = """
            Name: \(dogOwner.name)
            Contact: \(dogOwner.phone)
            Address: \(dogOwner.address)
            """
            let nsText = NSString(string: text)
            nsText.draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        }
    }

    private func saveToTempFile(data: Data, fileExtension: String = "json") -> URL? {
        logger.log("Saving data to temp file with extension: .\(fileExtension)")
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "DogOwnerProfile-\(UUID().uuidString).\(fileExtension)"
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: [.atomic])
            logger.log("Saved temp file at path: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("Failed to save temp file: \(error.localizedDescription)")
            return nil
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let url = activityItems.first as? URL {
            controller.excludedActivityTypes = []
            controller.setValue("Dog Owner Profile", forKey: "subject")
            controller.completionWithItemsHandler = { _, _, _, _ in
                // Optional: handle completion
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
