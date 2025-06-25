//
//  PhotoGalleryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Photo Gallery
//

import SwiftUI
import PhotosUI

struct PhotoGalleryView: View {
    @State private var photos: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading: [PhotosPickerItem: Bool] = [:]
    @State private var lastDeletedPhoto: (image: UIImage, index: Int)?
    @State private var showUndo = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 0) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()) {
                    Label("Add Photos", systemImage: "plus.circle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                        .accessibilityIdentifier("PhotoGalleryView-AddPhotosButton")
                }
                .padding(.horizontal)
                .onChange(of: selectedItems) { newItems in
                    for item in newItems {
                        isLoading[item] = true
                        loadImage(from: item)
                    }
                    selectedItems.removeAll()
                }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 6)
                    .accessibilityIdentifier("PhotoGalleryView-Error")
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(photos.indices, id: \.self) { index in
                        let image = photos[index]
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        lastDeletedPhoto = (image, index)
                                        photos.remove(at: index)
                                        showUndo = true
                                        PhotoGalleryAudit.record(action: "Delete", index: index)
                                    }
                                } label: {
                                    Label("Delete Photo", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
                            .accessibilityIdentifier("PhotoGalleryView-Photo-\(index)")
                            .accessibilityAddTraits(.isImage)
                    }
                    // Show placeholders for loading photos
                    ForEach(isLoading.keys.sorted(by: { $0.hashValue < $1.hashValue }), id: \.self) { item in
                        if isLoading[item] == true {
                            ProgressView()
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .accessibilityLabel("Loading photo")
                                .accessibilityIdentifier("PhotoGalleryView-LoadingPhoto")
                        }
                    }
                }
                .padding()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Photo gallery with \(photos.count) photos")

            if showUndo, let last = lastDeletedPhoto {
                Button {
                    withAnimation {
                        photos.insert(last.image, at: last.index)
                        PhotoGalleryAudit.record(action: "UndoDelete", index: last.index)
                        showUndo = false
                        lastDeletedPhoto = nil
                    }
                } label: {
                    Label("Undo delete photo", systemImage: "arrow.uturn.backward")
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 5)
                }
                .accessibilityIdentifier("PhotoGalleryView-UndoDeleteButton")
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: UIImage.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image?):
                    withAnimation {
                        photos.append(image)
                        PhotoGalleryAudit.record(action: "Add", index: photos.count - 1)
                    }
                case .success(nil):
                    errorMessage = "No image found in item."
                case .failure(let error):
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
                isLoading[item] = false
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct PhotoGalleryAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let index: Int?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[PhotoGallery] \(action) index: \(index.map { "\($0)" } ?? "-") at \(dateStr)"
    }
}
fileprivate final class PhotoGalleryAudit {
    static private(set) var log: [PhotoGalleryAuditEvent] = []
    static func record(action: String, index: Int?) {
        let event = PhotoGalleryAuditEvent(timestamp: Date(), action: action, index: index)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Admin/Audit Accessors

public enum PhotoGalleryAuditAdmin {
    public static func lastSummary() -> String { PhotoGalleryAudit.log.last?.summary ?? "No photo events yet." }
    public static func lastJSON() -> String? { PhotoGalleryAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { PhotoGalleryAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct PhotoGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGalleryView()
    }
}
#endif
