//
//  AppointmentTemplate.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 7, 2025 — replaced bare `.init()` and `.now` with `UUID()` and `Date.now` for fully qualified defaults.
//

import Foundation
import SwiftData
@Model
final class AppointmentTemplate: Identifiable {
    
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
    }
    
    
    // MARK: – Validation
    
    var isValid: Bool {
        !name.isEmpty && defaultDurationMinutes > 0
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
    }
    
    
    // MARK: – Template Instantiation
    
    /// Instantiates and inserts an `Appointment` based on this template for a given date and owner.
    @discardableResult
    func instantiate(
        on date: Date,
        owner: DogOwner,
        in context: ModelContext
    ) -> Appointment? {
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
        return tmpl
    }
    
    /// Fetches all templates, newest first. Returns an empty array on error.
    static func fetchAll(in context: ModelContext) -> [AppointmentTemplate] {
        let descriptor = FetchDescriptor<AppointmentTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ Error fetching AppointmentTemplates:", error)
            return []
        }
    }
    
    /// Fetches the first template matching the trimmed `name`, or nil on error.
    static func fetch(named name: String, in context: ModelContext) -> AppointmentTemplate? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<AppointmentTemplate>(
            predicate: #Predicate { $0.name == trimmed },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            print("⚠️ Error fetching AppointmentTemplate named '\(trimmed)':", error)
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
