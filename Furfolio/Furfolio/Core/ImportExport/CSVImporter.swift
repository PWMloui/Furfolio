//
//  CSVImporter.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - CSVImporter (Centralized, Modular CSV Import Utility, Auditable)

/// Utility class for importing CSV files into Furfolio models.
/// CSVImporter is designed to be modular, auditable, and extensible.
/// All import operations support audit/event logging and privacy considerations.
/// The system is prepared for future localization and compliance requirements.
/// Future features will include encryption, field-level localization, and owner privacy controls.
internal final class CSVImporter {
    
    // MARK: - Import DogOwners
    
    /// Imports DogOwner records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: ownerName,email,phone,address
    ///   - context: ModelContext for inserting and saving entities.
    /// - Returns: Array of imported DogOwner objects.
    /// All imports should log the event for auditing/business compliance.
    static func importOwners(from csv: String, context: ModelContext) -> [DogOwner] {
        // TODO: Integrate with audit/event logging before saving entities.
        var owners: [DogOwner] = []
        let lines = csv.components(separatedBy: .newlines).dropFirst() // Skip header line
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
        } catch {
            debugPrint("CSVImporter: Failed to save DogOwners - \(error.localizedDescription)")
        }
        return owners
    }
    
    // MARK: - Import Dogs
    
    /// Imports Dog records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: name,breed,ownerName,birthDate,notes
    ///   - context: ModelContext for inserting and saving entities.
    ///   - owners: Array of DogOwner objects to link Dogs to owners by ownerName.
    /// - Returns: Array of imported Dog objects.
    /// All imports should log the event for auditing/business compliance.
    static func importDogs(from csv: String, context: ModelContext, owners: [DogOwner]) -> [Dog] {
        // TODO: Integrate with audit/event logging before saving entities.
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
        } catch {
            debugPrint("CSVImporter: Failed to save Dogs - \(error.localizedDescription)")
        }
        return dogs
    }
    
    // MARK: - Import Appointments
    
    /// Imports Appointment records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: date,time,serviceType,dogName,ownerName,status,notes
    ///   - context: ModelContext for inserting and saving entities.
    ///   - owners: Array of DogOwner objects for owner lookup.
    ///   - dogs: Array of Dog objects for dog lookup.
    /// - Returns: Array of imported Appointment objects.
    /// All imports should log the event for auditing/business compliance.
    static func importAppointments(from csv: String, context: ModelContext, owners: [DogOwner], dogs: [Dog]) -> [Appointment] {
        // TODO: Integrate with audit/event logging before saving entities.
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
        } catch {
            debugPrint("CSVImporter: Failed to save Appointments - \(error.localizedDescription)")
        }
        return appointments
    }
    
    // MARK: - Import Charges
    
    /// Imports Charge records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: date,amount,type,ownerName,dogName,notes
    ///   - context: ModelContext for inserting and saving entities.
    ///   - owners: Array of DogOwner objects for owner lookup.
    ///   - dogs: Array of Dog objects for dog lookup.
    /// - Returns: Array of imported Charge objects.
    /// All imports should log the event for auditing/business compliance.
    static func importCharges(from csv: String, context: ModelContext, owners: [DogOwner], dogs: [Dog]) -> [Charge] {
        // TODO: Integrate with audit/event logging before saving entities.
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
        } catch {
            debugPrint("CSVImporter: Failed to save Charges - \(error.localizedDescription)")
        }
        return charges
    }
    
    // MARK: - Import Businesses
    
    /// Imports Business records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: name,address,email,phone,notes
    ///   - context: ModelContext for inserting and saving entities.
    /// - Returns: Array of imported Business objects.
    /// All imports should log the event for auditing/business compliance.
    static func importBusinesses(from csv: String, context: ModelContext) -> [Business] {
        // TODO: Integrate with audit/event logging before saving entities.
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
        } catch {
            debugPrint("CSVImporter: Failed to save Businesses - \(error.localizedDescription)")
        }
        return businesses
    }
    
    // MARK: - Import Expenses
    
    /// Imports Expense records from a CSV string.
    /// - Parameters:
    ///   - csv: CSV formatted string with columns: date,amount,category,description,businessName,notes
    ///   - context: ModelContext for inserting and saving entities.
    ///   - businesses: Array of Business objects for business lookup.
    /// - Returns: Array of imported Expense objects.
    /// All imports should log the event for auditing/business compliance.
    static func importExpenses(from csv: String, context: ModelContext, businesses: [Business]) -> [Expense] {
        // TODO: Integrate with audit/event logging before saving entities.
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
        } catch {
            debugPrint("CSVImporter: Failed to save Expenses - \(error.localizedDescription)")
        }
        return expenses
    }
    
    // MARK: - CSV Parsing Helper
    
    /// Splits a CSV line into columns, handling quoted commas and escaped quotes.
    /// - Parameter line: A single line of CSV text.
    /// - Returns: Array of column strings, trimmed and unescaped.
    /// Should be extended for localization/formatting and robust error handling in the future.
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        
        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes, let nextChar = iterator.next() {
                    if nextChar == "\"" {
                        // Escaped quote inside quoted string
                        current.append("\"")
                    } else {
                        // End of quoted string
                        inQuotes = false
                        if nextChar == "," {
                            result.append(current)
                            current = ""
                        } else {
                            current.append(nextChar)
                        }
                    }
                } else {
                    // Start of quoted string
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
        // Trim whitespace and unescape quotes
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"\"", with: "\"") }
    }
    
    // MARK: - Extension Points
    
    // Additional importers for new models can be added here.
}

// MARK: - Date Utils (for this importer)

extension DateUtils {
    /// Converts a short date string (e.g. "6/20/25") to a Date object.
    /// - Parameter string: Short date formatted string.
    /// - Returns: Date object or current date if parsing fails.
    static func shortDateStringToDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string) ?? Date()
    }
    
    /// Combines a Date with a time string (e.g. "2:00 PM") into a single Date object.
    /// - Parameters:
    ///   - date: Base Date object (date portion).
    ///   - timeString: Time string to combine with date.
    /// - Returns: Combined Date object or original date if parsing fails.
    static func combineDateAndTime(date: Date, timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = shortDate(date) + " " + timeString
        return formatter.date(from: dateString) ?? date
    }
}
