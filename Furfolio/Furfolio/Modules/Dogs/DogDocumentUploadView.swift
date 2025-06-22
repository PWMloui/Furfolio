//
//  DogDocumentUploadView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DogDocument: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let thumbnail: Image?
}

@MainActor
class DogDocumentUploadViewModel: ObservableObject {
    @Published var documents: [DogDocument] = []
    
    @Published var previewDocument: DogDocument? = nil

    func addDocument(url: URL) {
        let name = url.lastPathComponent
        let thumbnail: Image? = generateThumbnail(from: url)
        let newDoc = DogDocument(url: url, name: name, thumbnail: thumbnail)
        documents.append(newDoc)
    }

    func removeDocument(_ doc: DogDocument) {
        if let index = documents.firstIndex(of: doc) {
            documents.remove(at: index)
        }
    }

    private func generateThumbnail(from url: URL) -> Image? {
        // For images, create a thumbnail; for other types, use a generic icon
        if let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        } else {
            // Use system icon based on file type
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "pdf":
                return Image(systemName: "doc.richtext")
            case "txt":
                return Image(systemName: "doc.plaintext")
            default:
                return Image(systemName: "doc.text")
            }
        }
    }
}

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
                    .accessibilityLabel("No documents uploaded yet")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.documents) { doc in
                            VStack(spacing: 8) {
                                Button(action: {
                                    viewModel.previewDocument = doc
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

                                Text(doc.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 80)
                                    .accessibilityLabel("Document name \(doc.name)")

                                Button(action: {
                                    viewModel.removeDocument(doc)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .accessibilityLabel("Delete document \(doc.name)")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }

            HStack(spacing: 20) {
                PhotosPicker(
                    selection: $selectedItems,
                    matching: .images,
                    photoLibrary: .shared()) {
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
                    .accessibilityLabel("Add document from photo library")

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
                .accessibilityLabel("Add document from files")
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
                        // Save data temporarily and create a URL
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
                                Button("Close") {
                                    dismiss()
                                }
                            }
                        }
                } else if document.url.pathExtension.lowercased() == "pdf" {
                    PDFKitView(url: document.url)
                        .navigationTitle(document.name)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    dismiss()
                                }
                            }
                        }
                } else {
                    Text("Preview not available")
                        .foregroundColor(.secondary)
                        .navigationTitle(document.name)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    dismiss()
                                }
                            }
                        }
                }
            } else {
                Text("Preview not available")
                    .foregroundColor(.secondary)
                    .navigationTitle(document.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
            }
        }
    }
}

import PDFKit
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // no update needed
    }
}

#if DEBUG
struct DogDocumentUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DogDocumentUploadView()
                .onAppear {
                    let vm = DogDocumentUploadViewModel()
                    if let sampleImageUrl = Bundle.main.url(forResource: "SampleImage", withExtension: "jpg") {
                        vm.addDocument(url: sampleImageUrl)
                    }
                    if let samplePdfUrl = Bundle.main.url(forResource: "SamplePDF", withExtension: "pdf") {
                        vm.addDocument(url: samplePdfUrl)
                    }
                }
        }
    }
}
#endif
