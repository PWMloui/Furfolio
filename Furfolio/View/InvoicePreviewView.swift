//
//  InvoicePreviewView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import PDFKit

/// A SwiftUI wrapper around PDFKit's PDFView.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

/// A view that previews an invoice using a generated PDF.
struct InvoicePreviewView: View {
    let invoice: VendorInvoice

    @State private var pdfDocument: PDFDocument? = nil

    var body: some View {
        VStack {
            if let document = pdfDocument {
                PDFKitView(document: document)
                    .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView("Generating Invoice…")
                    .onAppear(perform: loadPDF)
            }
        }
        .navigationTitle("Invoice Preview")
    }

    private func loadPDF() {
        // Generate a PDF for the given invoice
        let data = PDFReportBuilder.buildPDFData(for: invoice)
        pdfDocument = PDFDocument(data: data)
    }
}

struct InvoicePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Replace with a sample invoice from PreviewHelpers
        if let sampleInvoice = PreviewHelpers.sampleVendorInvoices.first {
            NavigationView {
                InvoicePreviewView(invoice: sampleInvoice)
            }
        } else {
            Text("No sample invoice available")
        }
    }
}
