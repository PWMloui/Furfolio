//
//  InvoicePreviewView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import PDFKit
import os

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

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "InvoicePreviewView")

    @State private var pdfDocument: PDFDocument? = nil

    var body: some View {
        VStack {
            if let document = pdfDocument {
                PDFKitView(document: document)
                    .edgesIgnoringSafeArea(.all)
                    .background(AppTheme.background)
            } else {
                ProgressView("Generating Invoice…")
                    .font(AppTheme.body)
                    .onAppear {
                        logger.log("Starting PDF generation for invoice id: \(invoice.id)")
                        loadPDF()
                    }
            }
        }
        .onAppear {
            logger.log("InvoicePreviewView appeared for invoice id: \(invoice.id)")
        }
        .navigationTitle("Invoice Preview")
    }

    private func loadPDF() {
        logger.log("Building PDF data for invoice id: \(invoice.id)")
        let data = PDFReportBuilder.buildPDFData(for: invoice)
        logger.log("Generated PDF data of size: \(data.count) bytes for invoice id: \(invoice.id)")
        pdfDocument = PDFDocument(data: data)
        logger.log("PDFDocument initialized for invoice id: \(invoice.id)")
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
