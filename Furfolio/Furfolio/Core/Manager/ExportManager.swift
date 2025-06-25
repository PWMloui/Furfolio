//
//  ExportManager.swift
//  Furfolio
//
//  Enhanced: 2025+ Grooming Business App Architecture
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - ExportManager (Modular, Tokenized, Auditable Business Data Export)

@MainActor
final class ExportManager: ObservableObject {
    static let shared = ExportManager()
    private init() {}

    // MARK: - Audit/Event Log

    struct ExportAuditEvent: Codable {
        let timestamp: Date
        let operation: String         // "export" | "import"
        let entityTypes: [String]
        let entityCounts: [String: Int]
        let fileURL: String
        let tags: [String]
        let actor: String?
        let context: String?
        let status: String            // "success" | "error"
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(operation.capitalized) of \(entityTypes.joined(separator: \", \")) (\(status)) at \(dateStr)."
        }
    }
    private(set) static var auditLog: [ExportAuditEvent] = []

    private func logEvent(
        operation: String,
        models: FurfolioExportModels,
        fileURL: URL,
        tags: [String],
        actor: String? = nil,
        context: String? = nil,
        status: String = "success",
        error: Error? = nil
    ) {
        let entityTypes = models.entityTypes
        let entityCounts = models.entityCounts
        let event = ExportAuditEvent(
            timestamp: Date(),
            operation: operation,
            entityTypes: entityTypes,
            entityCounts: entityCounts,
            fileURL: fileURL.lastPathComponent,
            tags: tags,
            actor: actor,
            context: context,
            status: status,
            errorDescription: error?.localizedDescription
        )
        Self.auditLog.append(event)
        if Self.auditLog.count > 500 { Self.auditLog.removeFirst() }
    }

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    var accessibilitySummary: String {
        Self.auditLog.last?.accessibilityLabel ?? "No export/import events recorded."
    }

    // MARK: - Export/Import

    func exportAllData(models: FurfolioExportModels, actor: String? = nil, context: String? = nil) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(models)
        let filename = "FurfolioExport-\(dateString()).json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: url)
            logEvent(
                operation: "export",
                models: models,
                fileURL: url,
                tags: ["export", "json", "business"],
                actor: actor,
                context: context,
                status: "success"
            )
            return url
        } catch {
            logEvent(
                operation: "export",
                models: models,
                fileURL: url,
                tags: ["export", "json", "business"],
                actor: actor,
                context: context,
                status: "error",
                error: error
            )
            throw error
        }
    }

    func importAllData(from url: URL, actor: String? = nil, context: String? = nil) throws -> FurfolioExportModels {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let models = try decoder.decode(FurfolioExportModels.self, from: data)
            logEvent(
                operation: "import",
                models: models,
                fileURL: url,
                tags: ["import", "json", "business"],
                actor: actor,
                context: context,
                status: "success"
            )
            return models
        } catch {
            // Attempt best-effort logging of entityTypes for audit
            let entityTypes = ["Unknown"]
            let entityCounts = [String: Int]()
            let event = ExportAuditEvent(
                timestamp: Date(),
                operation: "import",
                entityTypes: entityTypes,
                entityCounts: entityCounts,
                fileURL: url.lastPathComponent,
                tags: ["import", "json", "business"],
                actor: actor,
                context: context,
                status: "error",
                errorDescription: error.localizedDescription
            )
            Self.auditLog.append(event)
            if Self.auditLog.count > 500 { Self.auditLog.removeFirst() }
            throw error
        }
    }

    var exportType: UTType { .json }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    func presentShareSheet(for url: URL) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(activityVC, animated: true)
        #endif
    }
}

// MARK: - Model Data Aggregator for Export

struct FurfolioExportModels: Codable {
    var owners: [DogOwner]
    var dogs: [Dog]
    var appointments: [Appointment]
    var charges: [Charge]
    var tasks: [Task]
    var sessions: [Session]
    var users: [User]
    var vaccinationRecords: [VaccinationRecord]
    var business: Business?
    var staff: [StaffMember]

    // Extension for entity type names and counts for audit analytics
    var entityTypes: [String] {
        var types: [String] = []
        if !owners.isEmpty { types.append("DogOwner") }
        if !dogs.isEmpty { types.append("Dog") }
        if !appointments.isEmpty { types.append("Appointment") }
        if !charges.isEmpty { types.append("Charge") }
        if !tasks.isEmpty { types.append("Task") }
        if !sessions.isEmpty { types.append("Session") }
        if !users.isEmpty { types.append("User") }
        if !vaccinationRecords.isEmpty { types.append("VaccinationRecord") }
        if business != nil { types.append("Business") }
        if !staff.isEmpty { types.append("StaffMember") }
        return types
    }
    var entityCounts: [String: Int] {
        var counts: [String: Int] = [:]
        counts["DogOwner"] = owners.count
        counts["Dog"] = dogs.count
        counts["Appointment"] = appointments.count
        counts["Charge"] = charges.count
        counts["Task"] = tasks.count
        counts["Session"] = sessions.count
        counts["User"] = users.count
        counts["VaccinationRecord"] = vaccinationRecords.count
        counts["Business"] = business == nil ? 0 : 1
        counts["StaffMember"] = staff.count
        return counts
    }

    init(
        owners: [DogOwner] = [],
        dogs: [Dog] = [],
        appointments: [Appointment] = [],
        charges: [Charge] = [],
        tasks: [Task] = [],
        sessions: [Session] = [],
        users: [User] = [],
        vaccinationRecords: [VaccinationRecord] = [],
        business: Business? = nil,
        staff: [StaffMember] = []
    ) {
        self.owners = owners
        self.dogs = dogs
        self.appointments = appointments
        self.charges = charges
        self.tasks = tasks
        self.sessions = sessions
        self.users = users
        self.vaccinationRecords = vaccinationRecords
        self.business = business
        self.staff = staff
    }
}

// MARK: - TopViewController Helper (iOS Only)

#if os(iOS)
import UIKit
extension UIApplication {
    var topViewController: UIViewController? {
        guard let window = self.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return nil }
        var topController = window.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
#endif
