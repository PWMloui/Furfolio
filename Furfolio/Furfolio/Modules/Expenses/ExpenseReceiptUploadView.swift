//
//  ExpenseReceiptUploadView.swift
//  Furfolio
//
//  Enterprise-grade, auditable, accessible enhancement
//

import SwiftUI
import PhotosUI

// MARK: - Audit/Event Logging

fileprivate struct ReceiptUploadAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let index: Int?
    let error: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ReceiptUpload] \(action)\(index != nil ? " idx:\(index!)" : "")\(error != nil ? ", error: \(error!)" : "") at \(dateStr)"
    }
}
fileprivate final class ReceiptUploadAudit {
    static private(set) var log: [ReceiptUploadAuditEvent] = []
    static func record(action: String, index: Int? = nil, error: String? = nil) {
        let event = ReceiptUploadAuditEvent(timestamp: Date(), action: action, index: index, error: error)
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
public enum ReceiptUploadAuditAdmin {
    public static func lastSummary() -> String { ReceiptUploadAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { ReceiptUploadAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { ReceiptUploadAudit.recentSummaries(limit: limit) }
}

@MainActor
class ExpenseReceiptUploadViewModel: ObservableObject {
    @Published var receiptImages: [UIImage] = []
    @Published var errorMessage: String? = nil
    @Published var lastDeleted: (image: UIImage, index: Int)? = nil
    @Published var showUndo: Bool = false

    func addReceiptImage(_ image: UIImage) {
        receiptImages.append(image)
        ReceiptUploadAudit.record(action: "Add", index: receiptImages.count - 1)
    }

    func removeReceiptImage(at index: Int) {
        guard receiptImages.indices.contains(index) else { return }
        lastDeleted = (receiptImages[index], index)
        receiptImages.remove(at: index)
        showUndo = true
        ReceiptUploadAudit.record(action: "Delete", index: index)
    }

    func undoDelete() {
        if let last = lastDeleted {
            receiptImages.insert(last.image, at: last.index)
            ReceiptUploadAudit.record(action: "UndoDelete", index: last.index)
            lastDeleted = nil
        }
        showUndo = false
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
                    .accessibilityIdentifier("ExpenseReceiptUploadView-Empty")
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
                                    .accessibilityIdentifier("ExpenseReceiptUploadView-Image-\(index)")

                                Button(action: {
                                    viewModel.removeReceiptImage(at: index)
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                        .padding(6)
                                }
                                .accessibilityLabel("Delete receipt image \(index + 1)")
                                .accessibilityIdentifier("ExpenseReceiptUploadView-Delete-\(index)")
                            }
                        }
                    }
                    .padding()
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 4)
                    .accessibilityIdentifier("ExpenseReceiptUploadView-Error")
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
                        .accessibilityIdentifier("ExpenseReceiptUploadView-AddButton")
                }
                .padding()
                .onChange(of: selectedItems) { newItems in
                    for item in newItems {
                        loadImage(from: item)
                    }
                    selectedItems.removeAll()
                }

            if viewModel.showUndo, let last = viewModel.lastDeleted {
                Button {
                    withAnimation { viewModel.undoDelete() }
                } label: {
                    Label("Undo delete", systemImage: "arrow.uturn.backward")
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("ExpenseReceiptUploadView-UndoButton")
            }
        }
        .navigationTitle("Upload Expense Receipts")
    }

    // --- ENHANCED LOGIC STARTS HERE ---
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: UIImage.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image?):
                    viewModel.addReceiptImage(image)
                case .success(nil):
                    viewModel.errorMessage = "No image found in item."
                    ReceiptUploadAudit.record(action: "AddFailed", error: "No image found")
                case .failure(let error):
                    viewModel.errorMessage = "Failed to load image: \(error.localizedDescription)"
                    ReceiptUploadAudit.record(action: "AddFailed", error: error.localizedDescription)
                }
            }
        }
    }
    // --- ENHANCED LOGIC ENDS HERE ---
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
