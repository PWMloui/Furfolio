//
//  ReportGenerator.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, cleaned, and unified by ChatGPT on 6/21/25

import Foundation
import PDFKit
import SwiftUI

/// Generates summary, analytics, and business reports for Furfolio.
/// Supports text, CSV, and PDF output for printing, sharing, or archiving.
/// Extensible for future business metrics (inventory, engagement, etc).
final class ReportGenerator {
    static let shared = ReportGenerator()
    private init() {}

    // MARK: - Report Types
    enum ReportType: String, CaseIterable {
        case revenue, appointment, loyalty
    }

    // MARK: - Main Entry Points
    /// Generates a summary or analytics report as a plain string (for on-screen display or export)
    func generateReport(type: ReportType, charges: [Charge] = [], appointments: [Appointment] = [], loyalties: [LoyaltyProgram] = [], owners: [DogOwner] = [], from start: Date? = nil, to end: Date? = nil) -> String {
        switch type {
        case .revenue:
            return generateRevenueReport(charges: charges, from: start, to: end)
        case .appointment:
            return generateAppointmentReport(appointments: appointments, from: start, to: end)
        case .loyalty:
            return generateLoyaltyReport(loyalties: loyalties, owners: owners)
        }
    }

    /// Generates a revenue summary report as a string.
    func generateRevenueReport(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
        let total = filtered.reduce(0) { $0 + $1.amount }
        var report = "Revenue Report\n"
        report += "From: \(format(date: start)) To: \(format(date: end))\n"
        report += "Total Revenue: \(format(amount: total))\n"
        report += "\nDetails:\n"
        for charge in filtered.sorted(by: { $0.date < $1.date }) {
            report += "\(format(date: charge.date)): \(format(amount: charge.amount)) (\(charge.type.displayName)) - \(charge.notes ?? "")\n"
        }
        return report
    }

    /// Generates an appointment summary report as a string.
    func generateAppointmentReport(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = appointments.filter { appt in
            (start == nil || appt.date >= start!) && (end == nil || appt.date <= end!)
        }
        var report = "Appointment Report\n"
        report += "From: \(format(date: start)) To: \(format(date: end))\n"
        report += "Total Appointments: \(filtered.count)\n"
        report += "\nDetails:\n"
        for appt in filtered.sorted(by: { $0.date < $1.date }) {
            let ownerName = appt.owner?.ownerName ?? "Unknown"
            let dogName = appt.dog?.name ?? "Unknown"
            report += "\(format(date: appt.date)): \(appt.serviceType.displayName) - \(dogName) (Owner: \(ownerName)) [\(appt.status.displayName)]\n"
        }
        return report
    }

    /// Generates a loyalty/retention summary report as a string.
    func generateLoyaltyReport(loyalties: [LoyaltyProgram], owners: [DogOwner]) -> String {
        var report = "Loyalty & Retention Report\n"
        report += "Total Loyalty Members: \(loyalties.count)\n"
        let eligible = loyalties.filter { $0.isEligibleForReward }
        report += "Eligible for Reward: \(eligible.count)\n"
        let analyzer = CustomerRetentionAnalyzer.shared
        let retentionStats = analyzer.retentionStats(for: owners)
        report += "\nRetention Breakdown:\n"
        for (tag, count) in retentionStats {
            report += "- \(tag.label): \(count)\n"
        }
        return report
    }

    // MARK: - CSV Export
    /// Exports a revenue report as CSV.
    func exportRevenueCSV(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
        var csv = "Date,Amount,Type,Owner,Dog,Notes\n"
        for charge in filtered.sorted(by: { $0.date < $1.date }) {
            let owner = charge.owner?.ownerName ?? ""
            let dog = charge.dog?.name ?? ""
            let line = "\"\(format(date: charge.date))\",\"\(format(amount: charge.amount))\",\"\(charge.type.displayName)\",\"\(owner)\",\"\(dog)\",\"\(charge.notes ?? "")\"\n"
            csv += line
        }
        return csv
    }

    /// Exports appointment data as CSV.
    func exportAppointmentsCSV(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = appointments.filter { appt in
            (start == nil || appt.date >= start!) && (end == nil || appt.date <= end!)
        }
        var csv = "Date,Service,Owner,Dog,Status,Notes\n"
        for appt in filtered.sorted(by: { $0.date < $1.date }) {
            let owner = appt.owner?.ownerName ?? ""
            let dog = appt.dog?.name ?? ""
            let line = "\"\(format(date: appt.date))\",\"\(appt.serviceType.displayName)\",\"\(owner)\",\"\(dog)\",\"\(appt.status.displayName)\",\"\(appt.notes ?? "")\"\n"
            csv += line
        }
        return csv
    }

    /// Generates a basic summary PDF for the given report string.
    /// This is a synchronous renderer optimized for short reports.
    /// - Parameters:
    ///   - title: Title of the report.
    ///   - body: Main content of the report.
    /// - Returns: PDF file data, or nil if generation fails or unsupported platform.
    func exportSummaryPDF(title: String, body: String) -> Data? {
        #if canImport(UIKit)
        // TODO: Migrate all hardcoded typography (UIFont.boldSystemFont, UIFont.systemFont) and spacings (22, 14, 50, 40, 10, 6, 8) to AppFonts and AppSpacing tokens as soon as cross-platform PDF rendering supports design tokens.

        // TODO: Localize all PDF metadata strings (creator, author, title) before export.
        // PDF Metadata
        let pdfMetaData = [
            kCGPDFContextCreator: "Furfolio",
            kCGPDFContextAuthor: "Furfolio App",
            kCGPDFContextTitle: title
        ]

        // TODO: Log/report all PDF export attempts and errors for business analytics or Trust Center compliance.

        // Renderer Configuration
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let titleHeight: CGFloat = 50
        let spacing: CGFloat = 10

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            // Typography Setup
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            paragraphStyle.paragraphSpacing = 8

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: paragraphStyle
            ]

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .paragraphStyle: paragraphStyle
            ]

            // Drawing Areas
            let titleRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: titleHeight)
            let bodyRect = CGRect(x: margin, y: margin + titleHeight + spacing, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin - titleHeight - spacing)

            title.draw(in: titleRect, withAttributes: titleAttributes)
            body.draw(in: bodyRect, withAttributes: bodyAttributes)
        }

        // Reminder: Extend this function for new report layouts (tables, charts, images) as business requirements grow.

        return data
        #else
        print("PDF export is not supported on this platform.")
        return nil
        #endif
    }

    // MARK: - File Output Support (Stub for future share/archive features)
    /// Writes a report string to a file at the given URL.
    func writeReportToFile(report: String, url: URL) throws {
        try report.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers
    private func format(date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    private func format(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
