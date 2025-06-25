//
//  CSVImporter.swift
//  Furfolio
//
//  Enhanced: Audit log, import badges/tags, accessibility, analytics-ready, exportable audit.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData

// MARK: - CSVImporter (Centralized, Modular CSV Import Utility, Auditable)

internal final class CSVImporter {

    // MARK: - Import Audit/Event Log

    struct ImportAuditEvent: Codable {
        let timestamp: Date
        let entityType: String
        let badgeTokens: [String]
        let importedCount: Int
        let errorDescription: String?
        let status: String   // "success" | "error"
        let sourceFilename: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "Imported \(importedCount) \(entityType) (\(status)) at \(dateStr)."
        }
    }

    private(set) static var auditLog: [ImportAuditEvent] = []

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func logImport(entityType: String, badgeTokens: [String], count: Int, status: String, error: Error? = nil, sourceFilename: String? = nil) {
        let event = ImportAuditEvent(
            timestamp: Date(),
            entityType: entityType,
            badgeTokens: badgeTokens,
            importedCount: count,
            errorDescription: error?.localizedDescription,
            status: status,
            sourceFilename: sourceFilename
        )
        auditLog.append(event)
    }

    // MARK: - Import DogOwners

    static func importOwners(from csv: String, context: ModelContext, sourceFilename: String? = nil) -> [DogOwner] {
        var owners: [DogOwner] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 4 else {
                debugPrint("CSVImporter: Skipping owner line \(index + 2) due to insufficient columns")
                continue
            }
            let name = columns[0]
            let email = columns[1].isEmpty ? nil : columns[1]
            let phone = columns[2].isEmpty ? nil : columns[2]
            let address = columns[3].isEmpty ? nil : columns[3]
            let owner = DogOwner(ownerName: name, email: email, phone: phone, address: address)
            context.insert(owner)
            owners.append(owner)
        }
        do {
            try context.save()
            logImport(entityType: "DogOwner", badgeTokens: ["owner", "contact"], count: owners.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "DogOwner", badgeTokens: ["owner", "contact"], count: owners.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save DogOwners - \(error.localizedDescription)")
        }
        return owners
    }

    // MARK: - Import Dogs

    static func importDogs(from csv: String, context: ModelContext, owners: [DogOwner], sourceFilename: String? = nil) -> [Dog] {
        var dogs: [Dog] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 3 else {
                debugPrint("CSVImporter: Skipping dog line \(index + 2) due to insufficient columns")
                continue
            }
            let name = columns[0]
            let breed = columns[1].isEmpty ? nil : columns[1]
            let ownerName = columns[2]
            guard let owner = owners.first(where: { $0.ownerName == ownerName }) else {
                debugPrint("CSVImporter: Dog '\(name)' references unknown owner '\(ownerName)' at line \(index + 2)")
                continue
            }
            let dob = columns.count > 3 ? DateUtils.shortDateStringToDate(columns[3]) : nil
            let notes = columns.count > 4 ? columns[4] : nil
            let dog = Dog(name: name, breed: breed, birthDate: dob, notes: notes, owner: owner)
            context.insert(dog)
            dogs.append(dog)
        }
        do {
            try context.save()
            logImport(entityType: "Dog", badgeTokens: ["dog", "pet"], count: dogs.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "Dog", badgeTokens: ["dog", "pet"], count: dogs.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save Dogs - \(error.localizedDescription)")
        }
        return dogs
    }

    // MARK: - Import Appointments

    static func importAppointments(from csv: String, context: ModelContext, owners: [DogOwner], dogs: [Dog], sourceFilename: String? = nil) -> [Appointment] {
        var appointments: [Appointment] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 5 else {
                debugPrint("CSVImporter: Skipping appointment line \(index + 2) due to insufficient columns")
                continue
            }
            let date = DateUtils.shortDateStringToDate(columns[0])
            let time = columns[1]
            let dateTime = DateUtils.combineDateAndTime(date: date, timeString: time)
            let serviceType = ChargeType(rawValue: columns[2]) ?? .fullGroom
            let dogName = columns[3]
            let ownerName = columns[4]
            let status = columns.count > 5 ? AppointmentStatus(rawValue: columns[5]) ?? .scheduled : .scheduled
            let notes = columns.count > 6 ? columns[6] : nil
            guard let dog = dogs.first(where: { $0.name == dogName }) else {
                debugPrint("CSVImporter: Appointment references unknown dog '\(dogName)' at line \(index + 2)")
                continue
            }
            guard let owner = owners.first(where: { $0.ownerName == ownerName }) else {
                debugPrint("CSVImporter: Appointment references unknown owner '\(ownerName)' at line \(index + 2)")
                continue
            }
            let appt = Appointment(date: dateTime, dog: dog, owner: owner, serviceType: serviceType, status: status, notes: notes)
            context.insert(appt)
            appointments.append(appt)
        }
        do {
            try context.save()
            logImport(entityType: "Appointment", badgeTokens: ["appointment", "calendar"], count: appointments.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "Appointment", badgeTokens: ["appointment", "calendar"], count: appointments.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save Appointments - \(error.localizedDescription)")
        }
        return appointments
    }

    // MARK: - Import Charges

    static func importCharges(from csv: String, context: ModelContext, owners: [DogOwner], dogs: [Dog], sourceFilename: String? = nil) -> [Charge] {
        var charges: [Charge] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 3 else {
                debugPrint("CSVImporter: Skipping charge line \(index + 2) due to insufficient columns")
                continue
            }
            let date = DateUtils.shortDateStringToDate(columns[0])
            let amount = Double(columns[1]) ?? 0.0
            let type = ChargeType(rawValue: columns[2]) ?? .fullGroom
            let owner = columns.count > 3 ? owners.first(where: { $0.ownerName == columns[3] }) : nil
            let dog = columns.count > 4 ? dogs.first(where: { $0.name == columns[4] }) : nil
            let notes = columns.count > 5 ? columns[5] : nil
            let charge = Charge(date: date, amount: amount, type: type, owner: owner, dog: dog, notes: notes)
            context.insert(charge)
            charges.append(charge)
        }
        do {
            try context.save()
            logImport(entityType: "Charge", badgeTokens: ["charge", "finance"], count: charges.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "Charge", badgeTokens: ["charge", "finance"], count: charges.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save Charges - \(error.localizedDescription)")
        }
        return charges
    }

    // MARK: - Import Businesses

    static func importBusinesses(from csv: String, context: ModelContext, sourceFilename: String? = nil) -> [Business] {
        var businesses: [Business] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 5 else {
                debugPrint("CSVImporter: Skipping business line \(index + 2) due to insufficient columns")
                continue
            }
            let name = columns[0]
            let address = columns[1].isEmpty ? nil : columns[1]
            let email = columns[2].isEmpty ? nil : columns[2]
            let phone = columns[3].isEmpty ? nil : columns[3]
            let notes = columns[4].isEmpty ? nil : columns[4]
            let business = Business(name: name, address: address, email: email, phone: phone, notes: notes)
            context.insert(business)
            businesses.append(business)
        }
        do {
            try context.save()
            logImport(entityType: "Business", badgeTokens: ["business", "company"], count: businesses.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "Business", badgeTokens: ["business", "company"], count: businesses.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save Businesses - \(error.localizedDescription)")
        }
        return businesses
    }

    // MARK: - Import Expenses

    static func importExpenses(from csv: String, context: ModelContext, businesses: [Business], sourceFilename: String? = nil) -> [Expense] {
        var expenses: [Expense] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst()
        for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 4 else {
                debugPrint("CSVImporter: Skipping expense line \(index + 2) due to insufficient columns")
                continue
            }
            let date = DateUtils.shortDateStringToDate(columns[0])
            let amount = Double(columns[1]) ?? 0.0
            let category = columns[2]
            let description = columns[3].isEmpty ? nil : columns[3]
            let businessName = columns.count > 4 ? columns[4] : nil
            let business = businessName.flatMap { name in businesses.first(where: { $0.name == name }) }
            let notes = columns.count > 5 ? columns[5] : nil
            let expense = Expense(date: date, amount: amount, category: category, description: description, business: business, notes: notes)
            context.insert(expense)
            expenses.append(expense)
        }
        do {
            try context.save()
            logImport(entityType: "Expense", badgeTokens: ["expense", "finance"], count: expenses.count, status: "success", sourceFilename: sourceFilename)
        } catch {
            logImport(entityType: "Expense", badgeTokens: ["expense", "finance"], count: expenses.count, status: "error", error: error, sourceFilename: sourceFilename)
            debugPrint("CSVImporter: Failed to save Expenses - \(error.localizedDescription)")
        }
        return expenses
    }

    // MARK: - CSV Parsing Helper (unchanged)

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes, let nextChar = iterator.next() {
                    if nextChar == "\"" {
                        current.append("\"")
                    } else {
                        inQuotes = false
                        if nextChar == "," {
                            result.append(current)
                            current = ""
                        } else {
                            current.append(nextChar)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"\"", with: "\"") }
    }
    // Extension points for more importers.
}
