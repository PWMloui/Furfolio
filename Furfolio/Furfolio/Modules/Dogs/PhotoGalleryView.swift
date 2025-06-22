//
//  PhotoGalleryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import PhotosUI

struct PhotoGalleryView: View {
    @State private var photos: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading: [PhotosPickerItem: Bool] = [:]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
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
                }
                .padding(.horizontal)
                .onChange(of: selectedItems) { newItems in
                    for item in newItems {
                        isLoading[item] = true
                        loadImage(from: item)
                    }
                    selectedItems.removeAll()
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
                                        photos.remove(at: index)
                                    }
                                } label: {
                                    Label("Delete Photo", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
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
                        }
                    }
                }
                .padding()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Photo gallery with \(photos.count) photos")
        }
    }

    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: UIImage.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image?):
                    withAnimation {
                        photos.append(image)
                    }
                case .success(nil):
                    print("No image found in item.")
                case .failure(let error):
                    print("Failed to load image: \(error.localizedDescription)")
                }
                isLoading[item] = false
            }
        }
    }
}

#if DEBUG
struct PhotoGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGalleryView()
            .onAppear {
                // Add sample photos for preview
                if let sampleImage = UIImage(systemName: "photo") {
                    for _ in 0..<6 {
                        // Add multiple sample images
                        // Note: Using system image for preview
                    }
                }
            }
    }
}
#endif
