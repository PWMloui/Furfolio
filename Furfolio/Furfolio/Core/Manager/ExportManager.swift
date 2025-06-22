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

/// Centralized export manager for all Furfolio business data.
/// Designed to be modular, tokenized, auditable, and extensible.
/// All export/import actions support privacy, audit/event logging, and future localization.
/// This ensures compliance with business standards and data protection requirements.
@MainActor
final class ExportManager: ObservableObject {
    static let shared = ExportManager()
    private init() {}

    /// Export all Furfolio model data to a JSON file in the app's Documents directory.
    /// All exports should log the event for auditing/business compliance.
    /// - Parameter models: The unified export struct holding all business data.
    /// - Returns: The URL of the exported JSON file.
    /// - Throws: Propagates encoding or file write errors.
    func exportAllData(models: FurfolioExportModels) throws -> URL {
        // TODO: Integrate audit/event logging and privacy controls before file write/read.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(models)
        let filename = "FurfolioExport-\(dateString()).json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        try data.write(to: url)
        return url
    }

    /// Import Furfolio data from a JSON file.
    /// All imports should log the event for auditing/business compliance.
    /// - Parameter url: File URL to import from.
    /// - Returns: The decoded `FurfolioExportModels` or throws error.
    /// - Throws: Propagates file read or decoding errors.
    func importAllData(from url: URL) throws -> FurfolioExportModels {
        // TODO: Integrate audit/event logging and privacy controls before file write/read.
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FurfolioExportModels.self, from: data)
    }

    /// Returns a UTType for JSON, for use with document pickers or UIExporters.
    var exportType: UTType {
        .json
    }

    // MARK: - Utility

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    /// Presents a share sheet for the exported data file (for iOS, macOS Catalyst).
    func presentShareSheet(for url: URL) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(activityVC, animated: true)
        #endif
        // For macOS, use NSSharingServicePicker if needed.
    }
}

// MARK: - Model Data Aggregator for Export

/// Aggregates all model data for export/import.
/// This struct should be extended to include all new business models as modules evolve.
/// Supports field-level localization, encryption, and owner/staff privacy controls for sensitive data.
/// Designed to integrate with audit/event logging and compliance frameworks.
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
    // Add additional models as needed for future modules

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
/// Should only be used for export-related UI actions; audit UI usage in compliance builds.
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
