//
//  DogDocumentUploadView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Document Upload View
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Document Model

struct DogDocument: Identifiable, Equatable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let thumbnailName: String? // for audit log and previews
    var thumbnail: Image? {
        if let thumbnailName {
            return Image(systemName: thumbnailName)
        }
        return nil
    }

    init(url: URL, name: String, thumbnailName: String? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.thumbnailName = thumbnailName
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogDocumentAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let documentName: String
    let documentType: String
    let context: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(action)] \(documentName) (\(documentType)) \(context ?? "") at \(dateStr)"
    }
}
fileprivate final class DogDocumentAudit {
    static private(set) var log: [DogDocumentAuditEvent] = []

    static func record(action: String, doc: DogDocument, context: String? = nil) {
        let event = DogDocumentAuditEvent(
            timestamp: Date(),
            action: action,
            documentName: doc.name,
            documentType: doc.url.pathExtension.uppercased(),
            context: context
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - ViewModel

@MainActor
class DogDocumentUploadViewModel: ObservableObject {
    @Published var documents: [DogDocument] = []
    @Published var previewDocument: DogDocument? = nil
    @Published var recentlyDeleted: DogDocument? = nil

    func addDocument(url: URL) {
        let name = url.lastPathComponent
        let thumbnailName = DogDocumentUploadViewModel.thumbnailName(for: url)
        let newDoc = DogDocument(url: url, name: name, thumbnailName: thumbnailName)
        documents.append(newDoc)
        DogDocumentAudit.record(action: "Add", doc: newDoc)
    }

    func removeDocument(_ doc: DogDocument) {
        if let index = documents.firstIndex(of: doc) {
            documents.remove(at: index)
            recentlyDeleted = doc
            DogDocumentAudit.record(action: "Remove", doc: doc)
        }
    }

    func undoRemove() {
        if let doc = recentlyDeleted {
            documents.append(doc)
            DogDocumentAudit.record(action: "UndoRemove", doc: doc)
            recentlyDeleted = nil
        }
    }

    func preview(_ doc: DogDocument) {
        previewDocument = doc
        DogDocumentAudit.record(action: "Preview", doc: doc)
    }

    static func thumbnailName(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "jpg", "jpeg", "png": return "photo"
        default: return "doc.text"
        }
    }
}

// MARK: - Main View

struct DogDocumentUploadView: View {
    @StateObject private var viewModel = DogDocumentUploadViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingDocumentPicker = false

    var body: some View {
        VStack {
            if viewModel.documents.isEmpty {
                Text("No documents uploaded yet.")
                    .foregroundColor(.secondary)
                    .padding()
                    .accessibilityIdentifier("DogDocumentUploadView-Empty")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.documents) { doc in
                            VStack(spacing: 8) {
                                Button(action: {
                                    viewModel.preview(doc)
                                }) {
                                    if let thumbnail = doc.thumbnail {
                                        thumbnail
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .cornerRadius(8)
                                            .accessibilityLabel("Preview document \(doc.name)")
                                    } else {
                                        Image(systemName: "doc.text")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .foregroundColor(.secondary)
                                            .accessibilityLabel("Preview document \(doc.name)")
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityIdentifier("DogDocumentUploadView-Preview-\(doc.name)")

                                Text(doc.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 80)
                                    .accessibilityIdentifier("DogDocumentUploadView-Name-\(doc.name)")

                                Button(action: {
                                    viewModel.removeDocument(doc)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .accessibilityLabel("Delete document \(doc.name)")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("DogDocumentUploadView-Delete-\(doc.name)")
                            }
                        }
                    }
                    .padding()
                }
            }

            if let deleted = viewModel.recentlyDeleted {
                Button(action: {
                    viewModel.undoRemove()
                }) {
                    Label("Undo Delete \(deleted.name)", systemImage: "arrow.uturn.backward")
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 4)
                .accessibilityIdentifier("DogDocumentUploadView-UndoDelete-\(deleted.name)")
            }

            HStack(spacing: 20) {
                PhotosPicker(
                    selection: $selectedItems,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add Document", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                .onChange(of: selectedItems) { newItems in
                    for item in newItems {
                        loadItem(item)
                    }
                    selectedItems.removeAll()
                }
                .accessibilityIdentifier("DogDocumentUploadView-AddPhoto")

                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Label("Add File", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                .fileImporter(
                    isPresented: $showingDocumentPicker,
                    allowedContentTypes: [UTType.pdf, UTType.image, UTType.text],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            viewModel.addDocument(url: url)
                        }
                    case .failure(let error):
                        print("File import error: \(error.localizedDescription)")
                    }
                }
                .accessibilityIdentifier("DogDocumentUploadView-AddFile")
            }
            .padding()
        }
        .navigationTitle("Dog Documents")
        .accessibilityElement(children: .contain)
        .sheet(item: $viewModel.previewDocument) { doc in
            DocumentPreviewView(document: doc)
        }
    }

    private func loadItem(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                        do {
                            try data.write(to: tempUrl)
                            viewModel.addDocument(url: tempUrl)
                        } catch {
                            print("Error saving picked photo: \(error)")
                        }
                    }
                case .failure(let error):
                    print("Failed to load photo data: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview/Document Views

struct DocumentPreviewView: View {
    let document: DogDocument
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            if document.url.isFileURL {
                if let uiImage = UIImage(contentsOfFile: document.url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .navigationTitle(document.name)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                } else if document.url.pathExtension.lowercased() == "pdf" {
                    PDFKitView(url: document.url)
                        .navigationTitle(document.name)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                } else {
                    Text("Preview not available")
                        .foregroundColor(.secondary)
                        .navigationTitle(document.name)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                }
            } else {
                Text("Preview not available")
                    .foregroundColor(.secondary)
                    .navigationTitle(document.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) { }
}

// MARK: - Audit/Admin Accessors

public enum DogDocumentUploadAuditAdmin {
    public static func lastSummary() -> String { DogDocumentAudit.log.last?.summary ?? "No document events yet." }
    public static func lastJSON() -> String? { DogDocumentAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { DogDocumentAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogDocumentUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DogDocumentUploadView()
        }
    }
}
#endif
