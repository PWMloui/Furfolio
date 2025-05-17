//
//  PDFReportBuilder.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import UIKit

/// A utility to generate a basic PDF report summarizing owners, appointments, and charges.
struct PDFReportBuilder {

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
    ) throws -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let title = "Furfolio Report"
            title.draw(at: CGPoint(x: 72, y: 72), withAttributes: titleAttributes)

            var yOffset: CGFloat = 120
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            func appendLines(_ lines: [String]) {
                for line in lines {
                    line.draw(at: CGPoint(x: 72, y: yOffset), withAttributes: bodyAttributes)
                    yOffset += 18
                    if yOffset > pageHeight - 72 {
                        context.beginPage()
                        yOffset = 72
                    }
                }
            }

            appendLines(["Owners:"] + owners.map { "• \($0.ownerName)" })
            yOffset += 12
            appendLines(["Appointments:"] + appointments.map {
                let dateStr = ISO8601DateFormatter().string(from: $0.date)
                return "• \(dateStr) – \($0.serviceType.rawValue) for \($0.dogOwner.ownerName)"
            })
            yOffset += 12
            appendLines(["Charges:"] + charges.map {
                let dateStr = ISO8601DateFormatter().string(from: $0.date)
                return String(format: "• %@ – %@: $%.2f", dateStr, $0.serviceType.rawValue, $0.amount)
            })
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FurfolioReport.pdf")
        try data.write(to: tempURL)
        return tempURL
    }
}
