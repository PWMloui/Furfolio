
import SwiftUI
import SwiftData
import PDFKit

struct ReorderListView: View {
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
                                .font(.headline)
                            Text("Stock: \(item.stockQuantity)  Reorder at: \(item.reorderThreshold)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            reorder(item)
                        }) {
                            Text("Reorder")
                        }
                        .buttonStyle(.borderedProminent)
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
    }

    private func reorder(_ item: InventoryItem) {
        // Create a draft purchase order entry
        let invoice = VendorInvoice(
            id: UUID(),
            date: Date(),
            supplier: item.supplier,
            lineItems: [VendorInvoice.LineItem(itemID: item.id, quantity: item.reorderQuantity)],
            totalAmount: Double(item.reorderQuantity) * item.unitCost
        )
        context.insert(invoice)
        try? context.save()
    }

    private func exportReorderPDF() {
        let builder = PDFReportBuilder()
        let url = builder.buildReorderReport(for: lowStockItems)
        if let doc = PDFDocument(url: url) {
            self.pdfDocument = doc
            self.showingPDF = true
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

