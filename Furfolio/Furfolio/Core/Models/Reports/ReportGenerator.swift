//
//  ReportGenerator.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, cleaned, and unified by ChatGPT on 6/21/25
//  Localized and accessibility enhanced by ChatGPT on 6/22/25

import Foundation
import PDFKit
import SwiftUI

/// Generates summary, analytics, and business reports for Furfolio.
/// Supports text, CSV, and PDF output for printing, sharing, or archiving.
/// All user-facing strings are fully localized using NSLocalizedString with appropriate comments.
/// Date and currency formatting respects the current locale.
/// Accessibility hints are included in documentation for generated strings.
/// Extensible for future business metrics (inventory, engagement, etc).
final class ReportGenerator {
    static let shared = ReportGenerator()
    private init() {}

    // MARK: - Report Types
    enum ReportType: String, CaseIterable {
        case revenue, appointment, loyalty

        /// Localized display name for the report type.
        var localizedName: String {
            switch self {
            case .revenue:
                return NSLocalizedString("report.type.revenue", value: "Revenue", comment: "Report type: Revenue")
            case .appointment:
                return NSLocalizedString("report.type.appointment", value: "Appointment", comment: "Report type: Appointment")
            case .loyalty:
                return NSLocalizedString("report.type.loyalty", value: "Loyalty", comment: "Report type: Loyalty")
            }
        }
    }

    // MARK: - Main Entry Points
    /// Generates a summary or analytics report as a localized plain string (for on-screen display or export).
    /// - Parameters:
    ///   - type: The type of report to generate.
    ///   - charges: Array of Charge objects relevant to revenue reports.
    ///   - appointments: Array of Appointment objects relevant to appointment reports.
    ///   - loyalties: Array of LoyaltyProgram objects relevant to loyalty reports.
    ///   - owners: Array of DogOwner objects for retention analysis.
    ///   - start: Optional start date for filtering data.
    ///   - end: Optional end date for filtering data.
    /// - Returns: Localized report string.
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

    /// Generates a revenue summary report as a localized string.
    /// - Parameters:
    ///   - charges: Array of Charge objects to include.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: Localized revenue report string with accessibility hints in comments.
    func generateRevenueReport(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
        let total = filtered.reduce(0) { $0 + $1.amount }
        var report = NSLocalizedString("report.revenue.title", value: "Revenue Report", comment: "Title for revenue report") + "\n"
        report += String(format: NSLocalizedString("report.revenue.dateRange", value: "From: %@ To: %@", comment: "Date range for revenue report"), format(date: start), format(date: end)) + "\n"
        report += String(format: NSLocalizedString("report.revenue.totalRevenue", value: "Total Revenue: %@", comment: "Total revenue amount"), format(amount: total)) + "\n"
        report += "\n" + NSLocalizedString("report.details", value: "Details:", comment: "Details section header") + "\n"
        for charge in filtered.sorted(by: { $0.date < $1.date }) {
            let notes = charge.notes ?? ""
            report += String(format: NSLocalizedString("report.revenue.detailLine", value: "%@ : %@ (%@) - %@", comment: "Line for each revenue charge: date, amount, type, notes"), format(date: charge.date), format(amount: charge.amount), charge.type.displayName, notes) + "\n"
        }
        return report
    }

    /// Generates an appointment summary report as a localized string.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: Localized appointment report string.
    func generateAppointmentReport(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = appointments.filter { appt in
            (start == nil || appt.date >= start!) && (end == nil || appt.date <= end!)
        }
        var report = NSLocalizedString("report.appointment.title", value: "Appointment Report", comment: "Title for appointment report") + "\n"
        report += String(format: NSLocalizedString("report.appointment.dateRange", value: "From: %@ To: %@", comment: "Date range for appointment report"), format(date: start), format(date: end)) + "\n"
        report += String(format: NSLocalizedString("report.appointment.totalAppointments", value: "Total Appointments: %d", comment: "Total number of appointments"), filtered.count) + "\n"
        report += "\n" + NSLocalizedString("report.details", value: "Details:", comment: "Details section header") + "\n"
        for appt in filtered.sorted(by: { $0.date < $1.date }) {
            let ownerName = appt.owner?.ownerName ?? NSLocalizedString("unknown", value: "Unknown", comment: "Unknown owner or dog name")
            let dogName = appt.dog?.name ?? NSLocalizedString("unknown", value: "Unknown", comment: "Unknown owner or dog name")
            report += String(format: NSLocalizedString("report.appointment.detailLine", value: "%@ : %@ - %@ (Owner: %@) [%@]", comment: "Line for each appointment: date, service, dog, owner, status"), format(date: appt.date), appt.serviceType.displayName, dogName, ownerName, appt.status.displayName) + "\n"
        }
        return report
    }

