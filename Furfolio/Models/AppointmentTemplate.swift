//
//  AppointmentTemplate.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 7, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData
import os
@Model
final class AppointmentTemplate: Identifiable {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentTemplate")
    
    // MARK: – Persistent Properties
    
    @Attribute(.unique)
    var id: UUID = UUID()                        // was `.init()`
    
    @Attribute
    var name: String
    
    @Attribute
    var serviceType: Appointment.ServiceType
    
    @Attribute
    var defaultNotes: String?
    
    @Attribute
    var defaultDurationMinutes: Int
    
    @Attribute
    var defaultEstimatedDurationMinutes: Int?
    
    @Attribute
    var defaultReminderOffset: Int
    
    @Attribute
    var templateBeforePhoto: Data?
    
    @Attribute
    var templateAfterPhoto: Data?
    
    @Attribute
    var createdAt: Date = Date.now              // was `.now`
    
    @Attribute
    var updatedAt: Date?

    /// Shared formatter for created/updated date display.
    private static let dateFormatter: DateFormatter = {
      let fmt = DateFormatter()
      fmt.dateStyle = .medium
      fmt.timeStyle = .short
      return fmt
    }()
    
    // MARK: – Computed Formatting
    
    @Transient var createdAtFormatted: String {
      Self.dateFormatter.string(from: createdAt)
    }
    @Transient var updatedAtFormatted: String {
      if let updated = updatedAt {
        return Self.dateFormatter.string(from: updated)
      } else {
        return "—"
      }
    }
    
    
    // MARK: – Initialization
    
    /// Initializes a new template, trimming inputs and enforcing default minimums.
    init(
        name: String,
        serviceType: Appointment.ServiceType,
        defaultNotes: String? = nil,
        defaultDurationMinutes: Int = 60,
        defaultEstimatedDurationMinutes: Int? = nil,
        defaultReminderOffset: Int = 30,
        templateBeforePhoto: Data? = nil,
        templateAfterPhoto: Data? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name                         = trimmedName
        self.serviceType                  = serviceType
        self.defaultNotes                 = defaultNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.defaultDurationMinutes       = max(1, defaultDurationMinutes)
        self.defaultEstimatedDurationMinutes = defaultEstimatedDurationMinutes.map { max(1, $0) }
        self.defaultReminderOffset        = max(0, defaultReminderOffset)
        self.templateBeforePhoto          = templateBeforePhoto
        self.templateAfterPhoto           = templateAfterPhoto
        // createdAt is set by its default, updatedAt remains nil
        logger.log("Initialized AppointmentTemplate id: \(id), name: \(name)")
    }
    
    
    // MARK: – Validation
    
    var isValid: Bool {
        let valid = !name.isEmpty && defaultDurationMinutes > 0
        logger.log("isValid check for template \(id): \(valid)")
        return valid
    }
    
    
    // MARK: – Updating
    
    /// Updates this template’s properties and sets `updatedAt` to now.
    func update(
        name: String,
        serviceType: Appointment.ServiceType,
        defaultNotes: String?,
        defaultDurationMinutes: Int,
        defaultEstimatedDurationMinutes: Int?,
        defaultReminderOffset: Int,
        templateBeforePhoto: Data?,
        templateAfterPhoto: Data?
    ) {
        logger.log("Updating AppointmentTemplate id: \(id)")
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name                         = trimmedName
        self.serviceType                  = serviceType
        self.defaultNotes                 = defaultNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.defaultDurationMinutes       = max(1, defaultDurationMinutes)
        self.defaultEstimatedDurationMinutes = defaultEstimatedDurationMinutes.map { max(1, $0) }
        self.defaultReminderOffset        = max(0, defaultReminderOffset)
        self.templateBeforePhoto          = templateBeforePhoto
        self.templateAfterPhoto           = templateAfterPhoto
        self.updatedAt                    = Date.now       // was `.now`
        logger.log("Updated AppointmentTemplate \(id) at \(updatedAt!)")
    }
    
    
    // MARK: – Template Instantiation
    
