//
//  PetGalleryView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 16, 2025 — added full SwiftUI gallery view, fetch, add & delete support.
//

import SwiftUI
import SwiftData
import PhotosUI
import os

// TODO: Move gallery loading, deletion, and photo-picking logic into a dedicated ViewModel; use ImageValidator and ImageProcessor for input checks and resizing.

@MainActor
class PetGalleryViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryViewModel")
    @Environment(\.modelContext) private var modelContext
    let owner: DogOwner
    @Published var images: [PetGalleryImage] = []

    init(owner: DogOwner, context: ModelContext) {
        self.owner = owner
        self.modelContext = context
        loadImages()
    }

    func loadImages() {
        logger.log("Loading images for owner id: \(owner.id)")
        images = try! modelContext.fetch(
            FetchDescriptor<PetGalleryImage>(
                predicate: #Predicate { $0.dogOwner.id == owner.id },
                sortBy: [SortDescriptor(\PetGalleryImage.dateAdded, order: .reverse)]
            )
        )
        logger.log("Loaded \(images.count) images")
    }

    func delete(_ img: PetGalleryImage) {
        logger.log("Deleting image id: \(img.id)")
        modelContext.delete(img)
        saveAndReload()
    }

    func add(_ data: Data) {
        logger.log("Adding new image for owner id: \(owner.id)")
        guard let processed = ImageProcessor.resize(data: data, maxDimension: 1024),
              ImageValidator.isValid(data: processed) else { return }
        _ = PetGalleryImage.record(
            imageData: processed,
            caption: nil,
            tags: [],
            owner: owner,
            appointment: nil,
            in: modelContext
        )
        logger.log("Image recorded, saving context")
        saveAndReload()
    }

    func saveAndReload() {
        logger.log("Saving context and reloading images")
        try? modelContext.save()
        loadImages()
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadImages()
    }
}

@MainActor
/// A grid-based gallery view displaying an owner’s pet photos with support for adding and deleting images.
struct PetGalleryView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PetGalleryView")
    let owner: DogOwner

    @StateObject private var viewModel: PetGalleryViewModel

    @State private var showingPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    /// Full-screen preview of a selected image.
    @State private var selectedImage: PetGalleryImage?
    /// Loading state for pull-to-refresh.
    @State private var isRefreshing: Bool = false
    /// Image selected for editing caption.
    @State private var editingImage: PetGalleryImage?
    /// Temporary caption text.
    @State private var newCaption: String = ""
    /// Error handling for caption save.
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    /// Shared formatter for accessibility labels on gallery images.
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()

    /// Defines a three-column flexible grid layout for the gallery thumbnails.
    var columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 3)

    init(owner: DogOwner, context: ModelContext) {
        self.owner = owner
        _viewModel = StateObject(wrappedValue: PetGalleryViewModel(owner: owner, context: context))
    }

    /// Composes the gallery UI with a grid of images and an "Add Photo" button.
    var body: some View {
        VStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.images) { img in
                        if let thumb = img.thumbnail {
                            Button {
                                logger.log("Thumbnail tapped for image id: \(img.id)")
                                selectedImage = img
                            } label: {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(6)
                                    .accessibilityLabel(Text("Photo added on \(Self.dateFormatter.string(from: img.dateAdded))"))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    logger.log("Swipe Delete tapped for image id: \(img.id)")
                                    viewModel.delete(img)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    logger.log("Swipe Edit Caption tapped for image id: \(img.id)")
                                    editingImage = img
                                    newCaption = img.caption ?? ""
                                } label: {
                                    Label("Edit Caption", systemImage: "pencil")
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(AppTheme.disabled.opacity(0.2))
                                .frame(height: 100)
                                .overlay(Text("No Image").font(AppTheme.caption).foregroundColor(AppTheme.secondaryText))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .animation(.default, value: viewModel.images)
            }
            .refreshable {
                await viewModel.refresh()
            }
            // Show loading indicator during refresh
            if isRefreshing {
                ProgressView()
                    .padding()
            }
            Divider()
            HStack {
                Spacer()
                /// Button to present the Photos picker for adding new gallery images.
                Button(action: {
                    logger.log("Add Photo button tapped")
                    showingPicker = true
                }) {
                    Label("Add Photo", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(FurfolioButtonStyle())
                .padding()
            }
        }
        .onAppear {
            logger.log("PetGalleryView appeared for owner id: \(owner.id)")
        }
        // Full-screen image preview
        .sheet(item: $selectedImage) { img in
            if let data = img.fullImage, let uiImage = UIImage(data: data) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .onTapGesture { selectedImage = nil }
                }
            }
        }
        // Edit caption sheet
        .sheet(item: $editingImage) { img in
            NavigationStack {
                Form {
                    Section("Edit Caption") {
                        TextField("Caption", text: $newCaption)
                    }
                }
                .navigationTitle("Edit Photo Caption")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            img.caption = newCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                            do {
                                try viewModel.modelContext.save()
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                            editingImage = nil
                        }
                        .disabled(newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingImage = nil }
                    }
                }
            }
        }
        // Error alert for caption saving
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .navigationTitle("Gallery for \(owner.ownerName)")
        /// Presents the PhotosUI picker allowing up to 5 image selections.
        .photosPicker(
            isPresented: $showingPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 5,
            matching: .images
        )
        /// Processes newly selected photos and records them in the model context.
        .onChange(of: selectedPhotos) { newItems in
            for item in newItems {
                Task {
                    if let raw = try? await item.loadTransferable(type: Data.self) {
                       viewModel.add(raw)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct PetGalleryView_Previews: PreviewProvider {
    static let container: ModelContainer = {
        let config = ModelConfiguration(inMemory: true)
        return try! ModelContainer(
            for: [DogOwner.self, PetGalleryImage.self],
            modelConfiguration: config
        )
    }()
    static var previews: some View {
        let ctx = container.mainContext
        let owner = DogOwner.sample
        ctx.insert(owner)
        // add some sample images
        let sampleData = UIImage(systemName: "photo")!.pngData()
        PetGalleryImage.record(imageData: sampleData, caption: "Before", tags: ["test"], owner: owner, appointment: nil, in: ctx)
        PetGalleryImage.record(imageData: sampleData, caption: "After", tags: [], owner: owner, appointment: nil, in: ctx)

        return NavigationView {
            PetGalleryView(owner: owner, context: ctx)
                .environment(\.modelContext, ctx)
        }
    }
}
#endif
