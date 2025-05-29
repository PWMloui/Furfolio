import Foundation
import SwiftData
import os

struct PreviewHelpers {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PreviewHelpers")

    static let fullGroom = AppointmentTemplate(
        name: "Full Groom", serviceType: .fullPackage,
        description: "Includes bath, haircut, nail trim, ear cleaning, and teeth brushing."
    )
    
    static let basicGroom = AppointmentTemplate(
        name: "Basic Groom", serviceType: .basicPackage,
        description: "Includes bath, nail trim, and ear cleaning."
    )
    
    static let spaBath = AppointmentTemplate(
        name: "Spa Bath", serviceType: .spaBath,
        description: "Includes a relaxing bath with special shampoos and conditioners."
    )
    
    /// All predefined appointment templates.
    static var appointmentTemplates: [AppointmentTemplate] {
        logger.log("Accessing appointmentTemplates: \( [fullGroom, basicGroom, spaBath].count ) templates")
        return [fullGroom, basicGroom, spaBath]
    }
    
    /// Sample dog owners for SwiftUI previews.
    static let sampleDogOwners: [DogOwner] = [
        DogOwner.sample
    ]
    
    /// Sample appointments for SwiftUI previews.
    static var sampleAppointments: [Appointment] {
        guard let owner = sampleDogOwners.first else { return [] }
        logger.log("Generating sampleAppointments for owner id: \(owner.id)")
        return appointmentTemplates.enumerated().map { index, template in
            Appointment(
                date: Calendar.current.date(byAdding: .day, value: index, to: Date.now)!,
                serviceType: template.serviceType,
                notes: "Sample appointment \(index + 1)",
                dogOwner: owner,
                in: PersistenceController.previewContext
            )
        }
    }
}