    /// Instantiates and inserts an `Appointment` based on this template for a given date and owner.
    @discardableResult
    func instantiate(
        on date: Date,
        owner: DogOwner,
        in context: ModelContext
    ) -> Appointment? {
        logger.log("Instantiating Appointment from template \(id) on \(date) for owner \(owner.id)")
        guard isValid else { return nil }
        let appt = Appointment(
            date: date,
            dogOwner: owner,
            serviceType: serviceType,
            notes: defaultNotes,
            durationMinutes: defaultDurationMinutes,
            estimatedDurationMinutes: defaultEstimatedDurationMinutes,
            beforePhoto: templateBeforePhoto,
            afterPhoto: templateAfterPhoto
        )
        context.insert(appt)
        logger.log("Inserted Appointment id: \(appt.id) and set reminderOffset to \(defaultReminderOffset)")
        appt.reminderOffset = defaultReminderOffset
        return appt
    }
    
    
    // MARK: – Static Helpers
    
    /// Creates and inserts a new `AppointmentTemplate` into the given context.
    @discardableResult
    static func create(
        name: String,
        serviceType: Appointment.ServiceType,
        defaultNotes: String? = nil,
        defaultDurationMinutes: Int = 60,
        defaultEstimatedDurationMinutes: Int? = nil,
        defaultReminderOffset: Int = 30,
        templateBeforePhoto: Data? = nil,
        templateAfterPhoto: Data? = nil,
        in context: ModelContext
    ) -> AppointmentTemplate {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentTemplate")
        logger.log("Creating AppointmentTemplate with name: \(name)")
        let tmpl = AppointmentTemplate(
            name: name,
            serviceType: serviceType,
            defaultNotes: defaultNotes,
            defaultDurationMinutes: defaultDurationMinutes,
            defaultEstimatedDurationMinutes: defaultEstimatedDurationMinutes,
            defaultReminderOffset: defaultReminderOffset,
            templateBeforePhoto: templateBeforePhoto,
            templateAfterPhoto: templateAfterPhoto
        )
        context.insert(tmpl)
        logger.log("Created AppointmentTemplate id: \(tmpl.id)")
        return tmpl
    }
    
    /// Fetches all templates, newest first. Returns an empty array on error.
    static func fetchAll(in context: ModelContext) -> [AppointmentTemplate] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentTemplate")
        logger.log("Fetching all AppointmentTemplates")
        let descriptor = FetchDescriptor<AppointmentTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let templates = try context.fetch(descriptor)
            logger.log("Fetched \(templates.count) templates")
            return templates
        } catch {
            logger.error("⚠️ Error fetching AppointmentTemplates: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches the first template matching the trimmed `name`, or nil on error.
    static func fetch(named name: String, in context: ModelContext) -> AppointmentTemplate? {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AppointmentTemplate")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.log("Fetching AppointmentTemplate named: \(trimmed)")
        let descriptor = FetchDescriptor<AppointmentTemplate>(
            predicate: #Predicate { $0.name == trimmed },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let results = try context.fetch(descriptor)
            if let first = results.first {
                logger.log("Fetched AppointmentTemplate named '\(trimmed)' with id: \(first.id)")
            } else {
                logger.log("No AppointmentTemplate found named '\(trimmed)'")
            }
            return results.first
        } catch {
            logger.error("⚠️ Error fetching AppointmentTemplate named '\(trimmed)': \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: – Preview Data
    
    #if DEBUG
    static var sample: AppointmentTemplate {
        AppointmentTemplate(
            name: NSLocalizedString("Monthly Groom", comment: ""),
            serviceType: .full,
            defaultNotes: NSLocalizedString(
                "Include nail trim and ear cleaning.",
                comment: ""
            ),
            defaultDurationMinutes: 90,
            defaultEstimatedDurationMinutes: 100,
            defaultReminderOffset: 1440  // 24h
        )
    }
    #endif
}
