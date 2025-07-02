//
//  CSVImporter.swift
//  Furfolio
//
//  Enhanced: Audit log, import badges/tags, accessibility, analytics-ready, exportable audit.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - CSVImporter (Centralized, Modular CSV Import Utility, Auditable)

internal final class CSVImporter {
    
    // MARK: - Import Audit/Event Log
    
    /// Represents an audit event for an import operation.
    /// Conforms to `Identifiable` for UI and data handling.
    @Model internal struct ImportAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        let timestamp: Date
        let entityType: String
        let badgeTokens: [String]
        let importedCount: Int
        let errorDescription: String?
        let status: String   // "success" | "error"
        let sourceFilename: String?
        
        /// Accessibility label describing the import event, localized and including status and badge tokens.
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let localizedStatus = NSLocalizedString(status.capitalized, comment: "Import status")
            let badgeDescription = badgeTokens.map {
                NSLocalizedString($0.capitalized, comment: "Badge token description")
            }.joined(separator: ", ")
            let formatString = NSLocalizedString("Imported %d %@ (%@) with badges: %@ at %@", comment: "Accessibility label format for import event")
            return String(format: formatString, importedCount, entityType, localizedStatus, badgeDescription, dateStr)
        }
    }
    
    // Private serial queue for thread-safe audit log operations.
    private static let auditLogQueue = DispatchQueue(label: "com.furfolio.csvimporter.auditlog.queue", qos: .userInitiated)
    
    // Internal audit log storage.
    private static var _auditLog: [ImportAuditEvent] = []
    
    /// Returns a snapshot of all audit events asynchronously.
    /// - Returns: Array of `ImportAuditEvent`.
    /// - Note: Thread-safe; uses internal serial queue.
    static func fetchAuditLog() async -> [ImportAuditEvent] {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                continuation.resume(returning: _auditLog)
            }
        }
    }
    
    /// Appends a new audit event to the audit log asynchronously.
    /// - Parameters:
    ///   - entityType: The type of entity imported.
    ///   - badgeTokens: Array of badge tokens associated with the import.
    ///   - count: Number of items imported.
    ///   - status: Status string ("success" or "error").
    ///   - error: Optional error encountered during import.
    ///   - sourceFilename: Optional filename source of the import.
    /// - Note: Thread-safe; uses internal serial queue.
    static func logImport(entityType: String, badgeTokens: [String], count: Int, status: String, error: Error? = nil, sourceFilename: String? = nil) async {
        let event = ImportAuditEvent(
            timestamp: Date(),
            entityType: entityType,
            badgeTokens: badgeTokens,
            importedCount: count,
            errorDescription: error?.localizedDescription,
            status: status,
            sourceFilename: sourceFilename
        )
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                _auditLog.append(event)
                continuation.resume()
            }
        }
    }
    
    /// Clears the entire audit log asynchronously.
    /// - Note: Thread-safe; uses internal serial queue.
    static func clearAuditLog() async {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                _auditLog.removeAll()
                continuation.resume()
            }
        }
    }
    
    /// Exports the last audit event as a pretty-printed JSON string asynchronously.
    /// - Returns: JSON string of the last audit event or nil if none exists.
    /// - Note: Thread-safe; uses internal serial queue.
    static func exportLastAuditEventJSON() async -> String? {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                guard let last = _auditLog.last else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(last),
                   let jsonString = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Exports all audit events as a pretty-printed JSON string asynchronously.
    /// - Returns: JSON string of all audit events or nil if none exist.
    /// - Note: Thread-safe; uses internal serial queue.
    static func exportAllAuditEventsJSON() async -> String? {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                guard !_auditLog.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(_auditLog),
                   let jsonString = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Import DogOwners
    
    /// Imports DogOwner entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported DogOwner objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "DogOwner", badgeTokens: ["owner", "contact"], count: owners.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "DogOwner", badgeTokens: ["owner", "contact"], count: owners.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save DogOwners - \(error.localizedDescription)")
        }
        return owners
    }
    
    // MARK: - Import Dogs
    
    /// Imports Dog entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - owners: Array of DogOwner to associate.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported Dog objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "Dog", badgeTokens: ["dog", "pet"], count: dogs.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "Dog", badgeTokens: ["dog", "pet"], count: dogs.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save Dogs - \(error.localizedDescription)")
        }
        return dogs
    }
    
    // MARK: - Import Appointments
    
    /// Imports Appointment entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - owners: Array of DogOwner to associate.
    ///   - dogs: Array of Dog to associate.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported Appointment objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "Appointment", badgeTokens: ["appointment", "calendar"], count: appointments.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "Appointment", badgeTokens: ["appointment", "calendar"], count: appointments.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save Appointments - \(error.localizedDescription)")
        }
        return appointments
    }
    
    // MARK: - Import Charges
    
    /// Imports Charge entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - owners: Array of DogOwner to associate.
    ///   - dogs: Array of Dog to associate.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported Charge objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "Charge", badgeTokens: ["charge", "finance"], count: charges.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "Charge", badgeTokens: ["charge", "finance"], count: charges.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save Charges - \(error.localizedDescription)")
        }
        return charges
    }
    
    // MARK: - Import Businesses
    
    /// Imports Business entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported Business objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "Business", badgeTokens: ["business", "company"], count: businesses.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "Business", badgeTokens: ["business", "company"], count: businesses.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save Businesses - \(error.localizedDescription)")
        }
        return businesses
    }
    
    // MARK: - Import Expenses
    
    /// Imports Expense entities from CSV string asynchronously.
    /// - Parameters:
    ///   - csv: CSV-formatted string.
    ///   - context: ModelContext to insert entities.
    ///   - businesses: Array of Business to associate.
    ///   - sourceFilename: Optional source filename for audit.
    /// - Returns: Array of imported Expense objects.
    /// - Note: This method is synchronous but logs asynchronously.
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
            Task {
                await logImport(entityType: "Expense", badgeTokens: ["expense", "finance"], count: expenses.count, status: "success", sourceFilename: sourceFilename)
            }
        } catch {
            Task {
                await logImport(entityType: "Expense", badgeTokens: ["expense", "finance"], count: expenses.count, status: "error", error: error, sourceFilename: sourceFilename)
            }
            debugPrint("CSVImporter: Failed to save Expenses - \(error.localizedDescription)")
        }
        return expenses
    }
    
    // MARK: - CSV Parsing Helper
    
    /// Parses a single CSV line into an array of trimmed strings, handling quoted commas and escaped quotes.
    /// - Parameter line: A single line of CSV text.
    /// - Returns: Array of column strings.
    /// - Note: This method preserves quoted commas and handles escaped quotes as per CSV standard.
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

