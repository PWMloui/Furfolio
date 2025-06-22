//
//  SiriIntentHandler.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated & Enhanced by ChatGPT on 6/21/25
//

import Intents
import Foundation
import OSLog

// MARK: - Siri Entry Point

/// Main extension handler for Furfolio's SiriKit Intents.
final class SiriIntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is AddAppointmentIntent:
            return AddAppointmentIntentHandler()
        case is AddQuickNoteIntent:
            return AddQuickNoteIntentHandler()
        case is OpenOwnerProfileIntent:
            return OpenOwnerProfileIntentHandler()
        default:
            return self
        }
    }
}

// MARK: - Add Appointment Intent Handler

/// Handles intent to schedule a new appointment for a dog.
final class AddAppointmentIntentHandler: NSObject, AddAppointmentIntentHandling {
    func handle(intent: AddAppointmentIntent, completion: @escaping (AddAppointmentIntentResponse) -> Void) {
        let dogName = intent.dogName ?? "Dog"
        let service = intent.serviceType ?? "Full Groom"
        let date = intent.date ?? Date()

        // TODO: Integrate with AppointmentService through DependencyContainer
        let response = AddAppointmentIntentResponse.success(dogName: dogName, serviceType: service, date: date)
        completion(response)
    }

    func resolveDogName(for intent: AddAppointmentIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let name = intent.dogName, !name.isEmpty {
            completion(.success(with: name))
        } else {
            completion(.needsValue())
        }
    }

    func resolveDate(for intent: AddAppointmentIntent, with completion: @escaping (INDateComponentsResolutionResult) -> Void) {
        if let date = intent.date {
            completion(.success(with: date))
        } else {
            completion(.needsValue())
        }
    }
}

// MARK: - Add Quick Note Intent Handler

/// Handles intent to quickly log a note for a client or the business.
final class AddQuickNoteIntentHandler: NSObject, AddQuickNoteIntentHandling {
    func handle(intent: AddQuickNoteIntent, completion: @escaping (AddQuickNoteIntentResponse) -> Void) {
        let content = intent.content ?? "Note"
        let owner = intent.ownerName ?? "Business"

        // TODO: Integrate with NoteManager
        let response = AddQuickNoteIntentResponse.success(noteContent: content, ownerName: owner)
        completion(response)
    }
}

// MARK: - Open Owner Profile Intent Handler

/// Handles intent to open a specific dog owner's profile.
final class OpenOwnerProfileIntentHandler: NSObject, OpenOwnerProfileIntentHandling {
    func handle(intent: OpenOwnerProfileIntent, completion: @escaping (OpenOwnerProfileIntentResponse) -> Void) {
        let name = intent.ownerName ?? "Owner"

        // TODO: Use NavigationService or ViewRouter to deep link to profile
        let response = OpenOwnerProfileIntentResponse.success(ownerName: name)
        completion(response)
    }
}

// MARK: - FUTURE INTENT EXPANSION

/*
final class OptimizeRouteIntentHandler: NSObject, OptimizeRouteIntentHandling {
    func handle(intent: OptimizeRouteIntent, completion: @escaping (OptimizeRouteIntentResponse) -> Void) {
        // TODO: RouteOptimizer.solve() for TSP-based route planning
    }
}
*/

// MARK: - SECURITY & EXTENSION NOTES

/*
- All intent data must be validated and sanitized.
- Avoid exposing private user or pet info in Siri responses.
- Support future role-based logic for multi-user businesses.
- Offline-first design must be preserved for all responses.
*/
