//
//  ExpenseReceiptUploadView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import PhotosUI

@MainActor
class ExpenseReceiptUploadViewModel: ObservableObject {
    @Published var receiptImages: [UIImage] = []

    func addReceiptImage(_ image: UIImage) {
        receiptImages.append(image)
    }

    func removeReceiptImage(at index: Int) {
        guard receiptImages.indices.contains(index) else { return }
        receiptImages.remove(at: index)
    }
}

struct ExpenseReceiptUploadView: View {
    @StateObject private var viewModel = ExpenseReceiptUploadViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            if viewModel.receiptImages.isEmpty {
                Text("No receipts uploaded yet.")
                    .foregroundColor(.secondary)
                    .padding()
                    .accessibilityLabel("No receipts uploaded yet")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.receiptImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: viewModel.receiptImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(12)
                                    .accessibilityLabel("Receipt image \(index + 1)")

                                Button(action: {
                                    viewModel.removeReceiptImage(at: index)
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                        .padding(6)
                                }
                                .accessibilityLabel("Delete receipt image \(index + 1)")
                            }
                        }
                    }
                    .padding()
                }
            }

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images,
                photoLibrary: .shared()) {
                    Label("Add Receipt Images", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding()
                .onChange(of: selectedItems) { newItems in
                    for item in newItems {
                        loadImage(from: item)
                    }
                    selectedItems.removeAll()
                }
        }
        .navigationTitle("Upload Expense Receipts")
    }

    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: UIImage.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image?):
                    viewModel.addReceiptImage(image)
                case .success(nil):
                    print("No image found in item.")
                case .failure(let error):
                    print("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }
}

#if DEBUG
struct ExpenseReceiptUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExpenseReceiptUploadView()
        }
    }
}
#endif
