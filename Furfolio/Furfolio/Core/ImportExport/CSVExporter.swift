//
//  CSVExporter.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - CSVExporter (Centralized, Modular CSV Export Utility, Auditable)

/**
 CSVExporter is a central utility class responsible for exporting Furfolio data models into CSV format. It provides static methods to convert arrays of various domain objects (such as DogOwner, Dog, Appointment, Charge, Business, and Expense) into CSV strings and to save those CSV strings as files in the app's Documents directory.

 This class is designed to be modular, auditable, and extensible. All exported CSV files should support privacy considerations, audit/event logging, and be prepared for future localization. Future features will include support for encryption, field-level localization, and owner privacy controls.

 In the Furfolio architecture, CSVExporter acts as a dedicated service for data export functionality, facilitating data sharing, backups, and integration with external tools.
 */
internal final class CSVExporter {
    /**
     Exports an array of `DogOwner` to a CSV string.

     - Parameter owners: Array of `DogOwner` objects to export.
     - Returns: A CSV formatted string representing the owners.
     */
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

    /**
     Exports an array of `Dog` to a CSV string.

     - Parameter dogs: Array of `Dog` objects to export.
     - Returns: A CSV formatted string representing the dogs.
     */
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

    /**
     Exports an array of `Appointment` to a CSV string.

     - Parameter appointments: Array of `Appointment` objects to export.
     - Returns: A CSV formatted string representing the appointments.
     */
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

    /**
     Exports an array of `Charge` to a CSV string.

     - Parameter charges: Array of `Charge` objects to export.
     - Returns: A CSV formatted string representing the charges.
     */
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

    /**
     Exports an array of `Business` to a CSV string.

     - Parameter businesses: Array of `Business` objects to export.
     - Returns: A CSV formatted string representing the businesses.
     */
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

    /**
     Exports an array of `Expense` to a CSV string.

     - Parameter expenses: Array of `Expense` objects to export.
     - Returns: A CSV formatted string representing the expenses.
     */
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

    /**
     Exports the provided CSV string to a file in the app's Documents directory.

     - Parameters:
       - csv: The CSV string to write.
       - filename: The desired filename. If it does not end with ".csv", the extension will be appended.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ csv: String, filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
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

    /**
     Exports an array of `DogOwner` to a CSV file.

     - Parameters:
       - owners: Array of `DogOwner` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ owners: [DogOwner], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = ownersCSV(owners)
        return try exportCSV(csvString, filename: filename)
    }

    /**
     Exports an array of `Dog` to a CSV file.

     - Parameters:
       - dogs: Array of `Dog` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ dogs: [Dog], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = dogsCSV(dogs)
        return try exportCSV(csvString, filename: filename)
    }

    /**
     Exports an array of `Appointment` to a CSV file.

     - Parameters:
       - appointments: Array of `Appointment` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ appointments: [Appointment], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = appointmentsCSV(appointments)
        return try exportCSV(csvString, filename: filename)
    }

    /**
     Exports an array of `Charge` to a CSV file.

     - Parameters:
       - charges: Array of `Charge` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ charges: [Charge], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = chargesCSV(charges)
        return try exportCSV(csvString, filename: filename)
    }

    /**
     Exports an array of `Business` to a CSV file.

     - Parameters:
       - businesses: Array of `Business` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ businesses: [Business], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = businessesCSV(businesses)
        return try exportCSV(csvString, filename: filename)
    }

    /**
     Exports an array of `Expense` to a CSV file.

     - Parameters:
       - expenses: Array of `Expense` objects to export.
       - filename: The desired filename for the CSV file.
     - Throws: An error if the file could not be written.
     - Returns: The file URL where the CSV was saved.

     All exports should log the event for auditing/business compliance.
     */
    @discardableResult
    static func exportCSV(_ expenses: [Expense], filename: String) throws -> URL {
        // TODO: Integrate with audit/event logging before completing file write.
        let csvString = expensesCSV(expenses)
        return try exportCSV(csvString, filename: filename)
    }

    // MARK: - Helper

    /// Escapes and quotes a string for CSV format.
    /// Should be extended for localization/formatting in the future.
    private static func quote(_ string: String) -> String {
        var str = string.replacingOccurrences(of: "\"", with: "\"\"")
        if str.contains(",") || str.contains("\n") || str.contains("\"") {
            str = "\"\(str)\""
        }
        return str
    }
}