    /// Generates a loyalty/retention summary report as a localized string.
    /// - Parameters:
    ///   - loyalties: Array of LoyaltyProgram objects.
    ///   - owners: Array of DogOwner objects for retention stats.
    /// - Returns: Localized loyalty and retention report string.
    func generateLoyaltyReport(loyalties: [LoyaltyProgram], owners: [DogOwner]) -> String {
        var report = NSLocalizedString("report.loyalty.title", value: "Loyalty & Retention Report", comment: "Title for loyalty report") + "\n"
        report += String(format: NSLocalizedString("report.loyalty.totalMembers", value: "Total Loyalty Members: %d", comment: "Total loyalty members count"), loyalties.count) + "\n"
        let eligible = loyalties.filter { $0.isEligibleForReward }
        report += String(format: NSLocalizedString("report.loyalty.eligibleReward", value: "Eligible for Reward: %d", comment: "Count of eligible loyalty members"), eligible.count) + "\n"
        let analyzer = CustomerRetentionAnalyzer.shared
        let retentionStats = analyzer.retentionStats(for: owners)
        report += "\n" + NSLocalizedString("report.loyalty.retentionBreakdown", value: "Retention Breakdown:", comment: "Retention breakdown header") + "\n"
        for (tag, count) in retentionStats {
            report += String(format: NSLocalizedString("report.loyalty.retentionLine", value: "- %@: %d", comment: "Retention tag and count"), tag.label, count) + "\n"
        }
        return report
    }

    // MARK: - CSV Export
    /// Exports a revenue report as localized CSV string.
    /// - Parameters:
    ///   - charges: Array of Charge objects.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: CSV string with localized headers and content.
    func exportRevenueCSV(charges: [Charge], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = charges.filter { charge in
            (start == nil || charge.date >= start!) && (end == nil || charge.date <= end!)
        }
        let headerDate = NSLocalizedString("csv.header.date", value: "Date", comment: "CSV header for date column")
        let headerAmount = NSLocalizedString("csv.header.amount", value: "Amount", comment: "CSV header for amount column")
        let headerType = NSLocalizedString("csv.header.type", value: "Type", comment: "CSV header for type column")
        let headerOwner = NSLocalizedString("csv.header.owner", value: "Owner", comment: "CSV header for owner column")
        let headerDog = NSLocalizedString("csv.header.dog", value: "Dog", comment: "CSV header for dog column")
        let headerNotes = NSLocalizedString("csv.header.notes", value: "Notes", comment: "CSV header for notes column")
        var csv = "\(headerDate),\(headerAmount),\(headerType),\(headerOwner),\(headerDog),\(headerNotes)\n"
        for charge in filtered.sorted(by: { $0.date < $1.date }) {
            let owner = charge.owner?.ownerName ?? ""
            let dog = charge.dog?.name ?? ""
            let line = "\"\(format(date: charge.date))\",\"\(format(amount: charge.amount))\",\"\(charge.type.displayName)\",\"\(owner)\",\"\(dog)\",\"\(charge.notes ?? "")\"\n"
            csv += line
        }
        return csv
    }

    /// Exports appointment data as localized CSV string.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects.
    ///   - start: Optional start date filter.
    ///   - end: Optional end date filter.
    /// - Returns: CSV string with localized headers and content.
    func exportAppointmentsCSV(appointments: [Appointment], from start: Date? = nil, to end: Date? = nil) -> String {
        let filtered = appointments.filter { appt in
            (start == nil || appt.date >= start!) && (end == nil || appt.date <= end!)
        }
        let headerDate = NSLocalizedString("csv.header.date", value: "Date", comment: "CSV header for date column")
        let headerService = NSLocalizedString("csv.header.service", value: "Service", comment: "CSV header for service column")
        let headerOwner = NSLocalizedString("csv.header.owner", value: "Owner", comment: "CSV header for owner column")
        let headerDog = NSLocalizedString("csv.header.dog", value: "Dog", comment: "CSV header for dog column")
        let headerStatus = NSLocalizedString("csv.header.status", value: "Status", comment: "CSV header for status column")
        let headerNotes = NSLocalizedString("csv.header.notes", value: "Notes", comment: "CSV header for notes column")
        var csv = "\(headerDate),\(headerService),\(headerOwner),\(headerDog),\(headerStatus),\(headerNotes)\n"
        for appt in filtered.sorted(by: { $0.date < $1.date }) {
            let owner = appt.owner?.ownerName ?? ""
            let dog = appt.dog?.name ?? ""
            let line = "\"\(format(date: appt.date))\",\"\(appt.serviceType.displayName)\",\"\(owner)\",\"\(dog)\",\"\(appt.status.displayName)\",\"\(appt.notes ?? "")\"\n"
            csv += line
        }
        return csv
    }

