//
//  PDFReportBuilder.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import UIKit
import CoreGraphics
import os
private let pdfLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PDFReportBuilder")

/// A utility to generate a basic PDF report summarizing owners, appointments, and charges.
// MARK: - PDF Layout Constants
private let margin: CGFloat = 48
private let lineHeight: CGFloat = 18
private let sectionSpacing: CGFloat = 12
private let logoSize = CGSize(width: 64, height: 64)

struct PDFReportBuilder {
    private static let logger = pdfLogger

    /// Generates a PDF summarizing the provided data and writes it to a temporary file.
    /// - Parameters:
    ///   - owners: Array of DogOwner entities to include in the report.
    ///   - appointments: Array of Appointment entities to include.
    ///   - charges: Array of Charge entities to include.
    /// - Returns: URL of the generated PDF file.
    /// - Throws: Errors from writing the PDF data to disk.
    static func generateReport(
        owners: [DogOwner],
        appointments: [Appointment],
        charges: [Charge]
    ) async throws -> URL {
        return try await Task.detached {
            logger.log("Starting PDF report generation: \(owners.count) owners, \(appointments.count) appts, \(charges.count) charges")

            let pageWidth: CGFloat = 612
            let pageHeight: CGFloat = 792
            let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

            let title = "Furfolio Report"
            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            // Helper: Draw logo at top-left margin if available
            func drawLogo(context: UIGraphicsPDFRendererContext) {
                if let logo = UIImage(named: "Logo") {
                    let rect = CGRect(origin: CGPoint(x: margin, y: margin), size: logoSize)
                    logo.draw(in: rect)
                }
            }

            // Helper: Draw header (logo, title, date)
            func drawHeader(context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int?) {
                drawLogo(context: context)
                // Title to right of logo, or at margin if no logo
                let titleX = margin + logoSize.width + 12
                let titleY = margin
                let titlePoint = CGPoint(x: titleX, y: titleY)
                title.draw(at: titlePoint, withAttributes: titleAttributes)
                // Date below title
                let datePoint = CGPoint(x: titleX, y: titleY + 30)
                dateString.draw(at: datePoint, withAttributes: dateAttributes)
            }

            // Helper: Draw footer (page number)
            func drawFooter(context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int?) {
                let pageLabel: String
                if let total = totalPages {
                    pageLabel = "Page \(pageNumber) of \(total)"
                } else {
                    pageLabel = "Page \(pageNumber)"
                }
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.gray
                ]
                let size = (pageLabel as NSString).size(withAttributes: attrs)
                let x = (pageWidth - size.width) / 2
                let y = pageHeight - margin + (lineHeight / 2)
                (pageLabel as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            }

            // Helper: Draw lines, wrapping as needed
            func appendLines(_ lines: [String], context: UIGraphicsPDFRendererContext, yOffset: inout CGFloat, pageNumber: inout Int) {
                let usableWidth = pageWidth - 2 * margin
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .paragraphStyle: paragraphStyle
                ]
                for line in lines {
                    let attributed = NSAttributedString(string: line, attributes: attrs)
                    let boundingRect = attributed.boundingRect(
                        with: CGSize(width: usableWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    // If not enough space, start new page
                    if yOffset + boundingRect.height > pageHeight - margin - lineHeight {
                        drawFooter(context: context, pageNumber: pageNumber, totalPages: nil)
                        context.beginPage()
                        pageNumber += 1
                        drawHeader(context: context, pageNumber: pageNumber, totalPages: nil)
                        yOffset = margin + logoSize.height + 36 // below header
                    }
                    let textRect = CGRect(x: margin, y: yOffset, width: usableWidth, height: boundingRect.height)
                    attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    yOffset += boundingRect.height
                }
            }

            logger.log("Rendering PDF pages for report")
            let data = renderer.pdfData { context in
                var pageNumber = 1
                context.beginPage()
                drawHeader(context: context, pageNumber: pageNumber, totalPages: nil)
                var yOffset = margin + logoSize.height + 36 // below header

                appendLines(["Owners:"], context: context, yOffset: &yOffset, pageNumber: &pageNumber)
                appendLines(owners.map { "• \($0.ownerName)" }, context: context, yOffset: &yOffset, pageNumber: &pageNumber)
                yOffset += sectionSpacing
                appendLines(["Appointments:"], context: context, yOffset: &yOffset, pageNumber: &pageNumber)
                appendLines(appointments.map {
                    let dateStr = ISO8601DateFormatter().string(from: $0.date)
                    return "• \(dateStr) – \($0.serviceType.rawValue) for \($0.dogOwner.ownerName)"
                }, context: context, yOffset: &yOffset, pageNumber: &pageNumber)
                yOffset += sectionSpacing
                appendLines(["Charges:"], context: context, yOffset: &yOffset, pageNumber: &pageNumber)
                appendLines(charges.map {
                    let dateStr = ISO8601DateFormatter().string(from: $0.date)
                    return String(format: "• %@ – %@: $%.2f", dateStr, $0.serviceType.rawValue, $0.amount)
                }, context: context, yOffset: &yOffset, pageNumber: &pageNumber)

                drawFooter(context: context, pageNumber: pageNumber, totalPages: nil)
            }

            logger.log("Generated PDF data of size: \(data.count) bytes")
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("FurfolioReport.pdf")
            logger.log("Writing PDF to path: \(tempURL.path)")
            try data.write(to: tempURL)
            logger.log("PDF report successfully written to \(tempURL.path)")
            return tempURL
        }.value
    }
}
