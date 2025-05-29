import SwiftUI
import SwiftData
import PDFKit
import os

struct ReorderListView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ReorderListView")
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate { $0.stockQuantity < $0.reorderThreshold }, sort: [Sort("stockQuantity", .forward)]) private var lowStockItems: [InventoryItem]

    @State private var showingPDF = false
    @State private var pdfDocument: PDFDocument?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lowStockItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(AppTheme.header)
                            Text("Stock: \(item.stockQuantity)  Reorder at: \(item.reorderThreshold)")
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        Spacer()
                        Button(action: {
                            logger.log("Reorder button tapped for item id: \(item.id), name: \(item.name), reorderQuantity: \(item.reorderQuantity)")
                            reorder(item)
                        }) {
                            Text("Reorder")
                        }
                        .buttonStyle(FurfolioButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Reorder List")
            .toolbar {
                Button(action: exportReorderPDF) {
                    Image(systemName: "printer.fill")
                }
            }
            .sheet(isPresented: $showingPDF) {
                if let doc = pdfDocument {
                    PDFKitView(document: doc)
                } else {
                    Text("Unable to generate PDF.")
                }
            }
        }
        .onAppear {
            logger.log("ReorderListView appeared with \(lowStockItems.count) low-stock items")
        }
    }

    private func reorder(_ item: InventoryItem) {
        logger.log("Starting reorder process for item \(item.id)")
        // Create a draft purchase order entry
        let invoice = VendorInvoice(
            id: UUID(),
            date: Date(),
            supplier: item.supplier,
            lineItems: [VendorInvoice.LineItem(itemID: item.id, quantity: item.reorderQuantity)],
            totalAmount: Double(item.reorderQuantity) * item.unitCost
        )
        logger.log("Creating VendorInvoice for item \(item.id), quantity: \(item.reorderQuantity)")
        context.insert(invoice)
        do {
            try context.save()
            logger.log("Successfully saved VendorInvoice id: \(invoice.id)")
        } catch {
            logger.error("Failed to save VendorInvoice: \(error.localizedDescription)")
        }
    }

    private func exportReorderPDF() {
        logger.log("ExportReorderPDF tapped for \(lowStockItems.count) items")
        let builder = PDFReportBuilder()
        let url = builder.buildReorderReport(for: lowStockItems)
        logger.log("Built reorder PDF at URL: \(url.path)")
        if let doc = PDFDocument(url: url) {
            self.pdfDocument = doc
            self.showingPDF = true
            logger.log("Presenting PDF sheet")
        }
    }
}

// A simple PDFKit wrapper for SwiftUI
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

#Preview {
    ReorderListView()
        .modelContainer(PreviewHelpers.previewContainer)
}
