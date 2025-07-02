//
//  ExportManager.swift
//  Furfolio
//
//  Enhanced: 2025+ Grooming Business App Architecture
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import SwiftData

// MARK: - ExportManager (Modular, Tokenized, Auditable Business Data Export)

@MainActor
final class ExportManager: ObservableObject {
    static let shared = ExportManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) private var auditEvents: [ExportAuditEvent]

    // MARK: - Audit/Event Log

    @Model public struct ExportAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
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

        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let localizedOperation = NSLocalizedString(operation.capitalized, comment: "Operation type for accessibility label")
            let localizedStatus = NSLocalizedString(status.capitalized, comment: "Status for accessibility label")
            let entityTypesJoined = entityTypes.joined(separator: ", ")
            return String(
                format: NSLocalizedString("%@ of %@ (%@) at %@.", comment: "Accessibility label for export/import event"),
                localizedOperation,
                entityTypesJoined,
                localizedStatus,
                dateStr
            )
        }
    }

    /// Asynchronously appends an audit event to the audit log in a thread-safe manner.
    /// - Parameters:
    ///   - operation: The operation type, e.g., "export" or "import".
    ///   - models: The exported/imported data models.
    ///   - fileURL: The URL of the file involved in the operation.
    ///   - tags: Tags associated with the operation.
    ///   - actor: Optional actor responsible for the operation.
    ///   - context: Optional context string.
    ///   - status: The status of the operation, e.g., "success" or "error".
    ///   - error: Optional error encountered during the operation.
    func logEvent(
        operation: String,
        models: FurfolioExportModels,
        fileURL: URL,
        tags: [String],
        actor: String? = nil,
        context: String? = nil,
        status: String = "success",
        error: Error? = nil
    ) async {
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
            errorDescription: error != nil ? NSLocalizedString(error!.localizedDescription, comment: "Error description") : nil
        )
        modelContext.insert(event)
    }

    /// Asynchronously retrieves the last audit event as a pretty-printed JSON string.
    /// - Returns: JSON string of the last audit event, or nil if no events exist.
    func exportLastAuditEventJSON() async -> String? {
        let entries = try? await modelContext.fetch(ExportAuditEvent.self)
        guard let last = entries?.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Asynchronously returns an accessibility summary string for the last audit event.
    var accessibilitySummary: String {
        get async {
            let entries = try? await modelContext.fetch(ExportAuditEvent.self)
            return entries?.last?.accessibilityLabel
                ?? NSLocalizedString("No export/import events recorded.", comment: "")
        }
    }

    /// Asynchronously clears all audit log events.
    /// This method ensures thread-safe clearing of the audit log.
    func clearAuditLog() async {
        let entries = try? await modelContext.fetch(ExportAuditEvent.self)
        entries?.forEach { modelContext.delete($0) }
    }

    // MARK: - Export/Import

    func exportAllData(models: FurfolioExportModels, actor: String? = nil, context: String? = nil) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(models)
        let filename = "FurfolioExport-\(dateString()).json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: url)
            await logEvent(
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
            await logEvent(
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

    func importAllData(from url: URL, actor: String? = nil, context: String? = nil) async throws -> FurfolioExportModels {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let models = try decoder.decode(FurfolioExportModels.self, from: data)
            await logEvent(
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
                errorDescription: NSLocalizedString(error.localizedDescription, comment: "Error description")
            )
            await withCheckedContinuation { continuation in
                auditQueue.async {
                    Self._auditLog.append(event)
                    if Self._auditLog.count > 500 { Self._auditLog.removeFirst() }
                    continuation.resume()
                }
            }
            throw error
        }
    }

    var exportType: UTType { .json }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    /// Presents the iOS share sheet for the given file URL on the main thread.
    /// - Parameter url: The URL of the file to share.
    @MainActor
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

#if DEBUG
import SwiftUI

@available(iOS 15.0, *)
struct ExportManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("ExportManager Audit Log Preview")
                .font(.headline)
            Button("Add Export Event") {
                Task {
                    let sampleModels = FurfolioExportModels(
                        owners: [DogOwner(id: UUID(), name: "Alice")],
                        dogs: [Dog(id: UUID(), name: "Fido")],
                        appointments: [],
                        charges: [],
                        tasks: [],
                        sessions: [],
                        users: [],
                        vaccinationRecords: [],
                        business: nil,
                        staff: []
                    )
                    try? await ExportManager.shared.exportAllData(models: sampleModels)
                }
            }
            Button("Show Last Audit Event JSON") {
                Task {
                    if let json = await ExportManager.shared.exportLastAuditEventJSON() {
                        print(json)
                    } else {
                        print("No audit events to show.")
                    }
                }
            }
            Button("Clear Audit Log") {
                Task {
                    await ExportManager.shared.clearAuditLog()
                }
            }
            Button("Show Accessibility Summary") {
                Task {
                    let summary = await ExportManager.shared.accessibilitySummary
                    print(summary)
                }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

// Dummy models for preview
struct DogOwner: Codable, Identifiable {
    let id: UUID
    let name: String
}
struct Dog: Codable, Identifiable {
    let id: UUID
    let name: String
}
struct Appointment: Codable {}
struct Charge: Codable {}
struct Task: Codable {}
struct Session: Codable {}
struct User: Codable {}
struct VaccinationRecord: Codable {}
struct Business: Codable {}
struct StaffMember: Codable {}
#endif