// MARK: - Unit Test Stubs

#if DEBUG
import XCTest

final class CSVImporterTests: XCTestCase {
    
    func testAuditLogConcurrencySafety() async {
        // Stub test: Perform concurrent logImport calls and verify audit log count.
        let group = DispatchGroup()
        for i in 0..<100 {
            group.enter()
            Task {
                await CSVImporter.logImport(entityType: "TestEntity", badgeTokens: ["test"], count: i, status: "success")
                group.leave()
            }
        }
        group.wait()
        let logs = await CSVImporter.fetchAuditLog()
        XCTAssertGreaterThanOrEqual(logs.count, 100)
    }
    
    func testExportAllAuditEventsJSON() async {
        // Stub test: Add a known audit event and export all as JSON.
        await CSVImporter.logImport(entityType: "TestExport", badgeTokens: ["export"], count: 1, status: "success")
        let json = await CSVImporter.exportAllAuditEventsJSON()
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("TestExport"))
    }
    
    func testClearAuditLog() async {
        await CSVImporter.logImport(entityType: "TestClear", badgeTokens: ["clear"], count: 1, status: "success")
        await CSVImporter.clearAuditLog()
        let logs = await CSVImporter.fetchAuditLog()
        XCTAssertEqual(logs.count, 0)
    }
}
#endif

// MARK: - SwiftUI PreviewProvider for Audit Log UI

#if DEBUG
import SwiftUI

@available(iOS 15.0, *)
struct CSVImporterAuditLogPreview: View {
    @State private var auditEvents: [CSVImporter.ImportAuditEvent] = []
    @State private var exportJSON: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView(NSLocalizedString("Loading audit log...", comment: "Loading indicator"))
                        .padding()
                } else if auditEvents.isEmpty {
                    Text(NSLocalizedString("No audit log entries available.", comment: "Empty audit log message"))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(auditEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.accessibilityLabel)
                                .font(.body)
                            if let error = event.errorDescription {
                                Text("\(NSLocalizedString("Error:", comment: "Error label")) \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if let source = event.sourceFilename {
                                Text("\(NSLocalizedString("Source:", comment: "Source filename label")) \(source)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .accessibilityLabel(event.accessibilityLabel)
                    }
                }
                Spacer()
                HStack {
                    Button {
                        Task {
                            isLoading = true
                            await CSVImporter.clearAuditLog()
                            auditEvents = []
                            exportJSON = nil
                            isLoading = false
                        }
                    } label: {
                        Label(NSLocalizedString("Clear Log", comment: "Clear audit log button"), systemImage: "trash")
                    }
                    .padding()
                    .disabled(isLoading || auditEvents.isEmpty)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            isLoading = true
                            exportJSON = await CSVImporter.exportAllAuditEventsJSON()
                            isLoading = false
                        }
                    } label: {
                        Label(NSLocalizedString("Export JSON", comment: "Export audit log JSON button"), systemImage: "square.and.arrow.up")
                    }
                    .padding()
                    .disabled(isLoading || auditEvents.isEmpty)
                    .popover(isPresented: Binding(get: { exportJSON != nil }, set: { if !$0 { exportJSON = nil } })) {
                        ScrollView {
                            Text(exportJSON ?? "")
                                .padding()
                        }
                        .frame(minWidth: 300, minHeight: 400)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Audit Log", comment: "Audit log view title"))
            .onAppear {
                Task {
                    isLoading = true
                    auditEvents = await CSVImporter.fetchAuditLog()
                    isLoading = false
                }
            }
        }
    }
}

@available(iOS 15.0, *)
struct CSVImporterAuditLogPreview_Previews: PreviewProvider {
    static var previews: some View {
        CSVImporterAuditLogPreview()
    }
}
#endif