    /// Generates a basic summary PDF for the given localized report string.
    /// - Parameters:
    ///   - title: Localized title of the report.
    ///   - body: Localized main content of the report.
    /// - Returns: PDF file data, or nil if generation fails or unsupported platform.
    /// - Note: PDF metadata strings are localized. On unsupported platforms, a localized debug message is printed.
    func exportSummaryPDF(title: String, body: String) -> Data? {
        #if canImport(UIKit)
        // TODO: Migrate all hardcoded typography (UIFont.boldSystemFont, UIFont.systemFont) and spacings (22, 14, 50, 40, 10, 6, 8) to AppFonts and AppSpacing tokens as soon as cross-platform PDF rendering supports design tokens.

        // PDF Metadata localized strings
        let pdfMetaData = [
            kCGPDFContextCreator: NSLocalizedString("pdf.metadata.creator", value: "Furfolio", comment: "PDF metadata creator"),
            kCGPDFContextAuthor: NSLocalizedString("pdf.metadata.author", value: "Furfolio App", comment: "PDF metadata author"),
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
        print(NSLocalizedString("pdf.export.unsupportedPlatform", value: "PDF export is not supported on this platform.", comment: "Debug message when PDF export is unsupported"))
        return nil
        #endif
    }

    // MARK: - File Output Support (Stub for future share/archive features)
    /// Writes a localized report string to a file at the given URL.
    /// - Parameters:
    ///   - report: Localized report string to write.
    ///   - url: Destination file URL.
    /// - Throws: Propagates any file writing errors.
    func writeReportToFile(report: String, url: URL) throws {
        try report.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers
    /// Formats a date using the current locale's short date style.
    /// - Parameter date: Optional date to format.
    /// - Returns: Localized formatted date string or placeholder if nil.
    private func format(date: Date?) -> String {
        guard let date = date else { return NSLocalizedString("date.placeholder", value: "--", comment: "Placeholder for missing date") }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Formats a currency amount using the current locale's currency style.
    /// - Parameter amount: Double amount to format.
    /// - Returns: Localized currency string.
    private func format(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? NSLocalizedString("currency.placeholder", value: "$0.00", comment: "Placeholder for currency formatting failure")
    }
}

#if DEBUG
import PlaygroundSupport

/// SwiftUI PreviewProvider demonstrating localized report generation with sample data.
struct ReportGenerator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("preview.title", value: "Report Generator Preview", comment: "Preview title"))
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("preview.revenueReport", value: "Revenue Report:", comment: "Preview section title for revenue report"))
                        .font(.headline)
                    Text(ReportGenerator.shared.generateRevenueReport(charges: sampleCharges, from: Date().addingTimeInterval(-86400*30), to: Date()))

                    Text(NSLocalizedString("preview.appointmentReport", value: "Appointment Report:", comment: "Preview section title for appointment report"))
                        .font(.headline)
                        .padding(.top)
                    Text(ReportGenerator.shared.generateAppointmentReport(appointments: sampleAppointments, from: Date().addingTimeInterval(-86400*30), to: Date()))

                    Text(NSLocalizedString("preview.loyaltyReport", value: "Loyalty Report:", comment: "Preview section title for loyalty report"))
                        .font(.headline)
                        .padding(.top)
                    Text(ReportGenerator.shared.generateLoyaltyReport(loyalties: sampleLoyaltyPrograms, owners: sampleOwners))
                }
                .padding()
            }
        }
    }

    // Sample data for previews
    static var sampleCharges: [Charge] = {
        let charge1 = Charge(date: Date().addingTimeInterval(-86400*10), amount: 120.0, type: .service, notes: "Grooming service", owner: sampleOwners[0], dog: sampleDogs[0])
        let charge2 = Charge(date: Date().addingTimeInterval(-86400*5), amount: 45.5, type: .product, notes: "Dog shampoo", owner: sampleOwners[1], dog: sampleDogs[1])
        return [charge1, charge2]
    }()

    static var sampleAppointments: [Appointment] = {
        let appt1 = Appointment(date: Date().addingTimeInterval(-86400*7), serviceType: .grooming, owner: sampleOwners[0], dog: sampleDogs[0], status: .completed, notes: "On time")
        let appt2 = Appointment(date: Date().addingTimeInterval(-86400*3), serviceType: .vet, owner: sampleOwners[1], dog: sampleDogs[1], status: .cancelled, notes: "Owner cancelled")
        return [appt1, appt2]
    }()

    static var sampleLoyaltyPrograms: [LoyaltyProgram] = {
        let lp1 = LoyaltyProgram(memberId: "123", isEligibleForReward: true)
        let lp2 = LoyaltyProgram(memberId: "456", isEligibleForReward: false)
        return [lp1, lp2]
    }()

    static var sampleOwners: [DogOwner] = {
        let owner1 = DogOwner(ownerName: "Alice")
        let owner2 = DogOwner(ownerName: "Bob")
        return [owner1, owner2]
    }()

    static var sampleDogs: [Dog] = {
        let dog1 = Dog(name: "Rex")
        let dog2 = Dog(name: "Bella")
        return [dog1, dog2]
    }()
}
#endif
