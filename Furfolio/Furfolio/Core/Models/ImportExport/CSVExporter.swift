//
//  CSVExporter.swift
//  Furfolio
//
//  Enhanced: Audit log, export badge/tags, accessibility, export summary, analytics-ready.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftUI
import SwiftData

/// CSVExporter is a central utility class for exporting Furfolio data models to CSV.
/// Now with audit trail, export tags, accessibility, and metadata for reporting/automation.
internal final class CSVExporter {

    // MARK: - Audit/Event Log & Export Metadata

    /// Each export event/attempt gets an audit entry.
    private static var auditLog: [ExportAuditEvent] = []
    
    /// Serial queue to ensure concurrency-safe access to auditLog.
    private static let auditQueue = DispatchQueue(label: "com.furfolio.csvExporter.auditQueue")

    /// Lightweight export metadata for UI/history/automation.
    @Model internal struct ExportAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        let timestamp: Date
        let filename: String
        let entityType: String
        let tagTokens: [String]
        let fileURL: URL?
        let status: String   // "success", "error", etc.
        let errorDescription: String?
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return NSLocalizedString("Exported %@ to %@ (%@) at %@.", comment: "Accessibility label for export event")
                .replacingOccurrences(of: "%@", with: entityType, options: [], range: nil)
                .replacingOccurrences(of: "%@", with: filename, options: [], range: nil)
                .replacingOccurrences(of: "%@", with: status, options: [], range: nil)
                .replacingOccurrences(of: "%@", with: dateStr, options: [], range: nil)
        }
    }

    /// Adds an export event to the audit log in a concurrency-safe manner.
    /// - Parameters:
    ///   - filename: The name of the exported file.
    ///   - entityType: The type of entity exported (e.g., "DogOwner").
    ///   - tagTokens: Tags associated with the export for categorization.
    ///   - fileURL: The file URL where the export was saved, if successful.
    ///   - status: The export status, e.g., "success" or "error".
    ///   - error: Optional error if the export failed.
    /// - Note: This method is asynchronous and thread-safe.
    private static func logExport(filename: String, entityType: String, tagTokens: [String], fileURL: URL?, status: String, error: Error? = nil) async {
        await auditQueue.async {
            let event = ExportAuditEvent(
                timestamp: Date(),
                filename: filename,
                entityType: entityType,
                tagTokens: tagTokens,
                fileURL: fileURL,
                status: status,
                errorDescription: error?.localizedDescription
            )
            auditLog.append(event)
            // Optionally persist to disk, or broadcast event.
        }
    }

    /// Quick JSON export of the last audit event (for admin, export center, etc).
    /// - Returns: A pretty-printed JSON string of the last audit event, or nil if none exists.
    /// - Note: This method is asynchronous and thread-safe.
    static func exportLastAuditEventJSON() async -> String? {
        await auditQueue.sync {
            guard let last = auditLog.last else { return nil }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }
    
    /// Fetches the entire audit log as a pretty-printed JSON string.
    /// - Returns: JSON string representing the full audit log.
    /// - Note: This method is asynchronous and thread-safe.
    public static func fetchAuditLogJSON() async -> String? {
        await auditQueue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(auditLog)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }
    
    /// Clears the entire audit log safely.
    /// - Note: This method is asynchronous and thread-safe.
    public static func clearAuditLog() async {
        await auditQueue.async {
            auditLog.removeAll()
        }
    }

    // MARK: - Main Export Functions

    // Below, every export function will log its event.
    // To support badges/tags/analytics, each export gets a "tag" (e.g. "dog", "owner", "finance", etc).

    /// Exports an array of DogOwner objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - owners: Array of DogOwner objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ owners: [DogOwner], filename: String) async throws -> URL {
        let tags = ["owner", "contact", "privacy"]
        do {
            let csvString = ownersCSV(owners)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "DogOwner", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "DogOwner", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Exports an array of Dog objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - dogs: Array of Dog objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ dogs: [Dog], filename: String) async throws -> URL {
        let tags = ["dog", "pet", "animal"]
        do {
            let csvString = dogsCSV(dogs)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "Dog", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "Dog", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Exports an array of Appointment objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - appointments: Array of Appointment objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ appointments: [Appointment], filename: String) async throws -> URL {
        let tags = ["appointment", "calendar", "schedule"]
        do {
            let csvString = appointmentsCSV(appointments)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "Appointment", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "Appointment", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Exports an array of Charge objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - charges: Array of Charge objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ charges: [Charge], filename: String) async throws -> URL {
        let tags = ["charge", "finance", "revenue"]
        do {
            let csvString = chargesCSV(charges)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "Charge", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "Charge", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Exports an array of Business objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - businesses: Array of Business objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ businesses: [Business], filename: String) async throws -> URL {
        let tags = ["business", "company", "profile"]
        do {
            let csvString = businessesCSV(businesses)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "Business", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "Business", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Exports an array of Expense objects to CSV and logs the export event asynchronously.
    /// - Parameters:
    ///   - expenses: Array of Expense objects to export.
    ///   - filename: Desired filename for the CSV export.
    /// - Returns: URL of the exported CSV file.
    /// - Throws: Propagates errors from writing the CSV file.
    @discardableResult
    static func exportCSV(_ expenses: [Expense], filename: String) async throws -> URL {
        let tags = ["expense", "finance", "cost"]
        do {
            let csvString = expensesCSV(expenses)
            let url = try exportCSV(csvString, filename: filename)
            await logExport(filename: filename, entityType: "Expense", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            await logExport(filename: filename, entityType: "Expense", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Generic CSV string export and file write (core logic, also audited).
    /// - Parameters:
    ///   - csv: CSV string content to write.
    ///   - filename: Desired filename for the CSV file.
    /// - Returns: URL of the written CSV file.
    /// - Throws: Errors related to file writing.
    @discardableResult
    static func exportCSV(_ csv: String, filename: String) throws -> URL {
        var safeFilename = filename
        if !safeFilename.lowercased().hasSuffix(".csv") {
            safeFilename += ".csv"
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(safeFilename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            debugPrint("Failed to write CSV file '\(safeFilename)': \(error)")
            throw error
        }
    }

    // MARK: - CSV String Generators (no change; audit/analytics at file level)

    static func ownersCSV(_ owners: [DogOwner]) -> String {
        var csv = NSLocalizedString("Owner Name,Email,Phone,Address,Number of Dogs,Last Appointment\n", comment: "CSV header for owners")
        for owner in owners {
            let name = quote(owner.ownerName)
            let email = quote(owner.email ?? "")
            let phone = quote(owner.phone ?? "")
            let address = quote(owner.address ?? "")
            let dogCount = "\(owner.dogs.count)"
            let lastAppt = quote(DateUtils.shortDate(owner.lastAppointmentDate))
            csv += "\(name),\(email),\(phone),\(address),\(dogCount),\(lastAppt)\n"
        }
        return csv
    }

    static func dogsCSV(_ dogs: [Dog]) -> String {
        var csv = NSLocalizedString("Dog Name,Breed,Owner,Date of Birth,Notes\n", comment: "CSV header for dogs")
        for dog in dogs {
            let name = quote(dog.name)
            let breed = quote(dog.breed ?? "")
            let owner = quote(dog.owner?.ownerName ?? "")
            let dob = quote(DateUtils.shortDate(dog.birthDate))
            let notes = quote(dog.notes ?? "")
            csv += "\(name),\(breed),\(owner),\(dob),\(notes)\n"
        }
        return csv
    }

    static func appointmentsCSV(_ appointments: [Appointment]) -> String {
        var csv = NSLocalizedString("Date,Time,Service,Dog,Owner,Status,Notes\n", comment: "CSV header for appointments")
        for appt in appointments {
            let date = quote(DateUtils.shortDate(appt.date))
            let time = quote(DateUtils.custom(appt.date, format: "h:mm a"))
            let service = quote(appt.serviceType.displayName)
            let dog = quote(appt.dog?.name ?? "")
            let owner = quote(appt.owner?.ownerName ?? "")
            let status = quote(appt.status.displayName)
            let notes = quote(appt.notes ?? "")
            csv += "\(date),\(time),\(service),\(dog),\(owner),\(status),\(notes)\n"
        }
        return csv
    }

    static func chargesCSV(_ charges: [Charge]) -> String {
        var csv = NSLocalizedString("Date,Amount,Type,Owner,Dog,Notes\n", comment: "CSV header for charges")
        for charge in charges {
            let date = quote(DateUtils.shortDate(charge.date))
            let amount = quote(String(format: "%.2f", charge.amount))
            let type = quote(charge.type.displayName)
            let owner = quote(charge.owner?.ownerName ?? "")
            let dog = quote(charge.dog?.name ?? "")
            let notes = quote(charge.notes ?? "")
            csv += "\(date),\(amount),\(type),\(owner),\(dog),\(notes)\n"
        }
        return csv
    }

    static func businessesCSV(_ businesses: [Business]) -> String {
        var csv = NSLocalizedString("Business Name,Owner,Email,Phone,Address,Active Clients,Revenue This Month\n", comment: "CSV header for businesses")
        for business in businesses {
            let name = quote(business.businessName)
            let owner = quote(business.ownerName ?? "")
            let email = quote(business.email ?? "")
            let phone = quote(business.phone ?? "")
            let address = quote(business.address ?? "")
            let activeClients = "\(business.activeClientsCount)"
            let revenue = quote(String(format: "%.2f", business.revenueThisMonth))
            csv += "\(name),\(owner),\(email),\(phone),\(address),\(activeClients),\(revenue)\n"
        }
        return csv
    }

    static func expensesCSV(_ expenses: [Expense]) -> String {
        var csv = NSLocalizedString("Date,Amount,Category,Notes,Related Owner\n", comment: "CSV header for expenses")
        for expense in expenses {
            let date = quote(DateUtils.shortDate(expense.date))
            let amount = quote(String(format: "%.2f", expense.amount))
            let category = quote(expense.category ?? "")
            let notes = quote(expense.notes ?? "")
            let relatedOwner = quote(expense.relatedOwner?.ownerName ?? "")
            csv += "\(date),\(amount),\(category),\(notes),\(relatedOwner)\n"
        }
        return csv
    }

    // MARK: - Helper

    /// Escapes and quotes a string for CSV format.
    /// - Parameter string: The string to escape and quote.
    /// - Returns: A CSV-safe quoted string.
    private static func quote(_ string: String) -> String {
        var str = string.replacingOccurrences(of: "\"", with: "\"\"")
        if str.contains(",") || str.contains("\n") || str.contains("\"") {
            str = "\"\(str)\""
        }
        return str
    }
}

#if DEBUG
import Combine

@available(iOS 15.0, *)
struct CSVExporter_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var auditLogJSON: String = NSLocalizedString("Fetching audit log...", comment: "Placeholder while fetching audit log")
        @State private var isClearing: Bool = false
        
        var body: some View {
            VStack(spacing: 20) {
                ScrollView {
                    Text(auditLogJSON)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                Button(action: {
                    Task {
                        isClearing = true
                        await CSVExporter.clearAuditLog()
                        auditLogJSON = NSLocalizedString("Audit log cleared.", comment: "Message shown after clearing audit log")
                        isClearing = false
                    }
                }) {
                    Text(isClearing ? NSLocalizedString("Clearing...", comment: "Button title while clearing audit log") : NSLocalizedString("Clear Audit Log", comment: "Button title to clear audit log"))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isClearing ? Color.gray : Color.red)
                        .cornerRadius(8)
                }
                .disabled(isClearing)
            }
            .padding()
            .task {
                if let json = await CSVExporter.fetchAuditLogJSON() {
                    auditLogJSON = json
                } else {
                    auditLogJSON = NSLocalizedString("No audit log entries found.", comment: "Message when no audit log entries exist")
                }
            }
            .navigationTitle(NSLocalizedString("CSV Exporter Audit Log", comment: "Navigation title in preview"))
        }
    }
    
    static var previews: some View {
        NavigationView {
            PreviewView()
        }
    }
}
#endif
