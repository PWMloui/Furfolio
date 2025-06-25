//
//  CSVExporter.swift
//  Furfolio
//
//  Enhanced: Audit log, export badge/tags, accessibility, export summary, analytics-ready.
//  Author: mac + ChatGPT
//

import Foundation

/// CSVExporter is a central utility class for exporting Furfolio data models to CSV.
/// Now with audit trail, export tags, accessibility, and metadata for reporting/automation.
internal final class CSVExporter {

    // MARK: - Audit/Event Log & Export Metadata

    /// Each export event/attempt gets an audit entry.
    private(set) static var auditLog: [ExportAuditEvent] = []

    /// Lightweight export metadata for UI/history/automation.
    struct ExportAuditEvent: Codable {
        let timestamp: Date
        let filename: String
        let entityType: String
        let tagTokens: [String]
        let fileURL: URL?
        let status: String   // "success", "error", etc.
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "Exported \(entityType) to \(filename) (\(status)) at \(dateStr)."
        }
    }

    /// Adds an export event to the audit log.
    private static func logExport(filename: String, entityType: String, tagTokens: [String], fileURL: URL?, status: String, error: Error? = nil) {
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

    /// Quick JSON export of the last audit event (for admin, export center, etc).
    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Main Export Functions

    // Below, every export function will log its event.
    // To support badges/tags/analytics, each export gets a "tag" (e.g. "dog", "owner", "finance", etc).

    @discardableResult
    static func exportCSV(_ owners: [DogOwner], filename: String) throws -> URL {
        let tags = ["owner", "contact", "privacy"]
        do {
            let csvString = ownersCSV(owners)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "DogOwner", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "DogOwner", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    @discardableResult
    static func exportCSV(_ dogs: [Dog], filename: String) throws -> URL {
        let tags = ["dog", "pet", "animal"]
        do {
            let csvString = dogsCSV(dogs)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "Dog", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "Dog", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    @discardableResult
    static func exportCSV(_ appointments: [Appointment], filename: String) throws -> URL {
        let tags = ["appointment", "calendar", "schedule"]
        do {
            let csvString = appointmentsCSV(appointments)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "Appointment", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "Appointment", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    @discardableResult
    static func exportCSV(_ charges: [Charge], filename: String) throws -> URL {
        let tags = ["charge", "finance", "revenue"]
        do {
            let csvString = chargesCSV(charges)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "Charge", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "Charge", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    @discardableResult
    static func exportCSV(_ businesses: [Business], filename: String) throws -> URL {
        let tags = ["business", "company", "profile"]
        do {
            let csvString = businessesCSV(businesses)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "Business", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "Business", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    @discardableResult
    static func exportCSV(_ expenses: [Expense], filename: String) throws -> URL {
        let tags = ["expense", "finance", "cost"]
        do {
            let csvString = expensesCSV(expenses)
            let url = try exportCSV(csvString, filename: filename)
            logExport(filename: filename, entityType: "Expense", tagTokens: tags, fileURL: url, status: "success")
            return url
        } catch {
            logExport(filename: filename, entityType: "Expense", tagTokens: tags, fileURL: nil, status: "error", error: error)
            throw error
        }
    }

    /// Generic CSV string export and file write (core logic, also audited).
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
        var csv = "Owner Name,Email,Phone,Address,Number of Dogs,Last Appointment\n"
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
        var csv = "Dog Name,Breed,Owner,Date of Birth,Notes\n"
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
        var csv = "Date,Time,Service,Dog,Owner,Status,Notes\n"
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
        var csv = "Date,Amount,Type,Owner,Dog,Notes\n"
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
        var csv = "Business Name,Owner,Email,Phone,Address,Active Clients,Revenue This Month\n"
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
        var csv = "Date,Amount,Category,Notes,Related Owner\n"
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
    private static func quote(_ string: String) -> String {
        var str = string.replacingOccurrences(of: "\"", with: "\"\"")
        if str.contains(",") || str.contains("\n") || str.contains("\"") {
            str = "\"\(str)\""
        }
        return str
    }
}
